import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orchestrator_core/orchestrator_core.dart';
import 'package:orchestrator_test/orchestrator_test.dart';
import 'package:simple_counter/cubit/counter_cubit.dart';
import 'package:simple_counter/cubit/counter_state.dart';
import 'package:simple_counter/jobs/counter_jobs.dart';

void main() {
  group('CounterCubit (Integration with orchestrator_test)', () {
    late Dispatcher dispatcher;

    setUp(() {
      // 1. Reset Dispatcher to ensure clean state
      dispatcher = Dispatcher();
      dispatcher.resetForTesting();
    });

    // We use blocTest because CounterCubit extends Cubit, not BaseOrchestrator.
    // orchestrator_test provides the mocks/fakes interacting with the Dispatcher.
    blocTest<CounterCubit, CounterState>(
      'emits [loading, success] when increment is called',
      setUp: () {
        // 2. Register a FakeExecutor for IncrementJob
        dispatcher.register<IncrementJob>(
          FakeExecutor<IncrementJob>((job) async {
            await Future.delayed(const Duration(milliseconds: 10));
            return 10;
          }),
        );
      },
      build: () => CounterCubit(),
      act: (cubit) => cubit.increment(),
      wait: const Duration(milliseconds: 20), // Wait for executor
      expect: () => [
        // Match loading=true
        isA<CounterState>().having((s) => s.isLoading, 'isLoading', true),
        // Match success with count=10
        isA<CounterState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.count, 'count', 10),
      ],
    );

    blocTest<CounterCubit, CounterState>(
      'emits [loading, failure] when processing fails',
      setUp: () {
        dispatcher.register<DecrementJob>(
          FakeExecutor<DecrementJob>((job) async {
            throw Exception('Network Error');
          }),
        );
      },
      build: () => CounterCubit(),
      act: (cubit) => cubit.decrement(),
      wait: const Duration(milliseconds: 20),
      expect: () => [
        isA<CounterState>().having((s) => s.isLoading, 'isLoading', true),
        isA<CounterState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.error, 'error', contains('Network Error')),
      ],
    );

    test('captures dispatched jobs in executor', () async {
      final executor = FakeExecutor<ResetJob>((job) async => 0);
      dispatcher.register<ResetJob>(executor);

      final cubit = CounterCubit();
      cubit.reset();

      // Wait for dispatch
      await Future.delayed(Duration(milliseconds: 50));

      expect(executor.processedJobs, hasLength(1));
      expect(executor.processedJobs.first, isA<ResetJob>());

      cubit.close();
    });
  });
}
