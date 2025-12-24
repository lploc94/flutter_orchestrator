import 'package:flutter_test/flutter_test.dart';
import 'package:orchestrator_provider/orchestrator_provider.dart';

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

class TestNotifier extends OrchestratorNotifier<CounterState> {
  TestNotifier() : super(const CounterState());

  void calculate(int value) {
    state = state.copyWith(isLoading: true);
    dispatch(TestJob(value));
  }

  @override
  void onActiveSuccess(JobSuccessEvent event) {
    state = state.copyWith(count: event.data as int, isLoading: false);
  }

  @override
  void onActiveFailure(JobFailureEvent event) {
    state = state.copyWith(isLoading: false, error: event.error.toString());
  }
}

// --- Test Suite ---

void main() {
  final dispatcher = Dispatcher();

  setUp(() {
    dispatcher.clear();
    dispatcher.register(TestExecutor());
  });

  group('OrchestratorNotifier', () {
    test('initial state is correct', () {
      final notifier = TestNotifier();
      expect(notifier.state.count, equals(0));
      expect(notifier.state.isLoading, isFalse);
      notifier.dispose();
    });

    test('dispatch job sets loading state', () async {
      final notifier = TestNotifier();

      notifier.calculate(5);

      expect(notifier.state.isLoading, isTrue);

      await Future.delayed(const Duration(milliseconds: 100));
      notifier.dispose();
    });

    test('success event updates state correctly', () async {
      final notifier = TestNotifier();

      notifier.calculate(5);

      await Future.delayed(const Duration(milliseconds: 100));

      expect(notifier.state.count, equals(10)); // 5 * 2
      expect(notifier.state.isLoading, isFalse);

      notifier.dispose();
    });

    test('notifyListeners is called on state change', () async {
      final notifier = TestNotifier();
      int notifyCount = 0;

      notifier.addListener(() => notifyCount++);

      notifier.calculate(7);

      await Future.delayed(const Duration(milliseconds: 100));

      // Should be called at least twice (loading -> success)
      expect(notifyCount, greaterThanOrEqualTo(2));

      notifier.dispose();
    });
  });
}
