import 'package:mocktail/mocktail.dart';
import 'package:orchestrator_core/orchestrator_core.dart';

/// A mock implementation of [BaseExecutor] for testing.
///
/// Use this with [mocktail] to stub the [process] method and verify calls.
///
/// ## Example
///
/// ```dart
/// class MockMyExecutor extends MockExecutor<MyJob> {}
///
/// final mockExecutor = MockMyExecutor();
/// when(() => mockExecutor.process(any())).thenAnswer((_) async => 'result');
/// ```
///
/// ## Note
///
/// You need to create a concrete subclass for each job type you want to mock.
class MockExecutor<T extends BaseJob> extends Mock implements BaseExecutor<T> {}

/// A fake [BaseExecutor] that captures processed jobs and returns predefined results.
///
/// This is useful when you want to verify that jobs are processed correctly
/// without needing to stub individual calls.
///
/// ## Example
///
/// ```dart
/// final executor = FakeExecutor<MyJob>((job) async => 'result for ${job.id}');
/// dispatcher.register(executor);
///
/// dispatcher.dispatch(MyJob());
///
/// expect(executor.processedJobs, hasLength(1));
/// ```
class FakeExecutor<T extends BaseJob> extends BaseExecutor<T> {
  /// Creates a [FakeExecutor] with a custom processor function.
  ///
  /// The [processor] function is called for each job and should return
  /// the result of processing the job.
  FakeExecutor(Future<dynamic> Function(T job) processor)
      : _processor = processor;

  /// Creates a [FakeExecutor] that always returns the same result.
  FakeExecutor.withResult(dynamic result) : _processor = ((_) async => result);

  /// Creates a [FakeExecutor] that always throws an error.
  FakeExecutor.withError(Object error)
      : _processor = ((_) async => throw error);

  /// Creates a [FakeExecutor] that always returns `null`.
  FakeExecutor.noResult() : _processor = ((_) async => null);

  /// All jobs that have been processed.
  final List<T> processedJobs = [];

  /// The function to call when processing a job.
  final Future<dynamic> Function(T job) _processor;

  @override
  Future<dynamic> process(T job) async {
    processedJobs.add(job);
    return _processor(job);
  }

  /// Get the last processed job, or `null` if none.
  T? get lastJob => processedJobs.isEmpty ? null : processedJobs.last;

  /// Clear all processed jobs.
  void clear() {
    processedJobs.clear();
  }
}
