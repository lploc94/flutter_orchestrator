import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as path;

import '../../utils/brick_loader.dart';
import '../../utils/config_loader.dart';
import '../../utils/logger.dart';

/// State management type for feature scaffolding
enum StateManagement {
  cubit,
  provider,
  riverpod,
}

/// Command to create a full feature scaffold
class FeatureCommand extends Command<int> {
  final CliLogger _logger = CliLogger();

  @override
  final String name = 'feature';

  @override
  final String description = 'Create a full feature scaffold (job, executor, state management)';

  @override
  final String invocation = 'orchestrator create feature <name>';

  FeatureCommand() {
    argParser
      ..addOption(
        'output',
        abbr: 'o',
        help: 'Output directory for the feature',
      )
      ..addOption(
        'state-management',
        abbr: 's',
        help: 'State management solution to use',
        allowed: ['cubit', 'provider', 'riverpod'],
      )
      ..addFlag(
        'no-job',
        help: 'Skip generating job file',
        defaultsTo: false,
        negatable: false,
      )
      ..addFlag(
        'no-executor',
        help: 'Skip generating executor file',
        defaultsTo: false,
        negatable: false,
      )
      ..addFlag(
        'interactive',
        abbr: 'i',
        help: 'Run in interactive mode with prompts',
        defaultsTo: false,
        negatable: false,
      );
  }

  @override
  Future<int> run() async {
    final args = argResults!.rest;
    final isInteractive = argResults!['interactive'] as bool;

    // Load config for defaults
    final config = await ConfigLoader.loadOrDefault();

    String name;
    String outputBase;
    StateManagement stateManagement;
    bool skipJob;
    bool skipExecutor;

    if (isInteractive || args.isEmpty) {
      // Interactive mode
      final result = await _runInteractive(config);
      if (result == null) return 1;
      
      name = result.name;
      outputBase = result.outputBase;
      stateManagement = result.stateManagement;
      skipJob = result.skipJob;
      skipExecutor = result.skipExecutor;
    } else {
      // Non-interactive mode
      name = args.first;
      outputBase = argResults!['output'] as String? ?? config.output.features;
      final stateManagementStr = argResults!['state-management'] as String? ?? config.stateManagement;
      stateManagement = StateManagement.values.firstWhere(
        (e) => e.name == stateManagementStr,
        orElse: () => StateManagement.cubit,
      );
      skipJob = argResults!['no-job'] as bool;
      skipExecutor = argResults!['no-executor'] as bool;
    }

    // Convert name to snake_case for folder
    final featureFolderName = _toSnakeCase(name);
    final featureDir = path.isAbsolute(outputBase)
        ? path.join(outputBase, featureFolderName)
        : path.join(Directory.current.path, outputBase, featureFolderName);

    _logger.info('');
    _logger.info('Creating $name feature with ${stateManagement.name}...');
    _logger.info('');

    final allFiles = <String>[];

    try {
      // 1. Generate Job (if not skipped)
      if (!skipJob) {
        final jobDir = path.join(featureDir, 'jobs');
        final progress = _logger.progress('Creating job');
        final files = await BrickLoader.generate(
          type: BrickType.job,
          vars: {'name': name},
          outputDir: jobDir,
        );
        progress.complete('Created job');
        allFiles.addAll(files.map((f) => f.path));
      }

      // 2. Generate Executor (if not skipped)
      if (!skipExecutor) {
        final executorDir = path.join(featureDir, 'executors');
        final progress = _logger.progress('Creating executor');
        final files = await BrickLoader.generate(
          type: BrickType.executor,
          vars: {'name': name},
          outputDir: executorDir,
        );
        progress.complete('Created executor');
        allFiles.addAll(files.map((f) => f.path));
      }

      // 3. Generate State Management
      final stateDir = _getStateDir(featureDir, stateManagement);
      final smProgress = _logger.progress('Creating ${stateManagement.name}');
      final smFiles = await _generateStateManagement(
        name: name,
        outputDir: stateDir,
        stateManagement: stateManagement,
      );
      smProgress.complete('Created ${stateManagement.name}');
      allFiles.addAll(smFiles);

      // 4. Generate barrel file
      final barrelProgress = _logger.progress('Creating barrel file');
      await _generateBarrelFile(
        featureDir: featureDir,
        featureName: name,
        stateManagement: stateManagement,
        skipJob: skipJob,
        skipExecutor: skipExecutor,
      );
      barrelProgress.complete('Created barrel file');
      allFiles.add(path.join(featureDir, '$featureFolderName.dart'));

      _logger.info('');
      _logger.success('✓ Created ${allFiles.length} file(s) in $featureDir');
      _logger.info('');

      // Show created files
      for (final file in allFiles) {
        _logger.detail('  ${path.relative(file)}');
      }

      _logger.info('');
      _logger.info('Next steps:');
      _logger.detail('  1. Add parameters to the job class');
      _logger.detail('  2. Implement business logic in the executor');
      _logger.detail('  3. Add state fields and handle events in the ${stateManagement.name}');
      _logger.detail('  4. Register the executor with Dispatcher');

      return 0;
    } catch (e) {
      _logger.error('Failed to create feature: $e');
      return 1;
    }
  }

