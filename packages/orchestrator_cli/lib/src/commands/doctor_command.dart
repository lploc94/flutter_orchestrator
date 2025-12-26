import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

import '../utils/logger.dart';

/// Check result for a single diagnostic
class DiagnosticResult {
  final String name;
  final bool passed;
  final String? message;
  final String? fix;
  final DiagnosticSeverity severity;

  const DiagnosticResult({
    required this.name,
    required this.passed,
    this.message,
    this.fix,
    this.severity = DiagnosticSeverity.error,
  });
}

/// Severity level for diagnostics
enum DiagnosticSeverity {
  error, // Must fix
  warning, // Should fix
  info, // Nice to have
}

/// Doctor command - checks project setup and identifies issues
class DoctorCommand extends Command<int> {
  DoctorCommand() {
    argParser.addFlag(
      'fix',
      abbr: 'f',
      help: 'Automatically fix issues where possible',
      negatable: false,
    );
    argParser.addFlag(
      'verbose',
      abbr: 'v',
      help: 'Show detailed diagnostic information',
      negatable: false,
    );
  }

  @override
  String get name => 'doctor';

  @override
  String get description =>
      'Check project setup and identify potential issues with Orchestrator configuration';

  @override
  Future<int> run() async {
    final verbose = argResults?['verbose'] as bool? ?? false;
    final autoFix = argResults?['fix'] as bool? ?? false;
    final logger = CliLogger(
      level: verbose ? CliLogLevel.verbose : CliLogLevel.normal,
    );

    logger.info('🩺 Running Orchestrator Doctor...\n');

    final results = <DiagnosticResult>[];

    // Run all diagnostics
    results.add(await _checkPubspec(verbose));
    results.add(await _checkOrchestratorConfig(verbose));
    results.add(await _checkProjectStructure(verbose));
    results.add(await _checkDispatcherSetup(verbose));
    results.add(await _checkExecutorRegistration(verbose));
    results.add(await _checkStateManagementIntegration(verbose));
    results.add(await _checkImports(verbose));
    results.add(await _checkJobExecutorMatch(verbose));
    results.add(await _checkStateCopyWith(verbose));
    results.add(await _checkOrchestratorHandlers(verbose));

    // Display results
    logger.info('');
    logger.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    logger.info('📋 Diagnostic Results');
    logger.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    int passed = 0;
    int failed = 0;
    int warnings = 0;
    final fixableIssues = <DiagnosticResult>[];

    for (final result in results) {
      if (result.passed) {
        passed++;
        logger.success('✓ ${result.name}');
        if (verbose && result.message != null) {
          logger.muted('  ${result.message}');
        }
      } else {
        if (result.severity == DiagnosticSeverity.warning) {
          warnings++;
          logger.warn('⚠ ${result.name}');
        } else {
          failed++;
          logger.error('✗ ${result.name}');
        }
        if (result.message != null) {
          logger.muted('  └─ ${result.message}');
        }
        if (result.fix != null) {
          fixableIssues.add(result);
          logger.muted('  └─ 💡 ${result.fix}');
        }
      }
    }

    logger.info('');
    logger.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    if (failed == 0 && warnings == 0) {
      logger.success(
          '🎉 All $passed checks passed! Your project is properly configured.');
      return 0;
    }

    final summaryParts = <String>['$passed passed'];
    if (failed > 0) summaryParts.add('$failed failed');
    if (warnings > 0) summaryParts.add('$warnings warning(s)');

    if (failed > 0) {
      logger.error('📊 Results: ${summaryParts.join(', ')}');
    } else {
      logger.warn('📊 Results: ${summaryParts.join(', ')}');
    }

    if (fixableIssues.isNotEmpty) {
      logger.info('');
      if (autoFix) {
        logger.info('🔧 Attempting to fix ${fixableIssues.length} issue(s)...');
        await _applyFixes(fixableIssues, logger);
      } else {
        logger.info('💡 ${fixableIssues.length} issue(s) can be auto-fixed.');
        logger.muted('   Run `orchestrator doctor --fix` to apply fixes.');
      }
    }

    return failed > 0 ? 1 : 0;
  }

