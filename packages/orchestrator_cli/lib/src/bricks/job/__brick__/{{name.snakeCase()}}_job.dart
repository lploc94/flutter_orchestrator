import 'package:orchestrator_core/orchestrator_core.dart';

/// {{name.pascalCase()}}Job - Represents a work request
///
/// Jobs are immutable data classes that describe what work needs to be done.
/// They are dispatched to Executors for processing.
class {{name.pascalCase()}}Job extends BaseJob {
  // TODO: Add job parameters
  // final String userId;

  {{name.pascalCase()}}Job() : super(id: generateJobId('{{name.snakeCase()}}'));

  // Example with parameters:
  // {{name.pascalCase()}}Job({required this.userId}) : super(id: generateJobId('{{name.snakeCase()}}'));

  // TODO: Override toString for better debugging
  // @override
  // String toString() => '{{name.pascalCase()}}Job(userId: $userId)';
}
