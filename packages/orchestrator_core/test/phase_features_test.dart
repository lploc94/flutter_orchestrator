import 'package:test/test.dart';
import 'package:orchestrator_core/orchestrator_core.dart';

// ============================================================================
// Test Jobs
// ============================================================================

class TestJob extends BaseJob {
  TestJob() : super(id: generateJobId('test'));
}

class AnotherJob extends BaseJob {
  AnotherJob() : super(id: generateJobId('another'));
}

// ============================================================================
// Test Executors
// ============================================================================

class TestExecutor extends BaseExecutor<TestJob> {
  @override
  Future<dynamic> process(TestJob job) async {
    return 'success';
  }
}

class AnotherExecutor extends BaseExecutor<AnotherJob> {
  @override
  Future<dynamic> process(AnotherJob job) async {
    return 42;
  }
}

/// TypedExecutor test - returns User type
class User {
  final String id;
  final String name;
  User(this.id, this.name);
}

class FetchUserJob extends BaseJob {
  final String userId;
  FetchUserJob(this.userId) : super(id: generateJobId('fetch_user'));
}

class FetchUserExecutor extends TypedExecutor<FetchUserJob, User> {
  @override
  Future<User> run(FetchUserJob job) async {
    return User(job.userId, 'Test User');
  }
}

/// SyncTypedExecutor test
class CalculateJob extends BaseJob {
  final int value;
  CalculateJob(this.value) : super(id: generateJobId('calculate'));
}

class CalculateExecutor extends SyncTypedExecutor<CalculateJob, int> {
  @override
  int runSync(CalculateJob job) {
    return job.value * 2;
  }
}

// ============================================================================
// Test State & Orchestrator
// ============================================================================

class TestState {
  final int count;
  final String? data;
  final String? error;
  final Type? lastJobType;

  TestState({
    this.count = 0,
    this.data,
    this.error,
    this.lastJobType,
  });

  TestState copyWith({
    int? count,
    String? data,
    String? error,
    Type? lastJobType,
  }) {
    return TestState(
      count: count ?? this.count,
      data: data ?? this.data,
      error: error ?? this.error,
      lastJobType: lastJobType ?? this.lastJobType,
    );
  }
}

class TestOrchestrator extends BaseOrchestrator<TestState> {
  TestOrchestrator({
    SignalBus? bus,
    Dispatcher? dispatcher,
  }) : super(TestState(), bus: bus, dispatcher: dispatcher);

  void runTestJob() {
    dispatch<String>(TestJob());
  }

  void runAnotherJob() {
    dispatch<int>(AnotherJob());
  }

  @override
  void onEvent(BaseEvent event) {
    if (event is JobSuccessEvent) {
      // Check if this is our job (active) or from another orchestrator (passive)
      final isActive = isJobRunning(event.correlationId);

      if (isActive) {
        // Active success - update data
        emit(state.copyWith(
          data: event.data?.toString(),
          lastJobType: event.jobType != null ? _parseJobType(event.jobType!) : null,
        ));
      } else if (event.isFromJobType<AnotherJob>()) {
        // Passive event from AnotherJob - increment count
        emit(state.copyWith(count: state.count + 1));
      }
    }
  }

  Type? _parseJobType(String typeName) {
    if (typeName == 'TestJob') return TestJob;
    if (typeName == 'AnotherJob') return AnotherJob;
    return null;
  }
}

// ============================================================================
// Mock Dispatcher for testing
// ============================================================================

class MockDispatcher implements Dispatcher {
  final List<BaseJob> dispatchedJobs = [];
  final Dispatcher _realDispatcher = Dispatcher();

  @override
  int get maxRetries => _realDispatcher.maxRetries;

  @override
  Map<String, String> get registeredExecutors =>
      _realDispatcher.registeredExecutors;

  @override
  void register<T extends BaseJob>(BaseExecutor<T> executor) {
    _realDispatcher.register<T>(executor);
  }

  @override
  void registerByType(Type jobType, BaseExecutor executor) {
    _realDispatcher.registerByType(jobType, executor);
  }

  @override
  String dispatch(BaseJob job, {JobHandle? handle}) {
    dispatchedJobs.add(job);
    return _realDispatcher.dispatch(job, handle: handle);
  }

  @override
  void resetForTesting() {
    _realDispatcher.resetForTesting();
    dispatchedJobs.clear();
  }

  @override
  void clear() {
    _realDispatcher.clear();
    dispatchedJobs.clear();
  }

