// Copyright (c) 2024, Flutter Orchestrator
// SPDX-License-Identifier: MIT

/// Example demonstrating Riverpod integration with Orchestrator pattern.
///
/// This example shows the v0.6.0 design with:
/// - `dispatch<T>()` returns `JobHandle<T>`
/// - `onEvent()` for domain events
/// - Error handling via `handle.future`
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

class CalculateJob extends EventJob<int, CalculationResultEvent> {
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
    await Future.delayed(const Duration(milliseconds: 500));
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

/// CalcNotifier demonstrating both fire-and-forget and await patterns.
class CalcNotifier extends OrchestratorNotifier<CalcState> {
  @override
  CalcState buildState() => const CalcState();

  /// Fire-and-forget: dispatch and handle result in onEvent
  void calculate(int value) {
    state = state.copyWith(isLoading: true, error: null);
    dispatch<int>(CalculateJob(value));
  }

  /// Await pattern: dispatch and await result directly
  Future<void> calculateWithAwait(int value) async {
    state = state.copyWith(isLoading: true, error: null);
    final handle = dispatch<int>(CalculateJob(value));

    try {
      final result = await handle.future;
      state = state.copyWith(result: result.data, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  @override
  void onEvent(BaseEvent event) {
    switch (event) {
      // Handle domain event from EventJob
      case CalculationResultEvent e when isJobRunning(e.correlationId):
        state = state.copyWith(result: e.result, isLoading: false);
      default:
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
                      style: const TextStyle(color: Colors.red),
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
