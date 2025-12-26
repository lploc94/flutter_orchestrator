// lib/cubit/counter_cubit.dart
// Orchestrator (Cubit) - bridges UI and business logic

import 'package:orchestrator_bloc/orchestrator_bloc.dart';
import '../jobs/counter_jobs.dart';
import 'counter_state.dart';

/// CounterCubit - Orchestrator for Counter feature
///
/// Responsibilities:
/// - Manage UI state (CounterState)
/// - Dispatch Jobs to Executors
/// - Handle Events (Success, Failure, Progress)
class CounterCubit extends OrchestratorCubit<CounterState> {
  CounterCubit() : super(const CounterState());

  /// Increment the counter
  void increment() {
    emit(state.copyWith(isLoading: true, error: null));
    dispatch(IncrementJob());
  }

  /// Decrement the counter
  void decrement() {
    emit(state.copyWith(isLoading: true, error: null));
    dispatch(DecrementJob());
  }

  /// Reset the counter to zero
  void reset() {
    emit(state.copyWith(isLoading: true, error: null));
    dispatch(ResetJob());
  }

  // ========== Event Hooks ==========

  @override
  void onActiveSuccess(JobSuccessEvent event) {
    // All counter jobs return int
    final newCount = event.dataAs<int>();
    emit(state.copyWith(count: newCount, isLoading: false));
  }

  @override
  void onActiveFailure(JobFailureEvent event) {
    emit(state.copyWith(isLoading: false, error: 'Error: ${event.error}'));
  }
}
