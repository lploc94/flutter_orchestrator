import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as path;

import '../../utils/brick_loader.dart';
import '../../utils/logger.dart';

/// Command to create an OrchestratorCubit with State (Bloc integration)
class CubitCommand extends Command<int> {
  final CliLogger _logger = CliLogger();

  @override
  final String name = 'cubit';

  @override
  final String description = 'Create an OrchestratorCubit with State (Bloc integration)';

  @override
  final String invocation = 'orchestrator create cubit <name>';

  CubitCommand() {
    argParser.addOption(
      'output',
      abbr: 'o',
      help: 'Output directory for the generated files',
      defaultsTo: BrickLoader.getDefaultOutputDir(BrickType.cubit),
    );
  }

  @override
  Future<int> run() async {
    final args = argResults!.rest;
    
    if (args.isEmpty) {
      _logger.error('Please provide a name for the cubit.');
      _logger.info('Usage: orchestrator create cubit <name>');
      return 1;
    }

    final name = args.first;
    final outputDir = argResults!['output'] as String;
    final absoluteOutputDir = path.isAbsolute(outputDir) 
        ? outputDir 
        : path.join(Directory.current.path, outputDir);

    final progress = _logger.progress('Creating $name cubit');

    try {
      final files = await BrickLoader.generate(
        type: BrickType.cubit,
        vars: {'name': name},
        outputDir: absoluteOutputDir,
      );

      progress.complete('Created ${files.length} file(s)');

      for (final file in files) {
        _logger.success('  ${path.relative(file.path)}');
      }

      _logger.info('');
      _logger.info('Next steps:');
      _logger.detail('  1. Add data fields to the state class');
      _logger.detail('  2. Add methods to trigger jobs');
      _logger.detail('  3. Handle success/failure events in onActiveSuccess/onActiveFailure');
      _logger.detail('  4. Provide the cubit with BlocProvider');

      return 0;
    } catch (e) {
      progress.fail('Failed to create cubit');
      _logger.error(e.toString());
      return 1;
    }
  }
}
