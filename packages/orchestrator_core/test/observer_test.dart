import 'package:test/test.dart';
import 'package:orchestrator_core/orchestrator_core.dart';

// --- Domain Events ---

class SuccessCompletedEvent extends BaseEvent {
  final int result;
  SuccessCompletedEvent(super.correlationId, this.result);
}

class FailCompletedEvent extends BaseEvent {
  FailCompletedEvent(super.correlationId);
}

class ProgressCompletedEvent extends BaseEvent {
  final String result;
  ProgressCompletedEvent(super.correlationId, this.result);
}

// Test observer implementation
class TestObserver extends OrchestratorObserver {
  final List<String> log = [];

  @override
  void onJobStart(EventJob job) {
    log.add('start:${job.runtimeType}:${job.id}');
  }

  @override
  void onJobSuccess(EventJob job, dynamic result, DataSource source) {
    log.add('success:${job.runtimeType}:$result:$source');
  }

  @override
  void onJobError(EventJob job, Object error, StackTrace stack) {
    log.add('error:${job.runtimeType}:$error');
  }

  @override
  void onEvent(BaseEvent event) {
    log.add('event:${event.runtimeType}:${event.correlationId}');
  }
}

// Test jobs
class SuccessJob extends EventJob<int, SuccessCompletedEvent> {
  final int value;
  SuccessJob(this.value);

  @override
  SuccessCompletedEvent createEventTyped(int result) =>
      SuccessCompletedEvent(id, result);
}

class FailJob extends EventJob<void, FailCompletedEvent> {
  FailJob();

  @override
  FailCompletedEvent createEventTyped(void _) => FailCompletedEvent(id);
}

class ProgressJob extends EventJob<String, ProgressCompletedEvent> {
  ProgressJob();

  @override
  ProgressCompletedEvent createEventTyped(String result) =>
      ProgressCompletedEvent(id, result);
}

// Test executors
class SuccessExecutor extends BaseExecutor<SuccessJob> {
  @override
  Future<dynamic> process(SuccessJob job) async {
    await Future.delayed(const Duration(milliseconds: 10));
    return job.value * 2;
  }
}

class FailExecutor extends BaseExecutor<FailJob> {
  @override
  Future<dynamic> process(FailJob job) async {
    await Future.delayed(const Duration(milliseconds: 10));
    throw Exception('Intentional failure');
  }
}

class ProgressExecutor extends BaseExecutor<ProgressJob> {
  @override
  Future<dynamic> process(ProgressJob job) async {
    for (int i = 1; i <= 3; i++) {
      await Future.delayed(const Duration(milliseconds: 10));
      reportProgress(job.id, progress: i / 3.0, message: 'Step $i');
    }
    return 'completed';
  }
}

// Test orchestrator
class TestOrchestrator extends BaseOrchestrator<String> {
  TestOrchestrator() : super('init');

  JobHandle<T> dispatchJob<T>(EventJob job) => dispatch<T>(job);

  @override
  void onEvent(BaseEvent event) {
    switch (event) {
      case SuccessCompletedEvent e:
        emit('success: ${e.result}');
      case FailCompletedEvent _:
        emit('failure');
      default:
        break;
    }
  }
}

