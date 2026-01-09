import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orchestrator_riverpod/orchestrator_riverpod.dart';

// --- Domain Events ---

class CalculationResultEvent extends BaseEvent {
  final int result;
  CalculationResultEvent(super.correlationId, this.result);
}

// --- Jobs ---

/// EventJob that emits CalculationResultEvent on success
class CalculateJob extends EventJob<int, CalculationResultEvent> {
  final int value;
  CalculateJob(this.value)
      : super(id: 'calc-${DateTime.now().millisecondsSinceEpoch}');

  @override
  CalculationResultEvent createEventTyped(int result) {
    return CalculationResultEvent(id, result);
  }
}

// --- Executor ---

class CalculateExecutor extends BaseExecutor<CalculateJob> {
  @override
  Future<dynamic> process(CalculateJob job) async {
    await Future.delayed(const Duration(milliseconds: 10));
    return job.value * 2;
  }
}

// --- State ---

class CounterState {
  final int count;
  final bool isLoading;
  final String? error;

  const CounterState({this.count = 0, this.isLoading = false, this.error});

  CounterState copyWith({int? count, bool? isLoading, String? error}) {
    return CounterState(
      count: count ?? this.count,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// --- Notifiers ---

/// Test notifier using EventJob and JobHandle
class TestNotifier extends OrchestratorNotifier<CounterState> {
  @override
  CounterState buildState() => const CounterState();

  /// Fire-and-forget pattern
  void calculate(int value) {
    state = state.copyWith(isLoading: true);
    dispatch<int>(CalculateJob(value));
  }

  /// Await result pattern
  Future<int?> calculateAndWait(int value) async {
    state = state.copyWith(isLoading: true);
    final handle = dispatch<int>(CalculateJob(value));
    try {
      final result = await handle.future;
      state = state.copyWith(count: result.data, isLoading: false);
      return result.data;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  @override
  void onEvent(BaseEvent event) {
    switch (event) {
      case CalculationResultEvent e when isJobRunning(e.correlationId):
        state = state.copyWith(count: e.result, isLoading: false);
      default:
        break;
    }
  }
}

final testProvider = NotifierProvider<TestNotifier, CounterState>(
  TestNotifier.new,
);

/// Test AsyncNotifier
class AsyncCounterState {
  final int count;
  AsyncCounterState({this.count = 0});
}

class TestAsyncNotifier extends OrchestratorAsyncNotifier<AsyncCounterState> {
  @override
  Future<AsyncCounterState> buildState() async {
    // Simulate async initialization
    await Future.delayed(const Duration(milliseconds: 10));
    return AsyncCounterState(count: 0);
  }

  Future<void> calculate(int value) async {
    state = const AsyncValue.loading();
    final handle = dispatch<int>(CalculateJob(value));
    try {
      final result = await handle.future;
      state = AsyncValue.data(AsyncCounterState(count: result.data));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final testAsyncProvider =
    AsyncNotifierProvider<TestAsyncNotifier, AsyncCounterState>(
  TestAsyncNotifier.new,
);

// --- Test Suite ---

void main() {
  final dispatcher = Dispatcher();

  setUp(() {
    dispatcher.clear();
    dispatcher.register(CalculateExecutor());
  });

  group('OrchestratorNotifier', () {
    test('initial state is correct', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(testProvider);
      expect(state.count, equals(0));
      expect(state.isLoading, isFalse);
    });

    test('dispatch returns JobHandle', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(testProvider.notifier);
      final handle = notifier.dispatch<int>(CalculateJob(5));

      expect(handle, isA<JobHandle<int>>());
      expect(handle.jobId, isNotEmpty);
    });

    test('dispatch job sets loading state', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(testProvider.notifier).calculate(5);

      expect(container.read(testProvider).isLoading, isTrue);

      await Future.delayed(const Duration(milliseconds: 100));
    });

    test('fire-and-forget: onEvent updates state via domain event', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(testProvider.notifier).calculate(5);

      await Future.delayed(const Duration(milliseconds: 100));

      final state = container.read(testProvider);
      expect(state.count, equals(10)); // 5 * 2
      expect(state.isLoading, isFalse);
    });

    test('await pattern: handle.future returns result', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final result =
          await container.read(testProvider.notifier).calculateAndWait(7);

      expect(result, equals(14)); // 7 * 2

      final state = container.read(testProvider);
      expect(state.count, equals(14));
      expect(state.isLoading, isFalse);
    });

    test('listener is notified on state change', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      int changeCount = 0;
      container.listen(testProvider, (_, __) => changeCount++);

      container.read(testProvider.notifier).calculate(7);

      await Future.delayed(const Duration(milliseconds: 100));

      // Should be notified at least twice (loading -> success)
      expect(changeCount, greaterThanOrEqualTo(2));
    });

    test('isJobRunning correctly identifies active jobs', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(testProvider.notifier);

      // No jobs initially
      expect(notifier.hasActiveJobs, isFalse);

      notifier.calculate(10);

      // Should have active job now
      expect(notifier.hasActiveJobs, isTrue);

      await Future.delayed(const Duration(milliseconds: 100));

      // Job should be cleaned up after completion
      expect(notifier.hasActiveJobs, isFalse);
    });
  });

  group('OrchestratorAsyncNotifier', () {
    test('initial state is AsyncLoading then AsyncData', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Initial state should be loading
      final initialState = container.read(testAsyncProvider);
      expect(initialState, isA<AsyncLoading>());

      // Wait for build to complete
      await Future.delayed(const Duration(milliseconds: 50));

      final loadedState = container.read(testAsyncProvider);
      expect(loadedState, isA<AsyncData<AsyncCounterState>>());
      expect(loadedState.value?.count, equals(0));
    });

    test('calculate updates state with AsyncValue', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Wait for initial build
      await Future.delayed(const Duration(milliseconds: 50));

      // Trigger calculation
      await container.read(testAsyncProvider.notifier).calculate(5);

      final state = container.read(testAsyncProvider);
      expect(state, isA<AsyncData<AsyncCounterState>>());
      expect(state.value?.count, equals(10)); // 5 * 2
    });
  });
}
