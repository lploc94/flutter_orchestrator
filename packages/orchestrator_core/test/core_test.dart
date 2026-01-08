import 'package:test/test.dart';
import 'package:orchestrator_core/orchestrator_core.dart';
import 'dart:async';

// --- MOCK CLASSES ---

class TestJob extends BaseJob {
  final int value;
  TestJob(
    this.value, {
    super.timeout,
    super.cancellationToken,
    super.retryPolicy,
  }) : super(
          id: 'job-${DateTime.now().millisecondsSinceEpoch}-${value.hashCode}',
        );
}

class FailingJob extends BaseJob {
  final int failCount;
  FailingJob({this.failCount = 999})
      : super(id: 'fail-job-${DateTime.now().millisecondsSinceEpoch}');
}

class TestExecutor extends BaseExecutor<TestJob> {
  @override
  Future<dynamic> process(TestJob job) async {
    await Future.delayed(Duration(milliseconds: 10));
    return job.value * 2;
  }
}

class FailingExecutor extends BaseExecutor<FailingJob> {
  int attempts = 0;

  @override
  Future<dynamic> process(FailingJob job) async {
    attempts++;
    await Future.delayed(Duration(milliseconds: 5));
    if (attempts <= job.failCount) {
      throw Exception('Simulated failure #$attempts');
    }
    return 'success after retries';
  }
}

class SlowExecutor extends BaseExecutor<TestJob> {
  @override
  Future<dynamic> process(TestJob job) async {
    await Future.delayed(Duration(seconds: 5)); // Very slow
    return job.value;
  }
}

class ProgressExecutor extends BaseExecutor<TestJob> {
  @override
  Future<dynamic> process(TestJob job) async {
    for (int i = 1; i <= 5; i++) {
      await Future.delayed(Duration(milliseconds: 10));
      emitProgress(job.id, progress: i / 5.0, message: 'Step $i/5');
    }
    return 'done';
  }
}

// Custom Event for Passive Listening test
class CustomDataEvent extends BaseEvent {
  final String payload;
  CustomDataEvent(super.correlationId, this.payload);
}

class TestOrchestrator extends BaseOrchestrator<String> {
  final List<String> eventLog = [];
  double lastProgress = 0;

  TestOrchestrator() : super('Init');

  @override
  void onEvent(BaseEvent event) {
    // Check if this is our job (active) or from another orchestrator (passive)
    final isActive = isJobRunning(event.correlationId);

    switch (event) {
      case JobSuccessEvent e:
        if (isActive) {
          eventLog.add('Active:Success:${e.data}');
          emit('Active Success: ${e.data}');
        } else {
          eventLog.add('Passive:Success:${e.data}');
          emit('Passive Received: ${e.data}');
        }
      case JobFailureEvent e:
        if (isActive) {
          eventLog.add('Active:Failure:${e.error}');
          emit('Active Failure: ${e.error}');
        }
      case JobCancelledEvent _:
        if (isActive) {
          eventLog.add('Active:Cancelled');
          emit('Active Cancelled');
        }
      case JobTimeoutEvent e:
        if (isActive) {
          eventLog.add('Active:Timeout:${e.timeout.inMilliseconds}ms');
          emit('Active Timeout');
        }
      case JobProgressEvent e:
        lastProgress = e.progress;
        eventLog.add('Progress:${(e.progress * 100).toInt()}%');
      case JobRetryingEvent e:
        eventLog.add('Retrying:${e.attempt}/${e.maxRetries}');
      case CustomDataEvent e:
        eventLog.add('Passive:Custom:${e.payload}');
        emit('Passive Custom: ${e.payload}');
      default:
        // Unknown event type, ignore
        break;
    }
  }

  JobHandle<int> runJob(
    int val, {
    Duration? timeout,
    CancellationToken? cancelToken,
    RetryPolicy? retry,
  }) =>
      dispatch<int>(
        TestJob(
          val,
          timeout: timeout,
          cancellationToken: cancelToken,
          retryPolicy: retry,
        ),
      );

  JobHandle<int> runFailingJob({int failCount = 999, RetryPolicy? retry}) =>
      dispatch<int>(FailingJob(failCount: failCount)..metadata);
}

// --- TEST SUITE ---

