import 'package:orchestrator_bloc/orchestrator_bloc.dart';

import '{{name.snakeCase()}}_state.dart';

/// {{name.pascalCase()}}Cubit - Orchestrator for {{name.pascalCase()}} feature
///
/// Responsibilities:
/// - Manage UI state ({{name.pascalCase()}}State)
/// - Dispatch Jobs to Executors
/// - Handle Events (Success, Failure, Progress)
class {{name.pascalCase()}}Cubit extends OrchestratorCubit<{{name.pascalCase()}}State> {
  {{name.pascalCase()}}Cubit() : super(const {{name.pascalCase()}}State());

  // TODO: Add methods to trigger jobs
  // Example:
  // void load{{name.pascalCase()}}(String id) {
  //   emit(state.copyWith(isLoading: true, error: null));
  //   dispatch(Fetch{{name.pascalCase()}}Job(id: id));
  // }

  @override
  void onActiveSuccess(JobSuccessEvent event) {
    // TODO: Handle success events based on job type
    // Example:
    // final data = event.dataAs<{{name.pascalCase()}}>();
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
