import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orchestrator_riverpod/orchestrator_riverpod.dart';

import '{{name.snakeCase()}}_state.dart';

/// {{name.pascalCase()}}Notifier - Orchestrator for {{name.pascalCase()}} feature (Riverpod)
class {{name.pascalCase()}}Notifier extends OrchestratorNotifier<{{name.pascalCase()}}State> {
  @override
  {{name.pascalCase()}}State buildState() => const {{name.pascalCase()}}State();

  // TODO: Add methods to trigger jobs
  // Example:
  // void load{{name.pascalCase()}}(String id) {
  //   state = state.copyWith(isLoading: true, error: null);
  //   dispatch(Fetch{{name.pascalCase()}}Job(id: id));
  // }

  @override
  void onActiveSuccess(JobSuccessEvent event) {
    // TODO: Handle success events
    // final data = event.dataAs<{{name.pascalCase()}}>();
    // state = state.copyWith(data: data, isLoading: false);
  }

  @override
  void onActiveFailure(JobFailureEvent event) {
    state = state.copyWith(isLoading: false, error: event.error.toString());
  }
}

/// Provider for {{name.pascalCase()}}Notifier
final {{name.camelCase()}}Provider = NotifierProvider<{{name.pascalCase()}}Notifier, {{name.pascalCase()}}State>(
  {{name.pascalCase()}}Notifier.new,
);
