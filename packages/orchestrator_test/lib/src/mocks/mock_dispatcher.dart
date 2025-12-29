import 'package:mocktail/mocktail.dart';
import 'package:orchestrator_core/orchestrator_core.dart';

/// A mock implementation of [Dispatcher] for testing.
///
/// Use this with [mocktail] to stub method calls and verify interactions.
///
/// ## Example
///
/// ```dart
/// final mockDispatcher = MockDispatcher();
///
/// // Stub the dispatch method
/// when(() => mockDispatcher.dispatch(any())).thenReturn('job-id');
///
/// // Use in your code
/// final jobId = mockDispatcher.dispatch(MyJob());
///
/// // Verify the call
/// verify(() => mockDispatcher.dispatch(any())).called(1);
/// ```
///
/// ## Registering Fallback Values
///
/// If you need to use `any()` with custom job types, register fallback values:
///
/// ```dart
/// setUpAll(() {
///   registerFallbackValue(MyJob());
/// });
/// ```
class MockDispatcher extends Mock implements Dispatcher {}

/// A fake [Dispatcher] that captures all dispatched jobs for verification.
///
/// Unlike [MockDispatcher], this fake provides a simple implementation
/// that captures jobs and can simulate events without requiring stubbing.
///
/// ## Example
///
/// ```dart
/// final dispatcher = FakeDispatcher();
///
/// // Dispatch a job
/// myOrchestrator.doSomething();
///
/// // Verify what was dispatched
/// expect(dispatcher.dispatchedJobs, hasLength(1));
/// expect(dispatcher.dispatchedJobs.first, isA<MyJob>());
///
/// // Simulate events
/// dispatcher.simulateSuccess('job-id', {'result': 'data'});
/// dispatcher.simulateFailure('job-id', Exception('error'));
/// ```
class FakeDispatcher implements Dispatcher {
  /// Creates a [FakeDispatcher].
  ///
  /// If [autoEmitSuccess] is `true` (default), a [JobSuccessEvent] with
  /// `null` data will be emitted after each dispatch.
  FakeDispatcher({this.autoEmitSuccess = true});

  /// All jobs that have been dispatched.
  final List<BaseJob> dispatchedJobs = [];

  final Map<Type, BaseExecutor> _registry = {};
  final SignalBus _bus = SignalBus.scoped();
  int _idCounter = 0;

  /// Whether to automatically emit [JobSuccessEvent] after dispatch.
  ///
  /// Defaults to `true`. Set to `false` if you want to manually control
  /// when events are emitted using [simulateSuccess] or [simulateFailure].
  bool autoEmitSuccess;

  @override
  int get maxRetries => 5;

  @override
  Map<String, String> get registeredExecutors {
    return _registry.map((jobType, executor) {
      return MapEntry(jobType.toString(), executor.runtimeType.toString());
    });
  }

  @override
  String dispatch(BaseJob job) {
    dispatchedJobs.add(job);
    final id = 'fake-job-${_idCounter++}';

    if (autoEmitSuccess) {
      Future.microtask(() {
        _bus.emit(JobSuccessEvent(id, null));
      });
    }

    return id;
  }

  @override
  void register<T extends BaseJob>(BaseExecutor<T> executor) {
    _registry[T] = executor;
  }

  @override
  void registerByType(Type jobType, BaseExecutor executor) {
    _registry[jobType] = executor;
  }

  @override
  void clear() {
    dispatchedJobs.clear();
    _registry.clear();
  }

  @override
  void dispose() {
    _bus.dispose();
  }

  @override
  void resetForTesting() {
    clear();
    _idCounter = 0;
  }

  /// Simulate a [JobSuccessEvent] for the given job ID.
  void simulateSuccess(String jobId, dynamic data) {
    _bus.emit(JobSuccessEvent(jobId, data));
  }

  /// Simulate a [JobFailureEvent] for the given job ID.
  void simulateFailure(String jobId, Object error, {bool wasRetried = false}) {
    _bus.emit(JobFailureEvent(jobId, error, stackTrace: StackTrace.current, wasRetried: wasRetried));
  }

  /// Simulate a [JobProgressEvent] for the given job ID.
  void simulateProgress(String jobId, double progress, {String? message}) {
    _bus.emit(JobProgressEvent(jobId, progress: progress, message: message));
  }

  /// Simulate a [JobCancelledEvent] for the given job ID.
  void simulateCancelled(String jobId) {
    _bus.emit(JobCancelledEvent(jobId));
  }

  /// Simulate a [JobTimeoutEvent] for the given job ID.
  void simulateTimeout(String jobId, Duration timeout) {
    _bus.emit(JobTimeoutEvent(jobId, timeout));
  }

  /// Get the last dispatched job, or `null` if none.
  BaseJob? get lastJob => dispatchedJobs.isEmpty ? null : dispatchedJobs.last;

  /// Get dispatched jobs of a specific type.
  List<T> jobsOfType<T extends BaseJob>() {
    return dispatchedJobs.whereType<T>().toList();
  }

  /// Clear all dispatched jobs and reset the counter.
  void reset() {
    dispatchedJobs.clear();
    _idCounter = 0;
  }
}
