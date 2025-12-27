import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as path;

import '../utils/brick_loader.dart';
import '../utils/logger.dart';

/// List command - shows available bricks/templates and project info
class ListCommand extends Command<int> {
  ListCommand() {
    argParser.addFlag(
      'verbose',
      abbr: 'v',
      help: 'Show detailed information about each template',
      negatable: false,
    );
    argParser.addFlag(
      'custom',
      abbr: 'c',
      help: 'Only show custom templates',
      negatable: false,
    );
  }

  @override
  String get name => 'list';

  @override
  String get description => 'List available templates and project components';

  @override
  List<String> get aliases => ['ls'];

  @override
  Future<int> run() async {
    final verbose = argResults?['verbose'] as bool? ?? false;
    final customOnly = argResults?['custom'] as bool? ?? false;
    final logger = CliLogger(
      level: verbose ? CliLogLevel.verbose : CliLogLevel.normal,
    );

    logger.info('📦 Orchestrator CLI Templates\n');

    // List bundled templates
    if (!customOnly) {
      logger.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      logger.info('📁 Bundled Templates');
      logger.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      final bundledTemplates = [
        _TemplateInfo(
          name: 'job',
          type: BrickType.job,
          description: 'Creates a Job class (work request)',
          usage: 'orchestrator create job <name>',
          generates: ['<name>_job.dart'],
        ),
        _TemplateInfo(
          name: 'executor',
          type: BrickType.executor,
          description: 'Creates an Executor class (business logic)',
          usage: 'orchestrator create executor <name>',
          generates: ['<name>_executor.dart'],
        ),
        _TemplateInfo(
          name: 'state',
          type: BrickType.state,
          description: 'Creates an immutable State class with copyWith',
          usage: 'orchestrator create state <name>',
          generates: ['<name>_state.dart'],
        ),
        _TemplateInfo(
          name: 'cubit',
          type: BrickType.cubit,
          description: 'Creates OrchestratorCubit + State (Bloc integration)',
          usage: 'orchestrator create cubit <name>',
          generates: ['<name>_cubit.dart', '<name>_state.dart'],
        ),
        _TemplateInfo(
          name: 'notifier',
          type: BrickType.notifier,
          description:
              'Creates OrchestratorNotifier + State (Provider integration)',
          usage: 'orchestrator create notifier <name>',
          generates: ['<name>_notifier.dart', '<name>_state.dart'],
        ),
        _TemplateInfo(
          name: 'riverpod',
          type: BrickType.riverpod,
          description:
              'Creates OrchestratorNotifier + State (Riverpod integration)',
          usage: 'orchestrator create riverpod <name>',
          generates: ['<name>_notifier.dart', '<name>_state.dart'],
        ),
      ];

      for (final template in bundledTemplates) {
        logger.success('  ${template.name}');
        logger.muted('    ${template.description}');
        if (verbose) {
          logger.muted('    Usage: ${template.usage}');
          logger.muted('    Generates: ${template.generates.join(", ")}');
        }
        logger.info('');
      }
    }

    // List custom templates
    final customTemplatesDir = Directory('.orchestrator/templates');
    if (customTemplatesDir.existsSync()) {
      logger.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      logger.info('🎨 Custom Templates');
      logger.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      final customTemplates = customTemplatesDir.listSync();
      if (customTemplates.isEmpty) {
        logger.muted('  No custom templates found');
        logger.muted(
            '  Run `orchestrator template init` to create custom templates');
      } else {
        for (final entity in customTemplates) {
          if (entity is Directory) {
            final templateName = path.basename(entity.path);
            final brickYaml = File(path.join(entity.path, 'brick.yaml'));

            if (brickYaml.existsSync()) {
              logger.success('  $templateName (custom)');
              if (verbose) {
                logger.muted('    Path: ${entity.path}');
              }
            }
          }
        }
      }
      logger.info('');
    } else if (customOnly) {
      logger.warn('No custom templates directory found.');
      logger.muted(
          'Run `orchestrator template init` to create custom templates.');
      return 1;
    }

    // List project components (if in a project)
    final libDir = Directory('lib');
    if (libDir.existsSync()) {
      logger.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      logger.info('📊 Project Components');
      logger.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      final stats = await _scanProjectComponents(libDir);

      logger.muted('  Jobs:       ${stats['jobs']}');
      logger.muted('  Executors:  ${stats['executors']}');
      logger.muted('  Cubits:     ${stats['cubits']}');
      logger.muted('  Notifiers:  ${stats['notifiers']}');
      logger.muted('  States:     ${stats['states']}');
      logger.info('');

      if (stats['unregistered']! > 0) {
        logger.warn(
            '  ⚠ ${stats['unregistered']} executor(s) may not be registered');
        logger.muted('    Run `orchestrator doctor` for details');
      }
    }

    logger.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    logger.info('💡 Tips:');
    logger.muted(
        '  • Use `orchestrator create <template> <name>` to generate code');
    logger.muted('  • Use `orchestrator doctor` to check for issues');
    logger.muted('  • Use `orchestrator init` to set up project structure');
    logger.info('');

    return 0;
  }

  /// Scan project for Orchestrator components
  Future<Map<String, int>> _scanProjectComponents(Directory libDir) async {
    int jobs = 0;
    int executors = 0;
    int cubits = 0;
    int notifiers = 0;
    int states = 0;
    int unregistered = 0;

    final registeredExecutors = <String>{};

    await for (final entity in libDir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        // Skip generated files
        if (entity.path.contains('.g.dart') ||
            entity.path.contains('.freezed.dart')) {
          continue;
        }

        final content = await entity.readAsString();

        // Count Jobs
        final jobMatches =
            RegExp(r'class\s+\w+Job\s+extends\s+BaseJob').allMatches(content);
        jobs += jobMatches.length;

        // Count Executors
        final executorMatches =
            RegExp(r'class\s+(\w+Executor)\s+extends\s+BaseExecutor')
                .allMatches(content);
        executors += executorMatches.length;

        // Count registered executors
        final registerMatches =
            RegExp(r'\.register<\w+>\s*\(\s*(\w+Executor)').allMatches(content);
        for (final match in registerMatches) {
          registeredExecutors.add(match.group(1)!);
        }

        // Count Cubits
        final cubitMatches =
            RegExp(r'class\s+\w+Cubit\s+extends\s+OrchestratorCubit')
                .allMatches(content);
        cubits += cubitMatches.length;

        // Count Notifiers (both Provider and Riverpod)
        final notifierMatches =
            RegExp(r'class\s+\w+Notifier\s+extends\s+OrchestratorNotifier')
                .allMatches(content);
        notifiers += notifierMatches.length;

        // Count States
        final stateMatches =
            RegExp(r'class\s+\w+State\s*\{').allMatches(content);
        states += stateMatches.length;
      }
    }

    // Check for unregistered executors (simplified check)
    if (executors > registeredExecutors.length) {
      unregistered = executors - registeredExecutors.length;
    }

    return {
      'jobs': jobs,
      'executors': executors,
      'cubits': cubits,
      'notifiers': notifiers,
      'states': states,
      'unregistered': unregistered,
    };
  }
}

class _TemplateInfo {
  final String name;
  final BrickType type;
  final String description;
  final String usage;
  final List<String> generates;

  const _TemplateInfo({
    required this.name,
    required this.type,
    required this.description,
    required this.usage,
    required this.generates,
  });
}
