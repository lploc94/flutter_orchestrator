import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as path;

import '../../utils/brick_loader.dart';
import '../../utils/logger.dart';

/// Command to create an OrchestratorNotifier with State (Riverpod integration)
class RiverpodCommand extends Command<int> {
  final CliLogger _logger = CliLogger();

  @override
  final String name = 'riverpod';

  @override
  final String description = 'Create an OrchestratorNotifier with State (Riverpod integration)';

  @override
  final String invocation = 'orchestrator create riverpod <name>';

  RiverpodCommand() {
    argParser.addOption(
      'output',
      abbr: 'o',
      help: 'Output directory for the generated files',
      defaultsTo: BrickLoader.getDefaultOutputDir(BrickType.riverpod),
    );
  }

  @override
  Future<int> run() async {
    final args = argResults!.rest;
    
    if (args.isEmpty) {
      _logger.error('Please provide a name for the notifier.');
      _logger.info('Usage: orchestrator create riverpod <name>');
      return 1;
    }

    final name = args.first;
    final outputDir = argResults!['output'] as String;
    final absoluteOutputDir = path.isAbsolute(outputDir) 
        ? outputDir 
        : path.join(Directory.current.path, outputDir);

    final progress = _logger.progress('Creating $name Riverpod notifier');

    try {
      final files = await BrickLoader.generate(
        type: BrickType.riverpod,
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
      _logger.detail('  4. Use the generated provider: ref.watch(${_toCamelCase(name)}Provider)');

      return 0;
    } catch (e) {
      progress.fail('Failed to create Riverpod notifier');
      _logger.error(e.toString());
      return 1;
    }
  }

  String _toCamelCase(String name) {
    if (name.isEmpty) return name;
    return name[0].toLowerCase() + name.substring(1);
  }
}