  /// Check pubspec.yaml for required dependencies
  Future<DiagnosticResult> _checkPubspec(bool verbose) async {
    final pubspecFile = File('pubspec.yaml');

    if (!pubspecFile.existsSync()) {
      return const DiagnosticResult(
        name: 'pubspec.yaml exists',
        passed: false,
        message: 'No pubspec.yaml found in current directory',
        fix: 'Run this command from your Flutter project root',
      );
    }

    try {
      final content = await pubspecFile.readAsString();
      final yaml = loadYaml(content) as YamlMap;
      final dependencies = yaml['dependencies'] as YamlMap?;

      if (dependencies == null) {
        return const DiagnosticResult(
          name: 'Dependencies section',
          passed: false,
          message: 'No dependencies section in pubspec.yaml',
        );
      }

      final missingDeps = <String>[];

      // Check for at least orchestrator_core
      if (!dependencies.containsKey('orchestrator_core')) {
        missingDeps.add('orchestrator_core');
      }

      // Check for state management integration
      final hasBloc = dependencies.containsKey('orchestrator_bloc');
      final hasProvider = dependencies.containsKey('orchestrator_provider');
      final hasRiverpod = dependencies.containsKey('orchestrator_riverpod');

      if (!hasBloc && !hasProvider && !hasRiverpod) {
        return DiagnosticResult(
          name: 'Orchestrator dependencies',
          passed: false,
          message: 'No state management integration found',
          fix:
              'Add one of: orchestrator_bloc, orchestrator_provider, or orchestrator_riverpod',
        );
      }

      if (missingDeps.isNotEmpty) {
        return DiagnosticResult(
          name: 'Orchestrator dependencies',
          passed: false,
          message: 'Missing: ${missingDeps.join(", ")}',
          fix: 'Run: flutter pub add ${missingDeps.join(" ")}',
        );
      }

      final found = <String>[];
      if (hasBloc) found.add('orchestrator_bloc');
      if (hasProvider) found.add('orchestrator_provider');
      if (hasRiverpod) found.add('orchestrator_riverpod');

      return DiagnosticResult(
        name: 'Orchestrator dependencies',
        passed: true,
        message: 'Found: ${found.join(", ")}',
      );
    } catch (e) {
      return DiagnosticResult(
        name: 'pubspec.yaml parsing',
        passed: false,
        message: 'Failed to parse pubspec.yaml: $e',
      );
    }
  }

  /// Check for orchestrator.yaml config file
  Future<DiagnosticResult> _checkOrchestratorConfig(bool verbose) async {
    final configFile = File('orchestrator.yaml');

    if (!configFile.existsSync()) {
      return const DiagnosticResult(
        name: 'orchestrator.yaml config',
        passed: false,
        severity: DiagnosticSeverity.warning,
        message: 'No orchestrator.yaml found (optional but recommended)',
        fix: 'Run: orchestrator init',
      );
    }

    try {
      final content = await configFile.readAsString();
      final yaml = loadYaml(content) as YamlMap?;

      if (yaml == null) {
        return const DiagnosticResult(
          name: 'orchestrator.yaml config',
          passed: false,
          severity: DiagnosticSeverity.warning,
          message: 'orchestrator.yaml is empty',
          fix: 'Run: orchestrator init --force',
        );
      }

      return const DiagnosticResult(
        name: 'orchestrator.yaml config',
        passed: true,
        message: 'Configuration file found and valid',
      );
    } catch (e) {
      return DiagnosticResult(
        name: 'orchestrator.yaml config',
        passed: false,
        message: 'Failed to parse orchestrator.yaml: $e',
        fix: 'Check YAML syntax or run: orchestrator init --force',
      );
    }
  }

  /// Check project structure
  Future<DiagnosticResult> _checkProjectStructure(bool verbose) async {
    final libDir = Directory('lib');
    if (!libDir.existsSync()) {
      return const DiagnosticResult(
        name: 'Project structure',
        passed: false,
        message: 'No lib/ directory found',
        fix: 'Run this command from your Flutter project root',
      );
    }

    final recommendedDirs = [
      'lib/core/jobs',
      'lib/core/executors',
      'lib/core/di',
    ];

    final missingDirs = <String>[];
    for (final dir in recommendedDirs) {
      if (!Directory(dir).existsSync()) {
        missingDirs.add(dir);
      }
    }

    if (missingDirs.isNotEmpty) {
      return DiagnosticResult(
        name: 'Project structure',
        passed: false,
        severity: DiagnosticSeverity.warning,
        message: 'Recommended directories missing: ${missingDirs.join(", ")}',
        fix: 'Run: orchestrator init',
      );
    }

    return const DiagnosticResult(
      name: 'Project structure',
      passed: true,
      message: 'All recommended directories exist',
    );
  }

