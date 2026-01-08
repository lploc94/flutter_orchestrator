// Copyright (c) 2024, Flutter Orchestrator
// SPDX-License-Identifier: MIT

/// Example demonstrating Riverpod integration with Orchestrator pattern.
///
/// This example shows the v0.6.0 unified `onEvent` pattern.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orchestrator_riverpod/orchestrator_riverpod.dart';

// ============ 1. Define Domain Event ============

/// Event emitted when calculation completes
class CalculationResultEvent extends BaseEvent {
  final int result;
  CalculationResultEvent(super.correlationId, this.result);
}

// ============ 2. Define Job (using EventJob) ============

class CalculateJob
    extends EventJob<int, CalculationResultEvent> {
  final int value;

  CalculateJob(this.value) : super(id: generateJobId('calc'));

  @override
  CalculationResultEvent createEventTyped(int result) {
    return CalculationResultEvent(id, result);
  }
}

// ============ 3. Create Executor ============

class CalculateExecutor extends BaseExecutor<CalculateJob> {
  @override
  Future<int> process(CalculateJob job) async {
    await Future.delayed(Duration(milliseconds: 500));
    return job.value * 2;
  }
}

// ============ 4. Define State ============

class CalcState {
  final int result;
  final bool isLoading;
  final String? error;

  const CalcState({this.result = 0, this.isLoading = false, this.error});

  CalcState copyWith({int? result, bool? isLoading, String? error}) => CalcState(
        result: result ?? this.result,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

// ============ 5. Create Notifier (Orchestrator) ============

/// CalcNotifier using the unified `onEvent` pattern.
///
/// Instead of multiple hooks like `onActiveSuccess`, `onActiveFailure`,
/// we now use a single `onEvent` with Dart 3 pattern matching.
class CalcNotifier extends OrchestratorNotifier<CalcState> {
  @override
  CalcState buildState() => const CalcState();

  void calculate(int value) {
    state = state.copyWith(isLoading: true, error: null);
    dispatch(CalculateJob(value));
  }

  @override
  void onEvent(BaseEvent event) {
    switch (event) {
      // Handle our domain event
      case CalculationResultEvent e when isJobRunning(e.correlationId):
        state = state.copyWith(result: e.result, isLoading: false);

      // Handle failure from our jobs
      case JobFailureEvent e when isJobRunning(e.correlationId):
        state = state.copyWith(
          isLoading: false,
          error: e.error.toString(),
        );

      // Handle other domain events (from other orchestrators)
      // case SomeOtherEvent e:
      //   state = state.copyWith(...);

      default:
        // Ignore events we don't care about
        break;
    }
  }
}

// ============ 6. Define Provider ============

final calcProvider = NotifierProvider<CalcNotifier, CalcState>(
  CalcNotifier.new,
);

// ============ 7. Use in Widget ============

void main() {
  Dispatcher().register<CalculateJob>(CalculateExecutor());

  runApp(
    const ProviderScope(child: MyApp()),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calcProvider);

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Orchestrator Riverpod Example')),
        body: Center(
          child: state.isLoading
              ? const CircularProgressIndicator()
              : state.error != null
                  ? Text(
                      'Error: ${state.error}',
                      style: TextStyle(color: Colors.red),
                    )
                  : Text(
                      'Result: ${state.result}',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => ref.read(calcProvider.notifier).calculate(21),
          child: const Icon(Icons.calculate),
        ),
      ),
    );
  }
}
