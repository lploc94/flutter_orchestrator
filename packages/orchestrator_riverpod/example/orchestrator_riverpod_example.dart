// Copyright (c) 2024, Flutter Orchestrator
// SPDX-License-Identifier: MIT

/// Example demonstrating Riverpod integration with Orchestrator pattern.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orchestrator_riverpod/orchestrator_riverpod.dart';

// ============ 1. Define Job ============

class CalculateJob extends BaseJob {
  final int value;
  CalculateJob(this.value) : super(id: generateJobId('calc'));
}

// ============ 2. Create Executor ============

class CalculateExecutor extends BaseExecutor<CalculateJob> {
  @override
  Future<int> process(CalculateJob job) async {
    await Future.delayed(Duration(milliseconds: 500));
    return job.value * 2;
  }
}

// ============ 3. Define State ============

class CalcState {
  final int result;
  final bool isLoading;

  const CalcState({this.result = 0, this.isLoading = false});

  CalcState copyWith({int? result, bool? isLoading}) => CalcState(
        result: result ?? this.result,
        isLoading: isLoading ?? this.isLoading,
      );
}

// ============ 4. Create Notifier (Orchestrator) ============

class CalcNotifier extends OrchestratorNotifier<CalcState> {
  @override
  CalcState buildState() => const CalcState();

  void calculate(int value) {
    state = state.copyWith(isLoading: true);
    dispatch(CalculateJob(value));
  }

  @override
  void onActiveSuccess(JobSuccessEvent event) {
    state = state.copyWith(
      result: event.dataAs<int>() ?? 0,
      isLoading: false,
    );
  }
}

// ============ 5. Define Provider ============

final calcProvider = NotifierProvider<CalcNotifier, CalcState>(
  CalcNotifier.new,
);

// ============ 6. Use in Widget ============

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
