/// CLI tool for scaffolding Flutter Orchestrator components.
///
/// This library provides commands to generate:
/// - Jobs - Work requests dispatched to executors
/// - Executors - Business logic handlers
/// - States - Immutable state classes with copyWith
/// - Cubits - OrchestratorCubit for Bloc integration
/// - Notifiers - OrchestratorNotifier for Provider integration
/// - Riverpod Notifiers - OrchestratorNotifier for Riverpod integration
/// - Features - Full feature scaffolds with all components
///
/// Additional utilities:
/// - Doctor - Check project setup and identify issues
/// - List - Show available templates and project components
/// - Template - Manage custom templates
library;

export 'src/commands/create_command.dart';
export 'src/commands/doctor_command.dart';
export 'src/commands/init_command.dart';
export 'src/commands/list_command.dart';
export 'src/commands/template_command.dart';
export 'src/commands/subcommands/job_command.dart';
export 'src/commands/subcommands/executor_command.dart';
export 'src/commands/subcommands/state_command.dart';
export 'src/commands/subcommands/cubit_command.dart';
export 'src/commands/subcommands/notifier_command.dart';
export 'src/commands/subcommands/riverpod_command.dart';
export 'src/commands/subcommands/feature_command.dart';
export 'src/utils/brick_loader.dart';
export 'src/utils/config_loader.dart';
export 'src/utils/logger.dart';
