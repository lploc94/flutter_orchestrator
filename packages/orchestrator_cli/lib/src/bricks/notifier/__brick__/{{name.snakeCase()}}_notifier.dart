import 'package:orchestrator_provider/orchestrator_provider.dart';

import '{{name.snakeCase()}}_state.dart';

/// {{name.pascalCase()}}Notifier - Orchestrator for {{name.pascalCase()}} feature (Provider)
///
/// Use with ChangeNotifierProvider:
/// ```dart
/// ChangeNotifierProvider(
///   create: (_) => {{name.pascalCase()}}Notifier(),
///   child: YourWidget(),
/// )
/// ```
class {{name.pascalCase()}}Notifier extends OrchestratorNotifier<{{name.pascalCase()}}State> {
  {{name.pascalCase()}}Notifier() : super(const {{name.pascalCase()}}State());

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
