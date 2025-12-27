import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as path;

import '../../utils/brick_loader.dart';
import '../../utils/logger.dart';

/// Command to create a Job class
class JobCommand extends Command<int> {
  final CliLogger _logger = CliLogger();

  @override
  final String name = 'job';

  @override
  final String description = 'Create an Orchestrator Job class';

  @override
  final String invocation = 'orchestrator create job <name>';

  JobCommand() {
    argParser.addOption(
      'output',
      abbr: 'o',
      help: 'Output directory for the generated file',
      defaultsTo: BrickLoader.getDefaultOutputDir(BrickType.job),
    );
  }

  @override
  Future<int> run() async {
    final args = argResults!.rest;

    if (args.isEmpty) {
      _logger.error('Please provide a name for the job.');
      _logger.info('Usage: orchestrator create job <name>');
      return 1;
    }

    final name = args.first;
    final outputDir = argResults!['output'] as String;
    final absoluteOutputDir = path.isAbsolute(outputDir)
        ? outputDir
        : path.join(Directory.current.path, outputDir);

    final progress = _logger.progress('Creating $name job');

    try {
      final files = await BrickLoader.generate(
        type: BrickType.job,
        vars: {'name': name},
        outputDir: absoluteOutputDir,
      );

      progress.complete('Created ${files.length} file(s)');

      for (final file in files) {
        _logger.success('  ${path.relative(file.path)}');
      }

      _logger.info('');
      _logger.info('Next steps:');
      _logger.detail('  1. Add job parameters as needed');
      _logger.detail('  2. Create a corresponding executor');
      _logger.detail('  3. Register the executor with Dispatcher');

      return 0;
    } catch (e) {
      progress.fail('Failed to create job');
      _logger.error(e.toString());
      return 1;
    }
  }
}
