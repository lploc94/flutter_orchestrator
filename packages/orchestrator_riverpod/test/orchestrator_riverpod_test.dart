import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orchestrator_riverpod/orchestrator_riverpod.dart';

// --- Mock Classes ---

class TestJob extends BaseJob {
  final int value;
  TestJob(this.value)
      : super(id: 'job-${DateTime.now().millisecondsSinceEpoch}');
}

class TestExecutor extends BaseExecutor<TestJob> {
  @override
  Future<dynamic> process(TestJob job) async {
    await Future.delayed(const Duration(milliseconds: 10));
    return job.value * 2;
  }
}

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

/// Test notifier using the new unified onEvent pattern
class TestNotifier extends OrchestratorNotifier<CounterState> {
  @override
  CounterState buildState() => const CounterState();

  void calculate(int value) {
    state = state.copyWith(isLoading: true);
    dispatch(TestJob(value));
  }

  @override
  void onEvent(BaseEvent event) {
    switch (event) {
      case JobSuccessEvent e when isJobRunning(e.correlationId):
        state = state.copyWith(count: e.data as int, isLoading: false);
      case JobFailureEvent e when isJobRunning(e.correlationId):
        state = state.copyWith(isLoading: false, error: e.error.toString());
      default:
        // Ignore other events
        break;
    }
  }
}

final testProvider = NotifierProvider<TestNotifier, CounterState>(
  TestNotifier.new,
);

// --- Test Suite ---

void main() {
  final dispatcher = Dispatcher();

  setUp(() {
    dispatcher.clear();
    dispatcher.register(TestExecutor());
  });

  group('OrchestratorNotifier (Riverpod)', () {
    test('initial state is correct', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(testProvider);
      expect(state.count, equals(0));
      expect(state.isLoading, isFalse);
    });

    test('dispatch job sets loading state', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(testProvider.notifier).calculate(5);

      expect(container.read(testProvider).isLoading, isTrue);

      await Future.delayed(const Duration(milliseconds: 100));
    });

    test('success event updates state correctly', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(testProvider.notifier).calculate(5);

      await Future.delayed(const Duration(milliseconds: 100));

      final state = container.read(testProvider);
      expect(state.count, equals(10)); // 5 * 2
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
}
