import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:orchestrator_bloc/orchestrator_bloc.dart';

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

class TestCubit extends OrchestratorCubit<CounterState> {
  TestCubit() : super(const CounterState());

  void calculate(int value) {
    emit(state.copyWith(isLoading: true));
    dispatch(TestJob(value));
  }

  @override
  void onActiveSuccess(JobSuccessEvent event) {
    emit(state.copyWith(count: event.data as int, isLoading: false));
  }

  @override
  void onActiveFailure(JobFailureEvent event) {
    emit(state.copyWith(isLoading: false, error: event.error.toString()));
  }
}

// --- Test Suite ---

void main() {
  final dispatcher = Dispatcher();

  setUp(() {
    dispatcher.clear();
    dispatcher.register(TestExecutor());
  });

  group('OrchestratorCubit', () {
    test('initial state is correct', () {
      final cubit = TestCubit();
      expect(cubit.state.count, equals(0));
      expect(cubit.state.isLoading, isFalse);
      cubit.close();
    });

    test('dispatch job sets loading state', () async {
      final cubit = TestCubit();

      cubit.calculate(5);

      expect(cubit.state.isLoading, isTrue);

      await Future.delayed(const Duration(milliseconds: 100));
      cubit.close();
    });

    test('success event updates state correctly', () async {
      final cubit = TestCubit();

      cubit.calculate(5);

      await Future.delayed(const Duration(milliseconds: 100));

      expect(cubit.state.count, equals(10)); // 5 * 2
      expect(cubit.state.isLoading, isFalse);

      cubit.close();
    });

    blocTest<TestCubit, CounterState>(
      'emits loading then success states',
      build: () => TestCubit(),
      act: (cubit) => cubit.calculate(7),
      wait: const Duration(milliseconds: 100),
      expect: () => [
        isA<CounterState>().having((s) => s.isLoading, 'isLoading', true),
        isA<CounterState>()
            .having((s) => s.count, 'count', 14)
            .having((s) => s.isLoading, 'isLoading', false),
      ],
    );
  });
}