  /// Check for Dispatcher setup
  Future<DiagnosticResult> _checkDispatcherSetup(bool verbose) async {
    final libDir = Directory('lib');
    if (!libDir.existsSync()) {
      return const DiagnosticResult(
        name: 'Dispatcher setup',
        passed: false,
        message: 'Cannot check - no lib/ directory',
      );
    }

    // Search for Dispatcher usage in Dart files
    final dartFiles = await _findDartFiles(libDir);
    bool foundDispatcher = false;
    String? dispatcherLocation;

    for (final file in dartFiles) {
      final content = await file.readAsString();
      if (content.contains('Dispatcher(') ||
          content.contains('Dispatcher.instance') ||
          content.contains('final dispatcher') ||
          content.contains('late final Dispatcher') ||
          content.contains('GetIt') && content.contains('Dispatcher')) {
        foundDispatcher = true;
        dispatcherLocation = path.relative(file.path);
        break;
      }
    }

    if (!foundDispatcher) {
      return const DiagnosticResult(
        name: 'Dispatcher setup',
        passed: false,
        message: 'No Dispatcher instance found in project',
        fix:
            'Create a Dispatcher instance in your DI setup (e.g., lib/core/di/injection.dart)',
      );
    }

    return DiagnosticResult(
      name: 'Dispatcher setup',
      passed: true,
      message: 'Found in $dispatcherLocation',
    );
  }

  /// Check for Executor registration
  Future<DiagnosticResult> _checkExecutorRegistration(bool verbose) async {
    final libDir = Directory('lib');
    if (!libDir.existsSync()) {
      return const DiagnosticResult(
        name: 'Executor registration',
        passed: false,
        message: 'Cannot check - no lib/ directory',
      );
    }

    final dartFiles = await _findDartFiles(libDir);

    // Find all Executor classes
    final executorFiles = <String>[];
    final registeredExecutors = <String>[];

    for (final file in dartFiles) {
      final content = await file.readAsString();
      final relativePath = path.relative(file.path);

      // Find Executor class definitions
      final executorMatch =
          RegExp(r'class\s+(\w+Executor)\s+extends\s+BaseExecutor')
              .allMatches(content);
      for (final match in executorMatch) {
        executorFiles.add('${match.group(1)} ($relativePath)');
      }

      // Find registered executors
      final registerMatch =
          RegExp(r'\.register<\w+>\s*\(\s*(\w+Executor)').allMatches(content);
      for (final match in registerMatch) {
        registeredExecutors.add(match.group(1)!);
      }
    }

    if (executorFiles.isEmpty) {
      return const DiagnosticResult(
        name: 'Executor registration',
        passed: true,
        message:
            'No executors found (create some with: orchestrator create executor <name>)',
      );
    }

    // Check if all executors are registered
    final unregistered = <String>[];
    for (final executor in executorFiles) {
      final name = executor.split(' ').first;
      if (!registeredExecutors.contains(name)) {
        unregistered.add(executor);
      }
    }

    if (unregistered.isNotEmpty) {
      return DiagnosticResult(
        name: 'Executor registration',
        passed: false,
        message: 'Unregistered executors: ${unregistered.join(", ")}',
        fix:
            'Register executors with dispatcher.register<JobType>(ExecutorInstance())',
      );
    }

    return DiagnosticResult(
      name: 'Executor registration',
      passed: true,
      message: '${executorFiles.length} executor(s) found and registered',
    );
  }

  /// Check state management integration
  Future<DiagnosticResult> _checkStateManagementIntegration(
      bool verbose) async {
    final pubspecFile = File('pubspec.yaml');
    if (!pubspecFile.existsSync()) {
      return const DiagnosticResult(
        name: 'State management integration',
        passed: false,
        message: 'Cannot check - no pubspec.yaml',
      );
    }

    final content = await pubspecFile.readAsString();
    final yaml = loadYaml(content) as YamlMap;
    final dependencies = yaml['dependencies'] as YamlMap?;

    if (dependencies == null) {
      return const DiagnosticResult(
        name: 'State management integration',
        passed: false,
        message: 'No dependencies found',
      );
    }

    // Detect which integration is used
    String? integration;
    String? expectedClass;

    if (dependencies.containsKey('orchestrator_bloc')) {
      integration = 'Bloc (OrchestratorCubit)';
      expectedClass = 'OrchestratorCubit';
    } else if (dependencies.containsKey('orchestrator_provider')) {
      integration = 'Provider (OrchestratorNotifier)';
      expectedClass = 'OrchestratorNotifier';
    } else if (dependencies.containsKey('orchestrator_riverpod')) {
      integration = 'Riverpod (OrchestratorNotifier)';
      expectedClass = 'OrchestratorNotifier';
    }

    if (integration == null) {
      return const DiagnosticResult(
        name: 'State management integration',
        passed: false,
        message: 'No orchestrator state management package found',
        fix:
            'Add orchestrator_bloc, orchestrator_provider, or orchestrator_riverpod',
      );
    }

    // Check if any Cubit/Notifier extends the base class
    final libDir = Directory('lib');
    if (!libDir.existsSync()) {
      return DiagnosticResult(
        name: 'State management integration',
        passed: true,
        message: 'Using $integration (no orchestrators created yet)',
      );
    }

    final dartFiles = await _findDartFiles(libDir);
    int orchestratorCount = 0;

    for (final file in dartFiles) {
      final fileContent = await file.readAsString();
      if (fileContent.contains('extends $expectedClass')) {
        orchestratorCount++;
      }
    }

    if (orchestratorCount == 0) {
      return DiagnosticResult(
        name: 'State management integration',
        passed: true,
        message:
            'Using $integration (create orchestrators with: orchestrator create cubit/notifier/riverpod <name>)',
      );
    }

    return DiagnosticResult(
      name: 'State management integration',
      passed: true,
      message: 'Using $integration with $orchestratorCount orchestrator(s)',
    );
  }