void main() {
  group('OrchestratorObserver', () {
    late TestObserver observer;
    late Dispatcher dispatcher;

    setUp(() {
      observer = TestObserver();
      OrchestratorObserver.instance = observer;

      dispatcher = Dispatcher();
      dispatcher.register(SuccessExecutor());
      dispatcher.register(FailExecutor());
      dispatcher.register(ProgressExecutor());
    });

    tearDown(() {
      OrchestratorObserver.instance = null;
      dispatcher.clear();
    });

    group('Job Lifecycle Hooks', () {
      test('onJobStart called when job begins', () async {
        final orchestrator = TestOrchestrator();
        final handle = orchestrator.dispatchJob<int>(SuccessJob(42));

        await handle.future;
        orchestrator.dispose();

        expect(
          observer.log.any((e) => e.startsWith('start:SuccessJob:')),
          isTrue,
        );
      });

      test('onJobSuccess called on successful completion', () async {
        final orchestrator = TestOrchestrator();
        final handle = orchestrator.dispatchJob<int>(SuccessJob(5));

        await handle.future;
        orchestrator.dispose();

        expect(
          observer.log.any((e) => e.contains('success:SuccessJob:10:')),
          isTrue,
        );
      });

      test('onJobError called on failure', () async {
        final orchestrator = TestOrchestrator();
        final handle = orchestrator.dispatchJob<dynamic>(FailJob());

        try {
          await handle.future;
        } catch (_) {
          // Expected
        }

        await Future.delayed(const Duration(milliseconds: 50));
        orchestrator.dispose();

        expect(
          observer.log.any((e) => e.contains('error:FailJob:')),
          isTrue,
        );
      });

      test('lifecycle hooks called in correct order', () async {
        final orchestrator = TestOrchestrator();
        final handle = orchestrator.dispatchJob<int>(SuccessJob(1));

        await handle.future;
        orchestrator.dispose();

        final startIdx =
            observer.log.indexWhere((e) => e.startsWith('start:SuccessJob:'));
        final successIdx =
            observer.log.indexWhere((e) => e.contains('success:SuccessJob:'));

        expect(startIdx, greaterThanOrEqualTo(0));
        expect(successIdx, greaterThanOrEqualTo(0));
        expect(startIdx, lessThan(successIdx));
      });
    });

    group('Event Notifications', () {
      test('onEvent receives domain event on success', () async {
        final orchestrator = TestOrchestrator();
        final handle = orchestrator.dispatchJob<int>(SuccessJob(7));

        await handle.future;
        await Future.delayed(const Duration(milliseconds: 50));
        orchestrator.dispose();

        expect(
          observer.log.any((e) => e.contains('event:SuccessCompletedEvent')),
          isTrue,
          reason: 'Expected SuccessCompletedEvent in log. Got: ${observer.log}',
        );
      });

      test('onEvent receives progress job completion', () async {
        final orchestrator = TestOrchestrator();
        final handle = orchestrator.dispatchJob<String>(ProgressJob());

        await handle.future;
        await Future.delayed(const Duration(milliseconds: 50));
        orchestrator.dispose();

        expect(
          observer.log.any((e) => e.startsWith('start:ProgressJob:')),
          isTrue,
        );
        expect(
          observer.log.any((e) => e.contains('success:ProgressJob:')),
          isTrue,
        );
      });
    });

    group('Null Observer Safety', () {
      test('no error when observer is null', () async {
        OrchestratorObserver.instance = null;

        final orchestrator = TestOrchestrator();
        final handle = orchestrator.dispatchJob<int>(SuccessJob(99));

        final result = await handle.future;
        expect(result.data, equals(198));

        orchestrator.dispose();
      });

      test('observer can be changed mid-flight', () async {
        final firstObserver = TestObserver();
        final secondObserver = TestObserver();

        OrchestratorObserver.instance = firstObserver;

        final orchestrator = TestOrchestrator();
        orchestrator.dispatchJob<int>(SuccessJob(1));

        await Future.delayed(const Duration(milliseconds: 5));

        OrchestratorObserver.instance = secondObserver;

        orchestrator.dispatchJob<int>(SuccessJob(2));

        await Future.delayed(const Duration(milliseconds: 100));
        orchestrator.dispose();

        expect(firstObserver.log.isNotEmpty, isTrue);
        expect(secondObserver.log.isNotEmpty, isTrue);
      });
    });

    group('Multiple Orchestrators', () {
      test('observer receives events from all orchestrators', () async {
        final orchestrator1 = TestOrchestrator();
        final orchestrator2 = TestOrchestrator();

        orchestrator1.dispatchJob<int>(SuccessJob(10));
        orchestrator2.dispatchJob<int>(SuccessJob(20));

        await Future.delayed(const Duration(milliseconds: 100));

        orchestrator1.dispose();
        orchestrator2.dispose();

        final startEvents =
            observer.log.where((e) => e.startsWith('start:SuccessJob:'));
        expect(startEvents.length, equals(2));

        final successEvents =
            observer.log.where((e) => e.contains('success:SuccessJob:'));
        expect(successEvents.length, equals(2));
      });
    });

    group('DataSource Reporting', () {
      test('fresh source reported for non-cached jobs', () async {
        final orchestrator = TestOrchestrator();
        final handle = orchestrator.dispatchJob<int>(SuccessJob(3));

        await handle.future;
        orchestrator.dispose();

        expect(
          observer.log.any((e) => e.contains(':DataSource.fresh')),
          isTrue,
        );
      });
    });
  });
}
