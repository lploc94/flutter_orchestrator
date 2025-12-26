// Copyright (c) 2024, Flutter Orchestrator
// https://github.com/lploc94/flutter_orchestrator
//
// SPDX-License-Identifier: MIT

/// Example demonstrating BLoC integration with Orchestrator pattern.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:orchestrator_bloc/orchestrator_bloc.dart';

// ============ 1. Define Job ============

class FetchCounterJob extends BaseJob {
  FetchCounterJob() : super(id: generateJobId('counter'));
}

// ============ 2. Create Executor ============

class CounterExecutor extends BaseExecutor<FetchCounterJob> {
  @override
  Future<int> process(FetchCounterJob job) async {
    await Future.delayed(Duration(milliseconds: 500));
    return 42;
  }
}

// ============ 3. Define State ============

class CounterState {
  final int count;
  final bool isLoading;

  const CounterState({this.count = 0, this.isLoading = false});

  CounterState copyWith({int? count, bool? isLoading}) => CounterState(
        count: count ?? this.count,
        isLoading: isLoading ?? this.isLoading,
      );
}

// ============ 4. Create Cubit (Orchestrator) ============

class CounterCubit extends OrchestratorCubit<CounterState> {
  CounterCubit() : super(const CounterState());

  void fetchCounter() {
    emit(state.copyWith(isLoading: true));
    dispatch(FetchCounterJob());
  }

  @override
  void onActiveSuccess(JobSuccessEvent event) {
    emit(state.copyWith(count: event.dataAs<int>() ?? 0, isLoading: false));
  }
}

// ============ 5. Use in Widget ============

void main() {
  // Register executor
  Dispatcher().register<FetchCounterJob>(CounterExecutor());

  runApp(
    BlocProvider(
      create: (_) => CounterCubit(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Orchestrator BLoC Example')),
        body: Center(
          child: BlocBuilder<CounterCubit, CounterState>(
            builder: (context, state) {
              if (state.isLoading) {
                return const CircularProgressIndicator();
              }
              return Text('Count: ${state.count}',
                  style: Theme.of(context).textTheme.headlineLarge);
            },
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => context.read<CounterCubit>().fetchCounter(),
          child: const Icon(Icons.refresh),
        ),
      ),
    );
  }
}
