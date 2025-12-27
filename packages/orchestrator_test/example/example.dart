// ignore_for_file: avoid_print

import 'package:orchestrator_core/orchestrator_core.dart';
import 'package:orchestrator_test/orchestrator_test.dart';

/// Example usage of orchestrator_test package.
///
/// This example demonstrates how to use the testing utilities
/// provided by orchestrator_test to write unit tests for
/// Orchestrator-based applications.
void main() {
  // 1. Using FakeDispatcher
  final dispatcher = FakeDispatcher();

  // Dispatch a job
  dispatcher.dispatch(FetchUserJob(userId: '123'));

  // Verify job was dispatched
  print('Dispatched jobs: ${dispatcher.dispatchedJobs}');
  print('Has dispatched jobs: ${dispatcher.dispatchedJobs.isNotEmpty}');

  // 2. Using FakeSignalBus
  final bus = FakeSignalBus();

  // Emit events (using positional parameters as per actual API)
  bus.emit(JobStartedEvent('job-1', jobType: 'FetchUserJob'));
  bus.emit(JobSuccessEvent<String>('job-1', 'Hello'));

  // Verify events
  print('Emitted events: ${bus.emittedEvents}');

  // 3. Using FakeCacheProvider
  final cache = FakeCacheProvider();

  // Write and read cache
  cache.write('user:123', {'name': 'John'});
  print('Cache read: ${cache.read('user:123')}');

  // 4. Using EventCapture
  final capture = EventCapture(bus);

  bus.emit(JobProgressEvent('job-2', progress: 0.5));

  // Verify captured events
  print('Captured events: ${capture.events}');

  // 5. Using matchers (in actual tests)
  // expect(event, isJobSuccess<String>());
  // expect(event, isJobFailure());

  print('Example completed successfully!');
}

// Example Job for demonstration
class FetchUserJob extends BaseJob {
  FetchUserJob({required this.userId}) : super(id: 'fetch-user-$userId');

  final String userId;
}
