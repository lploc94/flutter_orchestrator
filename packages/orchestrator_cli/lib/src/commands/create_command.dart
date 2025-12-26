import 'package:args/command_runner.dart';

import 'subcommands/job_command.dart';
import 'subcommands/executor_command.dart';
import 'subcommands/state_command.dart';
import 'subcommands/cubit_command.dart';
import 'subcommands/notifier_command.dart';
import 'subcommands/riverpod_command.dart';
import 'subcommands/feature_command.dart';

/// Main "create" command that groups all scaffolding subcommands
class CreateCommand extends Command<int> {
  @override
  final String name = 'create';

  @override
  final String description = 'Create Orchestrator components (job, executor, cubit, feature, etc.)';

  CreateCommand() {
    addSubcommand(JobCommand());
    addSubcommand(ExecutorCommand());
    addSubcommand(StateCommand());
    addSubcommand(CubitCommand());
    addSubcommand(NotifierCommand());
    addSubcommand(RiverpodCommand());
    addSubcommand(FeatureCommand());
  }

  @override
  Future<int> run() async {
    // If no subcommand is provided, show usage
    printUsage();
    return 0;
  }
}
