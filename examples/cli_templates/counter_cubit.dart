// @template-name: Counter
// Golden example file for CLI template generation
// Run: dart run scripts/sync_templates.dart

import 'package:orchestrator_bloc/orchestrator_bloc.dart';

import 'counter_state.dart';

/// CounterCubit - Orchestrator for Counter feature
///
/// Responsibilities:
/// - Manage UI state (CounterState)
/// - Dispatch Jobs to Executors
/// - Handle Events (Success, Failure, Progress)
class CounterCubit extends OrchestratorCubit<CounterState> {
  CounterCubit() : super(const CounterState());

  // TODO: Add methods to trigger jobs
  // Example:
  // void loadCounter(String id) {
  //   emit(state.copyWith(isLoading: true, error: null));
  //   dispatch(FetchCounterJob(id: id));
  // }

  @override
  void onActiveSuccess(JobSuccessEvent event) {
    // TODO: Handle success events based on job type
    // Example:
    // final data = event.dataAs<Counter>();
    // emit(state.copyWith(data: data, isLoading: false));
  }

  @override
  void onActiveFailure(JobFailureEvent event) {
    emit(state.copyWith(isLoading: false, error: event.error.toString()));
  }

  @override
  void onProgress(JobProgressEvent event) {
    // TODO: Handle progress updates if needed
    // emit(state.copyWith(progress: event.progress));
  }
}
