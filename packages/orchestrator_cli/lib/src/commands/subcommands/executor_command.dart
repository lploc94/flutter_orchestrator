import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as path;

import '../../utils/brick_loader.dart';
import '../../utils/logger.dart';

/// Command to create an Executor class
class ExecutorCommand extends Command<int> {
  final CliLogger _logger = CliLogger();

  @override
  final String name = 'executor';

  @override
  final String description = 'Create an Orchestrator Executor class';

  @override
  final String invocation = 'orchestrator create executor <name>';

  ExecutorCommand() {
    argParser.addOption(
      'output',
      abbr: 'o',
      help: 'Output directory for the generated file',
      defaultsTo: BrickLoader.getDefaultOutputDir(BrickType.executor),
    );
  }

  @override
  Future<int> run() async {
    final args = argResults!.rest;

    if (args.isEmpty) {
      _logger.error('Please provide a name for the executor.');
      _logger.info('Usage: orchestrator create executor <name>');
      return 1;
    }

    final name = args.first;
    final outputDir = argResults!['output'] as String;
    final absoluteOutputDir = path.isAbsolute(outputDir)
        ? outputDir
        : path.join(Directory.current.path, outputDir);

    final progress = _logger.progress('Creating $name executor');

    try {
      final files = await BrickLoader.generate(
        type: BrickType.executor,
        vars: {'name': name},
        outputDir: absoluteOutputDir,
      );

      progress.complete('Created ${files.length} file(s)');

      for (final file in files) {
        _logger.success('  ${path.relative(file.path)}');
      }

      _logger.info('');
      _logger.info('Next steps:');
      _logger.detail('  1. Import the corresponding job');
      _logger.detail('  2. Add dependencies via constructor injection');
      _logger.detail('  3. Implement the process() method');
      _logger.detail(
          '  4. Register with Dispatcher: dispatcher.register<${name}Job>(${name}Executor());');

      return 0;
    } catch (e) {
      progress.fail('Failed to create executor');
      _logger.error(e.toString());
      return 1;
    }
  }
}
