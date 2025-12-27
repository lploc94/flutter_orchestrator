// ignore_for_file: avoid_print

/// Example usage of orchestrator_cli.
///
/// This CLI tool provides commands to scaffold Orchestrator components.
///
/// ## Installation
/// ```bash
/// dart pub global activate orchestrator_cli
/// ```
///
/// ## Usage
/// ```bash
/// # Initialize project structure
/// orchestrator init
///
/// # Create a new Job
/// orchestrator create job FetchUsers
///
/// # Create a new Executor
/// orchestrator create executor FetchUsers
///
/// # Create a full feature
/// orchestrator create feature Auth
///
/// # Run doctor to check setup
/// orchestrator doctor
/// ```
void main(List<String> args) {
  print('Run: dart pub global activate orchestrator_cli');
  print('Then: orchestrator --help');
}