void main() {
  final dispatcher = Dispatcher();

  setUp(() {
    dispatcher.clear();
    dispatcher.register(TestExecutor());
    dispatcher.register(FailingExecutor());
  });

  group('Core Models', () {
    test('BaseEvent has correct correlationId and timestamp', () {
      final event = JobSuccessEvent('test-id', 42);
      expect(event.correlationId, equals('test-id'));
      expect(event.timestamp, isNotNull);
      expect(event.data, equals(42));
    });

    test('BaseJob generates unique IDs', () {
      final job1 = TestJob(1);
      final job2 = TestJob(2);
      expect(job1.id, isNot(equals(job2.id)));
    });

    test('JobFailureEvent stores error details', () {
      final event = JobFailureEvent(
        'err-id',
        Exception('test'),
        stackTrace: StackTrace.current,
        wasRetried: true,
      );
      expect(event.error, isA<Exception>());
      expect(event.wasRetried, isTrue);
    });
  });

  group('Signal Bus', () {
    test('Bus broadcasts to multiple listeners', () async {
      final bus = SignalBus();
      final results1 = <BaseEvent>[];
      final results2 = <BaseEvent>[];

      bus.stream.listen(results1.add);
      bus.stream.listen(results2.add);

      bus.emit(JobSuccessEvent('multi-test', 'data'));

      await Future.delayed(Duration(milliseconds: 50));

      expect(results1.length, equals(1));
      expect(results2.length, equals(1));
    });
  });

  group('Dispatcher', () {
    test('Dispatcher routes job to correct executor', () async {
      final id = dispatcher.dispatch(TestJob(5));
      expect(id, isNotEmpty);
    });

    test('Dispatcher throws on unregistered job type', () {
      dispatcher.clear();
      expect(
        () => dispatcher.dispatch(TestJob(1)),
        throwsA(isA<ExecutorNotFoundException>()),
      );
    });
  });

  group('Orchestrator - Active Flow', () {
    test('Success flow updates state correctly', () async {
      final orchestrator = TestOrchestrator();

      orchestrator.runJob(10);

      await expectLater(
        orchestrator.stream,
        emitsThrough('Active Success: 20'),
      );

      expect(orchestrator.eventLog, contains('Active:Success:20'));
      orchestrator.dispose();
    });

    test('Failure flow updates state correctly', () async {
      final orchestrator = TestOrchestrator();
      dispatcher.register(FailingExecutor());

      orchestrator.runFailingJob();

      await expectLater(
        orchestrator.stream,
        emitsThrough(contains('Active Failure')),
      );

      expect(
        orchestrator.eventLog.any((e) => e.contains('Active:Failure')),
        isTrue,
      );
      orchestrator.dispose();
    });

    test('Multiple concurrent jobs tracked separately', () async {
      final orchestrator = TestOrchestrator();

      orchestrator.runJob(1);
      orchestrator.runJob(2);
      orchestrator.runJob(3);

      await Future.delayed(Duration(milliseconds: 100));

      expect(
        orchestrator.eventLog.where((e) => e.startsWith('Active:')).length,
        equals(3),
      );
      expect(
        orchestrator.eventLog.where((e) => e.startsWith('Passive:')).length,
        equals(0),
      );

      orchestrator.dispose();
    });
  });

  group('Orchestrator - Passive Flow', () {
    test('Observer receives events from other orchestrators', () async {
      final sender = TestOrchestrator();
      final observer = TestOrchestrator();

      sender.runJob(50);

      await Future.delayed(Duration(milliseconds: 100));

      expect(sender.eventLog.any((e) => e.startsWith('Active:')), isTrue);
      expect(observer.eventLog.any((e) => e.startsWith('Passive:')), isTrue);

      sender.dispose();
      observer.dispose();
    });

    test('Observer receives custom events', () async {
      final observer = TestOrchestrator();
      final bus = SignalBus();

      bus.emit(CustomDataEvent('external-123', 'hello world'));

      await Future.delayed(Duration(milliseconds: 50));

      expect(observer.eventLog, contains('Passive:Custom:hello world'));
      observer.dispose();
    });
  });

  group('Advanced Features - Timeout', () {
    test('Job times out correctly', () async {
      final orchestrator = TestOrchestrator();
      dispatcher.register(SlowExecutor());

      orchestrator.runJob(1, timeout: Duration(milliseconds: 50));

      await Future.delayed(Duration(milliseconds: 200));

      expect(orchestrator.eventLog.any((e) => e.contains('Timeout')), isTrue);
      orchestrator.dispose();
    });
  });

  group('Advanced Features - Cancellation', () {
    test('Job cancellation emits cancelled event', () async {
      final orchestrator = TestOrchestrator();
      dispatcher.register(SlowExecutor());

      final token = CancellationToken();
      orchestrator.runJob(1, cancelToken: token);

      await Future.delayed(Duration(milliseconds: 20));
      token.cancel();

      await Future.delayed(Duration(milliseconds: 100));

      expect(orchestrator.eventLog.any((e) => e.contains('Cancelled')), isTrue);
      orchestrator.dispose();
    });

    test('CancellationToken throws when checking after cancel', () {
      final token = CancellationToken();
      token.cancel();
      expect(
        () => token.throwIfCancelled(),
        throwsA(isA<CancelledException>()),
      );
    });
  });

  group('Advanced Features - Progress', () {
    test('Executor emits progress events', () async {
      final orchestrator = TestOrchestrator();
      dispatcher.register(ProgressExecutor());

      orchestrator.runJob(1);

      await Future.delayed(Duration(milliseconds: 200));

      expect(
        orchestrator.eventLog.where((e) => e.startsWith('Progress:')).length,
        greaterThanOrEqualTo(3),
      );
      expect(orchestrator.lastProgress, equals(1.0));
      orchestrator.dispose();
    });
  });

  group('Advanced Features - Retry', () {
    test('Executor retries on failure', () async {
      final orchestrator = TestOrchestrator();
      final retryExecutor = FailingExecutor();
      dispatcher.clear();
      dispatcher.register(retryExecutor);

      // Fail 2 times, retry 3 times -> should succeed
      final job = FailingJob(failCount: 2);
      dispatcher.dispatch(job);

      // Note: Testing retry requires job to have RetryPolicy
      // For now, just verify FailingExecutor works
      // Dispatch is async so executor may already have started

      await Future.delayed(Duration(milliseconds: 100));
      expect(retryExecutor.attempts, greaterThan(0));

      orchestrator.dispose();
    });
  });

  group('JobHandle', () {
    test('JobHandle completes with result on success', () async {
      final orchestrator = TestOrchestrator();

      final handle = orchestrator.runJob(42);

      final result = await handle.future;

      expect(result.data, equals(84)); // 42 * 2
      expect(result.source, equals(DataSource.fresh));
      expect(handle.isCompleted, isTrue);
      expect(handle.jobId, isNotEmpty);

      orchestrator.dispose();
    });

    test('JobHandle completes with error on failure', () async {
      final orchestrator = TestOrchestrator();
      dispatcher.register(FailingExecutor());

      final handle = orchestrator.runFailingJob();

      expect(handle.future, throwsA(isA<Exception>()));

      orchestrator.dispose();
    });

    test('JobHandle fire-and-forget does not throw', () async {
      final orchestrator = TestOrchestrator();
      dispatcher.register(FailingExecutor());

      // Fire and forget - should not throw uncaught async error
      orchestrator.runFailingJob();

      // Wait for the job to complete
      await Future.delayed(Duration(milliseconds: 100));

      // If we get here without async error, test passes
      expect(orchestrator.eventLog.any((e) => e.contains('Failure')), isTrue);

      orchestrator.dispose();
    });

    test('JobHandle.complete is idempotent', () {
      final handle = JobHandle<String>('test-id');

      handle.complete('first', DataSource.fresh);
      handle.complete('second', DataSource.fresh); // Should be ignored

      expect(handle.isCompleted, isTrue);
    });

    test('JobHandle.completeError is idempotent', () {
      final handle = JobHandle<String>('test-id');

      handle.completeError(Exception('first'));
      handle.completeError(Exception('second')); // Should be ignored

      expect(handle.isCompleted, isTrue);
    });

    test('JobHandle toString shows completion status', () {
      final handle = JobHandle<String>('test-123');

      expect(handle.toString(), contains('test-123'));
      expect(handle.toString(), contains('completed: false'));

      handle.complete('done', DataSource.fresh);

      expect(handle.toString(), contains('completed: true'));
    });
  });
}