  Future<_InteractiveResult?> _runInteractive(OrchestratorConfig config) async {
    _logger.alert('🚀 Create Feature Wizard');
    _logger.info('');

    // 1. Get feature name
    stdout.write('Feature name (e.g., User, Product, Auth): ');
    final name = stdin.readLineSync()?.trim();
    if (name == null || name.isEmpty) {
      _logger.error('Feature name is required');
      return null;
    }

    // 2. Select state management
    final stateManagementStr = _logger.chooseOne(
      'Select state management:',
      choices: ['cubit', 'provider', 'riverpod'],
      defaultValue: config.stateManagement,
    );
    final stateManagement = StateManagement.values.firstWhere(
      (e) => e.name == stateManagementStr,
    );

    // 3. Include job?
    final includeJob = _logger.confirm(
      'Include job file?',
      defaultValue: config.feature.includeJob,
    );

    // 4. Include executor?
    final includeExecutor = _logger.confirm(
      'Include executor file?',
      defaultValue: config.feature.includeExecutor,
    );

    // 5. Output directory
    stdout.write('Output directory [${config.output.features}]: ');
    final outputInput = stdin.readLineSync()?.trim();
    final outputBase = outputInput?.isNotEmpty == true 
        ? outputInput! 
        : config.output.features;

    return _InteractiveResult(
      name: name,
      outputBase: outputBase,
      stateManagement: stateManagement,
      skipJob: !includeJob,
      skipExecutor: !includeExecutor,
    );
  }

  String _getStateDir(String featureDir, StateManagement sm) {
    switch (sm) {
      case StateManagement.cubit:
        return path.join(featureDir, 'cubit');
      case StateManagement.provider:
      case StateManagement.riverpod:
        return path.join(featureDir, 'notifier');
    }
  }

  Future<List<String>> _generateStateManagement({
    required String name,
    required String outputDir,
    required StateManagement stateManagement,
  }) async {
    final BrickType brickType;
    switch (stateManagement) {
      case StateManagement.cubit:
        brickType = BrickType.cubit;
      case StateManagement.provider:
        brickType = BrickType.notifier;
      case StateManagement.riverpod:
        brickType = BrickType.riverpod;
    }

    final files = await BrickLoader.generate(
      type: brickType,
      vars: {'name': name},
      outputDir: outputDir,
    );

    return files.map((f) => f.path).toList();
  }

  Future<void> _generateBarrelFile({
    required String featureDir,
    required String featureName,
    required StateManagement stateManagement,
    required bool skipJob,
    required bool skipExecutor,
  }) async {
    final snakeName = _toSnakeCase(featureName);
    final buffer = StringBuffer();

    buffer.writeln("/// $featureName feature exports");
    buffer.writeln("library;");
    buffer.writeln();

    // Export job
    if (!skipJob) {
      buffer.writeln("export 'jobs/${snakeName}_job.dart';");
    }

    // Export executor
    if (!skipExecutor) {
      buffer.writeln("export 'executors/${snakeName}_executor.dart';");
    }

    // Export state management
    switch (stateManagement) {
      case StateManagement.cubit:
        buffer.writeln("export 'cubit/${snakeName}_cubit.dart';");
        buffer.writeln("export 'cubit/${snakeName}_state.dart';");
      case StateManagement.provider:
      case StateManagement.riverpod:
        buffer.writeln("export 'notifier/${snakeName}_notifier.dart';");
        buffer.writeln("export 'notifier/${snakeName}_state.dart';");
    }

    final barrelFile = File(path.join(featureDir, '$snakeName.dart'));
    await barrelFile.parent.create(recursive: true);
    await barrelFile.writeAsString(buffer.toString());
  }

  String _toSnakeCase(String input) {
    return input
        .replaceAllMapped(
          RegExp(r'([A-Z])'),
          (match) => '_${match.group(1)!.toLowerCase()}',
        )
        .replaceFirst(RegExp(r'^_'), '');
  }
}

class _InteractiveResult {
  final String name;
  final String outputBase;
  final StateManagement stateManagement;
  final bool skipJob;
  final bool skipExecutor;

  _InteractiveResult({
    required this.name,
    required this.outputBase,
    required this.stateManagement,
    required this.skipJob,
    required this.skipExecutor,
  });
}