  /// Check for common import issues
  Future<DiagnosticResult> _checkImports(bool verbose) async {
    final libDir = Directory('lib');
    if (!libDir.existsSync()) {
      return const DiagnosticResult(
        name: 'Import consistency',
        passed: true,
        message: 'Cannot check - no lib/ directory',
      );
    }

    final dartFiles = await _findDartFiles(libDir);
    final issues = <String>[];

    for (final file in dartFiles) {
      final content = await file.readAsString();
      final relativePath = path.relative(file.path);

      // Check for mixing orchestrator package imports
      final hasCore = content.contains("import 'package:orchestrator_core");
      final hasBloc = content.contains("import 'package:orchestrator_bloc");
      final hasProvider =
          content.contains("import 'package:orchestrator_provider");
      final hasRiverpod =
          content.contains("import 'package:orchestrator_riverpod");

      // Check if using BaseJob without importing core
      if (content.contains('BaseJob') &&
          !hasCore &&
          !hasBloc &&
          !hasProvider &&
          !hasRiverpod) {
        issues
            .add('$relativePath: Uses BaseJob but missing orchestrator import');
      }

      // Check if using BaseExecutor without importing core
      if (content.contains('BaseExecutor') &&
          !hasCore &&
          !hasBloc &&
          !hasProvider &&
          !hasRiverpod) {
        issues.add(
            '$relativePath: Uses BaseExecutor but missing orchestrator import');
      }
    }

    if (issues.isNotEmpty) {
      return DiagnosticResult(
        name: 'Import consistency',
        passed: false,
        message: '${issues.length} import issue(s) found',
        fix: issues.take(3).join('\n  └─ '),
      );
    }

    return const DiagnosticResult(
      name: 'Import consistency',
      passed: true,
      message: 'All imports look correct',
    );
  }

  /// Check if Jobs have matching Executors
  Future<DiagnosticResult> _checkJobExecutorMatch(bool verbose) async {
    final libDir = Directory('lib');
    if (!libDir.existsSync()) {
      return const DiagnosticResult(
        name: 'Job-Executor matching',
        passed: true,
        message: 'Cannot check - no lib/ directory',
      );
    }

    final dartFiles = await _findDartFiles(libDir);
    final jobs = <String>[];
    final executors = <String>[];

    for (final file in dartFiles) {
      final content = await file.readAsString();

      // Find Job definitions (e.g., class FetchUserJob extends BaseJob)
      final jobMatches =
          RegExp(r'class\s+(\w+Job)\s+extends\s+BaseJob').allMatches(content);
      for (final match in jobMatches) {
        jobs.add(match.group(1)!);
      }

      // Find Executor definitions
      final executorMatches =
          RegExp(r'class\s+(\w+)Executor\s+extends\s+BaseExecutor')
              .allMatches(content);
      for (final match in executorMatches) {
        executors.add('${match.group(1)}Job');
      }
    }

    if (jobs.isEmpty) {
      return const DiagnosticResult(
        name: 'Job-Executor matching',
        passed: true,
        message: 'No Jobs found yet',
      );
    }

    final orphanJobs = jobs.where((job) => !executors.contains(job)).toList();

    if (orphanJobs.isNotEmpty) {
      return DiagnosticResult(
        name: 'Job-Executor matching',
        passed: false,
        severity: DiagnosticSeverity.warning,
        message: 'Jobs without Executors: ${orphanJobs.join(", ")}',
        fix: 'Create executors: orchestrator create executor <name>',
      );
    }

    return DiagnosticResult(
      name: 'Job-Executor matching',
      passed: true,
      message: '${jobs.length} Job(s) have matching Executors',
    );
  }

