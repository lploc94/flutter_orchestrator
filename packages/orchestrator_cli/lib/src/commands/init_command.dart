import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as path;

import '../utils/logger.dart';

/// Command to initialize Orchestrator project structure
class InitCommand extends Command<int> {
  final CliLogger _logger = CliLogger();

  @override
  final String name = 'init';

  @override
  final String description = 'Initialize Orchestrator project structure';

  @override
  final String invocation = 'orchestrator init';

  InitCommand() {
    argParser
      ..addOption(
        'state-management',
        abbr: 's',
        help: 'Default state management solution',
        allowed: ['cubit', 'provider', 'riverpod'],
        defaultsTo: 'cubit',
      )
      ..addFlag(
        'force',
        abbr: 'f',
        help: 'Overwrite existing configuration',
        defaultsTo: false,
        negatable: false,
      );
  }

  @override
  Future<int> run() async {
    final stateManagement = argResults!['state-management'] as String;
    final force = argResults!['force'] as bool;

    final currentDir = Directory.current.path;
    
    _logger.info('Initializing Orchestrator project structure...');
    _logger.info('');

    try {
      // 1. Create folder structure
      await _createFolderStructure(currentDir);

      // 2. Create orchestrator.yaml config file
      await _createConfigFile(currentDir, stateManagement, force);

      _logger.info('');
      _logger.success('✓ Orchestrator project initialized successfully!');
      _logger.info('');
      _logger.info('Created structure:');
      _logger.detail('  lib/');
      _logger.detail('    ├── features/       # Feature modules');
      _logger.detail('    ├── core/');
      _logger.detail('    │   ├── jobs/       # Shared jobs');
      _logger.detail('    │   ├── executors/  # Shared executors');
      _logger.detail('    │   └── di/         # Dependency injection');
      _logger.detail('    └── shared/         # Shared utilities');
      _logger.detail('  orchestrator.yaml     # CLI configuration');
      _logger.info('');
      _logger.info('Next steps:');
      _logger.detail('  1. Add orchestrator packages to pubspec.yaml');
      _logger.detail('  2. Create your first feature: orchestrator create feature <name>');
      _logger.detail('  3. Set up Dispatcher and register executors in lib/core/di/');

      return 0;
    } catch (e) {
      _logger.error('Failed to initialize: $e');
      return 1;
    }
  }

  Future<void> _createFolderStructure(String baseDir) async {
    final folders = [
      'lib/features',
      'lib/core/jobs',
      'lib/core/executors',
      'lib/core/di',
      'lib/shared',
    ];

    for (final folder in folders) {
      final dir = Directory(path.join(baseDir, folder));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
        _logger.success('  Created $folder/');
      } else {
        _logger.detail('  $folder/ already exists');
      }
    }

    // Create .gitkeep files to preserve empty directories
    for (final folder in folders) {
      final gitkeep = File(path.join(baseDir, folder, '.gitkeep'));
      if (!await gitkeep.exists()) {
        await gitkeep.create();
      }
    }
  }

  Future<void> _createConfigFile(
    String baseDir,
    String stateManagement,
    bool force,
  ) async {
    final configFile = File(path.join(baseDir, 'orchestrator.yaml'));

    if (await configFile.exists() && !force) {
      _logger.warn('  orchestrator.yaml already exists (use --force to overwrite)');
      return;
    }

    final config = '''
# Orchestrator CLI Configuration
# This file configures default options for the orchestrator CLI tool.

# Default state management solution
# Options: cubit, provider, riverpod
state_management: $stateManagement

# Output paths for generated files
output:
  features: lib/features
  jobs: lib/core/jobs
  executors: lib/core/executors

# Feature structure
feature:
  # Include job in feature scaffold
  include_job: true
  # Include executor in feature scaffold
  include_executor: true
  # Generate barrel file for feature
  generate_barrel: true
''';

    await configFile.writeAsString(config);
    _logger.success('  Created orchestrator.yaml');
  }
}
