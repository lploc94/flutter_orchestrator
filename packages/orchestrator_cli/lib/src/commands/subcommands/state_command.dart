import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as path;

import '../../utils/brick_loader.dart';
import '../../utils/logger.dart';

/// Command to create a State class
class StateCommand extends Command<int> {
  final CliLogger _logger = CliLogger();

  @override
  final String name = 'state';

  @override
  final String description = 'Create an immutable State class with copyWith';

  @override
  final String invocation = 'orchestrator create state <name>';

  StateCommand() {
    argParser.addOption(
      'output',
      abbr: 'o',
      help: 'Output directory for the generated file',
      defaultsTo: BrickLoader.getDefaultOutputDir(BrickType.state),
    );
  }

  @override
  Future<int> run() async {
    final args = argResults!.rest;

    if (args.isEmpty) {
      _logger.error('Please provide a name for the state.');
      _logger.info('Usage: orchestrator create state <name>');
      return 1;
    }

    final name = args.first;
    final outputDir = argResults!['output'] as String;
    final absoluteOutputDir = path.isAbsolute(outputDir)
        ? outputDir
        : path.join(Directory.current.path, outputDir);

    final progress = _logger.progress('Creating $name state');

    try {
      final files = await BrickLoader.generate(
        type: BrickType.state,
        vars: {'name': name},
        outputDir: absoluteOutputDir,
      );

      progress.complete('Created ${files.length} file(s)');

      for (final file in files) {
        _logger.success('  ${path.relative(file.path)}');
      }

      _logger.info('');
      _logger.info('Next steps:');
      _logger.detail('  1. Add your data fields to the state class');
      _logger.detail('  2. Update copyWith() method to include new fields');
      _logger.detail('  3. Update == and hashCode to include new fields');

      return 0;
    } catch (e) {
      progress.fail('Failed to create state');
      _logger.error(e.toString());
      return 1;
    }
  }
}