  /// Check if State classes have copyWith method
  Future<DiagnosticResult> _checkStateCopyWith(bool verbose) async {
    final libDir = Directory('lib');
    if (!libDir.existsSync()) {
      return const DiagnosticResult(
        name: 'State copyWith methods',
        passed: true,
        message: 'Cannot check - no lib/ directory',
      );
    }

    final dartFiles = await _findDartFiles(libDir);
    final statesWithoutCopyWith = <String>[];

    for (final file in dartFiles) {
      final content = await file.readAsString();
      final relativePath = path.relative(file.path);

      // Find State classes
      final stateMatches =
          RegExp(r'class\s+(\w+State)\s*\{').allMatches(content);

      for (final match in stateMatches) {
        final stateName = match.group(1)!;
        // Check if copyWith exists in the same file
        if (!content.contains('$stateName copyWith(') &&
            !content.contains('copyWith({')) {
          statesWithoutCopyWith.add('$stateName ($relativePath)');
        }
      }
    }

    if (statesWithoutCopyWith.isEmpty) {
      return const DiagnosticResult(
        name: 'State copyWith methods',
        passed: true,
        message: 'All State classes have copyWith',
      );
    }

    return DiagnosticResult(
      name: 'State copyWith methods',
      passed: false,
      severity: DiagnosticSeverity.warning,
      message:
          'States missing copyWith: ${statesWithoutCopyWith.take(3).join(", ")}',
      fix: 'Add copyWith method or use @GenerateAsyncState annotation',
    );
  }

  /// Check if Orchestrators override required handlers
  Future<DiagnosticResult> _checkOrchestratorHandlers(bool verbose) async {
    final libDir = Directory('lib');
    if (!libDir.existsSync()) {
      return const DiagnosticResult(
        name: 'Orchestrator handlers',
        passed: true,
        message: 'Cannot check - no lib/ directory',
      );
    }

    final dartFiles = await _findDartFiles(libDir);
    final missingHandlers = <String>[];

    for (final file in dartFiles) {
      final content = await file.readAsString();
      final relativePath = path.relative(file.path);

      // Find OrchestratorCubit or OrchestratorNotifier classes
      final orchestratorMatch = RegExp(
              r'class\s+(\w+)\s+extends\s+(OrchestratorCubit|OrchestratorNotifier)')
          .firstMatch(content);

      if (orchestratorMatch != null) {
        final className = orchestratorMatch.group(1)!;

        // Check for handler overrides
        final hasOnActiveSuccess = content.contains('onActiveSuccess(');
        final hasOnActiveFailure = content.contains('onActiveFailure(');

        if (!hasOnActiveSuccess && !hasOnActiveFailure) {
          missingHandlers.add('$className ($relativePath)');
        }
      }
    }

    if (missingHandlers.isEmpty) {
      return const DiagnosticResult(
        name: 'Orchestrator handlers',
        passed: true,
        message: 'All Orchestrators override handlers',
      );
    }

    return DiagnosticResult(
      name: 'Orchestrator handlers',
      passed: false,
      severity: DiagnosticSeverity.warning,
      message:
          'Orchestrators missing handlers: ${missingHandlers.take(3).join(", ")}',
      fix: 'Override onActiveSuccess() and onActiveFailure() methods',
    );
  }

  /// Find all Dart files in a directory
  Future<List<File>> _findDartFiles(Directory dir) async {
    final files = <File>[];
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        // Skip generated files
        if (!entity.path.contains('.g.dart') &&
            !entity.path.contains('.freezed.dart')) {
          files.add(entity);
        }
      }
    }
    return files;
  }

  /// Apply automatic fixes
  Future<void> _applyFixes(
      List<DiagnosticResult> issues, CliLogger logger) async {
    for (final issue in issues) {
      if (issue.fix != null) {
        if (issue.fix!.startsWith('Run: orchestrator init')) {
          logger.info('  → Creating project structure...');
          // Create recommended directories
          final dirs = [
            'lib/features',
            'lib/core/jobs',
            'lib/core/executors',
            'lib/core/di',
            'lib/shared',
          ];
          for (final dir in dirs) {
            await Directory(dir).create(recursive: true);
          }
          logger.success('  ✓ Created project directories');
        }
      }
    }
  }
}
