// @template-name: Counter
// Golden example file for CLI template generation
// Run: dart run scripts/sync_templates.dart

import 'package:orchestrator_core/orchestrator_core.dart';

/// CounterJob - Represents a work request
///
/// Jobs are immutable data classes that describe what work needs to be done.
/// They are dispatched to Executors for processing.
class CounterJob extends BaseJob {
  // TODO: Add job parameters
  // final String userId;

  CounterJob() : super(id: generateJobId('counter'));

  // Example with parameters:
  // CounterJob({required this.userId}) : super(id: generateJobId('counter'));

  // TODO: Override toString for better debugging
  // @override
  // String toString() => 'CounterJob(userId: $userId)';
}
