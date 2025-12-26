import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:orchestrator_cli/src/commands/create_command.dart';
import 'package:orchestrator_cli/src/commands/doctor_command.dart';
import 'package:orchestrator_cli/src/commands/init_command.dart';
import 'package:orchestrator_cli/src/commands/list_command.dart';
import 'package:orchestrator_cli/src/commands/template_command.dart';
import 'package:orchestrator_cli/src/utils/logger.dart';

/// CLI version - keep in sync with pubspec.yaml
const String version = '0.1.0';

/// Entry point for the orchestrator CLI
Future<void> main(List<String> args) async {
  final logger = CliLogger();

  // Handle --version flag
  if (args.contains('--version') || args.contains('-v') && args.length == 1) {
    logger.info('orchestrator_cli version $version');
    exit(0);
  }
  
  final runner = CommandRunner<int>(
    'orchestrator',
    '''CLI tool for scaffolding Flutter Orchestrator components.

Create Job, Executor, Cubit, Notifier, Feature and more with ease.

Version: $version

Quick Start:
  orchestrator init                    Initialize project structure
  orchestrator create feature User     Create a full feature scaffold
  orchestrator doctor                  Check project setup

Commands:
  create    Create new components (job, executor, cubit, feature, etc.)
  init      Initialize project structure with folders and config
  doctor    Check project setup and identify issues
  list      List available templates and project components
  template  Manage custom templates''',
  );

  runner.argParser.addFlag(
    'version',
    negatable: false,
    help: 'Print the CLI version',
  );

  runner.addCommand(CreateCommand());
  runner.addCommand(InitCommand());
  runner.addCommand(DoctorCommand());
  runner.addCommand(ListCommand());
  runner.addCommand(TemplateCommand());

  try {
    final exitCode = await runner.run(args);
    exit(exitCode ?? 0);
  } on UsageException catch (e) {
    logger.error(e.message);
    logger.info('');
    logger.info(e.usage);
    exit(64); // EX_USAGE
  } catch (e, stackTrace) {
    logger.error('An unexpected error occurred: $e');
    if (Platform.environment['DEBUG'] == 'true') {
      logger.error(stackTrace.toString());
    }
    exit(1);
  }
}
