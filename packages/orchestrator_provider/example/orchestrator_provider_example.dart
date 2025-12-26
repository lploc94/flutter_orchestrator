// Copyright (c) 2024, Flutter Orchestrator
// SPDX-License-Identifier: MIT

/// Example demonstrating Provider integration with Orchestrator pattern.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:orchestrator_provider/orchestrator_provider.dart';

// ============ 1. Define Job ============

class FetchDataJob extends BaseJob {
  FetchDataJob() : super(id: generateJobId('data'));
}

// ============ 2. Create Executor ============

class DataExecutor extends BaseExecutor<FetchDataJob> {
  @override
  Future<String> process(FetchDataJob job) async {
    await Future.delayed(Duration(milliseconds: 500));
    return 'Hello from Orchestrator!';
  }
}

// ============ 3. Define State ============

class AppState {
  final String? message;
  final bool isLoading;

  const AppState({this.message, this.isLoading = false});

  AppState copyWith({String? message, bool? isLoading}) => AppState(
        message: message ?? this.message,
        isLoading: isLoading ?? this.isLoading,
      );
}

// ============ 4. Create Notifier (Orchestrator) ============

class AppNotifier extends OrchestratorNotifier<AppState> {
  AppNotifier() : super(const AppState());

  void fetchData() {
    state = state.copyWith(isLoading: true);
    dispatch(FetchDataJob());
  }

  @override
  void onActiveSuccess(JobSuccessEvent event) {
    state = state.copyWith(
      message: event.dataAs<String>(),
      isLoading: false,
    );
  }
}

// ============ 5. Use in Widget ============

void main() {
  Dispatcher().register<FetchDataJob>(DataExecutor());

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppNotifier(),
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
        appBar: AppBar(title: const Text('Orchestrator Provider Example')),
        body: Center(
          child: Consumer<AppNotifier>(
            builder: (context, notifier, _) {
              if (notifier.state.isLoading) {
                return const CircularProgressIndicator();
              }
              return Text(
                notifier.state.message ?? 'Press button to load',
                style: Theme.of(context).textTheme.headlineSmall,
              );
            },
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => context.read<AppNotifier>().fetchData(),
          child: const Icon(Icons.refresh),
        ),
      ),
    );
  }
}