  @override
  void dispose() {
    _realDispatcher.dispose();
  }
}

void main() {
  group('Phase 1: Testing Infrastructure', () {
    late SignalBus bus;
    late Dispatcher dispatcher;

    setUp(() {
      bus = SignalBus.scoped();
      dispatcher = Dispatcher();
      dispatcher.register<TestJob>(TestExecutor());
      dispatcher.register<AnotherJob>(AnotherExecutor());
    });

    tearDown(() {
      dispatcher.resetForTesting();
      bus.dispose();
    });

    group('Dispatcher Injection', () {
      test('BaseOrchestrator accepts custom dispatcher', () {
        final mockDispatcher = MockDispatcher();
        mockDispatcher.register<TestJob>(TestExecutor());

        final orchestrator = TestOrchestrator(
          bus: bus,
          dispatcher: mockDispatcher,
        );

        orchestrator.runTestJob();

        expect(mockDispatcher.dispatchedJobs, hasLength(1));
        expect(mockDispatcher.dispatchedJobs.first, isA<TestJob>());

        orchestrator.dispose();
      });

      test('BaseOrchestrator uses default dispatcher when not provided', () {
        // Should not throw
        final orchestrator = TestOrchestrator(bus: bus);
        expect(orchestrator, isNotNull);
        orchestrator.dispose();
      });
    });

    group('SignalBus.listen()', () {
      test('listen() is shorthand for stream.listen()', () async {
        final events = <BaseEvent>[];

        final subscription = bus.listen((event) {
          events.add(event);
        });

        bus.emit(JobStartedEvent('test-id', jobType: 'TestJob'));
        await Future.delayed(Duration(milliseconds: 10));

        expect(events, hasLength(1));
        expect(events.first, isA<JobStartedEvent>());

        await subscription.cancel();
      });

      test('listen() supports onError and onDone callbacks', () async {
        var doneCallbackCalled = false;

        final subscription = bus.listen(
          (event) {},
          onDone: () => doneCallbackCalled = true,
        );

        bus.dispose();
        await Future.delayed(Duration(milliseconds: 10));

        expect(doneCallbackCalled, isTrue);
        await subscription.cancel();
      });
    });
  });

  group('Phase 2: Type Safety', () {
    late SignalBus bus;
    late Dispatcher dispatcher;

    setUp(() {
      bus = SignalBus.scoped();
      dispatcher = Dispatcher();
      dispatcher.register<TestJob>(TestExecutor());
      dispatcher.register<AnotherJob>(AnotherExecutor());
      dispatcher.register<FetchUserJob>(FetchUserExecutor());
      dispatcher.register<CalculateJob>(CalculateExecutor());
    });

    tearDown(() {
      dispatcher.resetForTesting();
      bus.dispose();
    });

    group('jobType in Events', () {
      test('JobSuccessEvent includes jobType from executor', () async {
        // Use global bus because executors emit to global bus by default
        final globalBus = SignalBus.instance;
        final events = <BaseEvent>[];
        final subscription = globalBus.listen((e) => events.add(e));

        final job = TestJob();
        dispatcher.dispatch(job);

        await Future.delayed(Duration(milliseconds: 50));

        final successEvent = events.whereType<JobSuccessEvent>().firstOrNull;
        expect(successEvent, isNotNull);
        expect(successEvent!.jobType, equals('TestJob'));

        await subscription.cancel();
      });

      test('JobFailureEvent includes jobType', () async {
        final failingExecutor = _FailingExecutor();
        dispatcher.register<_FailingJob>(failingExecutor);

        final globalBus = SignalBus.instance;
        final events = <BaseEvent>[];
        final subscription = globalBus.listen((e) => events.add(e));

        dispatcher.dispatch(_FailingJob());

        await Future.delayed(Duration(milliseconds: 50));

        final failureEvent = events.whereType<JobFailureEvent>().firstOrNull;
        expect(failureEvent, isNotNull);
        expect(failureEvent!.jobType, equals('_FailingJob'));

        await subscription.cancel();
      });

      test('isFromJobType<T>() returns true for matching job type', () {
        final event = JobSuccessEvent(
          'test-id',
          'data',
          jobType: 'TestJob',
        );

        expect(event.isFromJobType<TestJob>(), isTrue);
        expect(event.isFromJobType<AnotherJob>(), isFalse);
      });

      test('isFromJobType<T>() returns false when jobType is null', () {
        final event = JobSuccessEvent('test-id', 'data');

        expect(event.isFromJobType<TestJob>(), isFalse);
      });

      test('JobFailureEvent.isFromJobType works correctly', () {
        final event = JobFailureEvent(
          'test-id',
          Exception('error'),
          jobType: 'AnotherJob',
        );

        expect(event.isFromJobType<AnotherJob>(), isTrue);
        expect(event.isFromJobType<TestJob>(), isFalse);
      });

      test('JobCancelledEvent.isFromJobType works correctly', () {
        final event = JobCancelledEvent('test-id', jobType: 'TestJob');

        expect(event.isFromJobType<TestJob>(), isTrue);
      });

      test('JobTimeoutEvent.isFromJobType works correctly', () {
        final event = JobTimeoutEvent(
          'test-id',
          Duration(seconds: 5),
          jobType: 'TestJob',
        );

        expect(event.isFromJobType<TestJob>(), isTrue);
      });
    });

    group('TypedExecutor', () {
      test('TypedExecutor returns correctly typed result', () async {
        final globalBus = SignalBus.instance;
        final events = <BaseEvent>[];
        final subscription = globalBus.listen((e) => events.add(e));

        dispatcher.dispatch(FetchUserJob('user-123'));

        await Future.delayed(Duration(milliseconds: 50));

        final successEvent = events.whereType<JobSuccessEvent>().firstOrNull;
        expect(successEvent, isNotNull);
        expect(successEvent!.data, isA<User>());

        final user = successEvent.data as User;
        expect(user.id, equals('user-123'));
        expect(user.name, equals('Test User'));

        await subscription.cancel();
      });

      test('SyncTypedExecutor returns correctly typed result', () async {
        final globalBus = SignalBus.instance;
        final events = <BaseEvent>[];
        final subscription = globalBus.listen((e) => events.add(e));

        dispatcher.dispatch(CalculateJob(21));

        await Future.delayed(Duration(milliseconds: 50));

        final successEvent = events.whereType<JobSuccessEvent>().firstOrNull;
        expect(successEvent, isNotNull);
        expect(successEvent!.data, equals(42));

        await subscription.cancel();
      });
    });

    group('Cross-feature Event Filtering', () {
      test('Orchestrator can filter passive events by jobType', () async {
        final orchestrator1 =
            TestOrchestrator(bus: bus, dispatcher: dispatcher);
        final orchestrator2 =
            TestOrchestrator(bus: bus, dispatcher: dispatcher);

        // Orchestrator1 dispatches AnotherJob
        orchestrator1.runAnotherJob();

        await Future.delayed(Duration(milliseconds: 50));

        // Orchestrator2 should have received passive event and incremented count
        expect(orchestrator2.state.count, equals(1));

        orchestrator1.dispose();
        orchestrator2.dispose();
      });
    });
  });

  group('Phase 4: Code Generation Annotations', () {
    test('@TypedJob annotation exists and has correct properties', () {
      const annotation = TypedJob(
        idPrefix: 'user',
        timeout: Duration(seconds: 30),
        maxRetries: 3,
        retryDelay: Duration(seconds: 1),
      );

      expect(annotation.idPrefix, equals('user'));
      expect(annotation.timeout, equals(Duration(seconds: 30)));
      expect(annotation.maxRetries, equals(3));
      expect(annotation.retryDelay, equals(Duration(seconds: 1)));
      expect(annotation.interfaceSuffix, equals('Interface'));
    });

    test('@TypedJob has sensible defaults', () {
      const annotation = TypedJob();

      expect(annotation.idPrefix, isNull);
      expect(annotation.timeout, isNull);
      expect(annotation.maxRetries, isNull);
      expect(annotation.retryDelay, isNull);
      expect(annotation.interfaceSuffix, equals('Interface'));
    });

    test('@OrchestratorProvider annotation exists and has correct properties',
        () {
      const annotation = OrchestratorProvider(
        name: 'myProvider',
        withRef: true,
      );

      expect(annotation.name, equals('myProvider'));
      expect(annotation.withRef, isTrue);
    });

    test('@OrchestratorProvider has sensible defaults', () {
      const annotation = OrchestratorProvider();

      expect(annotation.name, isNull);
      expect(annotation.withRef, isFalse);
    });
  });
}

// ============================================================================
// Helper classes for tests
// ============================================================================

class _FailingJob extends BaseJob {
  _FailingJob() : super(id: generateJobId('failing'));
}

class _FailingExecutor extends BaseExecutor<_FailingJob> {
  @override
  Future<dynamic> process(_FailingJob job) async {
    throw Exception('Intentional failure');
  }
}
