// @template-name: Counter
// Golden example file for CLI template generation
// Run: dart run scripts/sync_templates.dart

import 'package:orchestrator_provider/orchestrator_provider.dart';

import 'counter_state.dart';

/// CounterNotifier - Orchestrator for Counter feature (Provider)
///
/// Use with ChangeNotifierProvider:
/// ```dart
/// ChangeNotifierProvider(
///   create: (_) => CounterNotifier(),
///   child: YourWidget(),
/// )
/// ```
class CounterNotifier extends OrchestratorNotifier<CounterState> {
  CounterNotifier() : super(const CounterState());

  // TODO: Add methods to trigger jobs
  // Example:
  // void loadCounter(String id) {
  //   state = state.copyWith(isLoading: true, error: null);
  //   dispatch(FetchCounterJob(id: id));
  // }

  @override
  void onActiveSuccess(JobSuccessEvent event) {
    // TODO: Handle success events
    // final data = event.dataAs<Counter>();
    // state = state.copyWith(data: data, isLoading: false);
  }

  @override
  void onActiveFailure(JobFailureEvent event) {
    state = state.copyWith(isLoading: false, error: event.error.toString());
  }
}
