// lib/main.dart
// Entry point - Setup Orchestrator and run the app

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:orchestrator_core/orchestrator_core.dart';
// Import orchestrator_flutter to auto-activate DevTools observer
// ignore: unused_import
import 'package:orchestrator_flutter/orchestrator_flutter.dart';

import 'jobs/counter_jobs.dart';
import 'executors/counter_executor.dart';
import 'cubit/counter_cubit.dart';
import 'cubit/counter_state.dart';

void main() {
  // 1. Register Executors BEFORE runApp
  _registerExecutors();

  // 2. (Optional) Enable debug logging
  OrchestratorConfig.enableDebugLogging();

  // 3. DevTools Observer
  initDevToolsObserver();

  runApp(const MyApp());
}

/// Register all Executors with Dispatcher
/// This connects Job types to their handlers
void _registerExecutors() {
  final dispatcher = Dispatcher();

  // Option 1: Simple executors (each manages its own state)
  // dispatcher.register<IncrementJob>(IncrementExecutor());
  // dispatcher.register<DecrementJob>(DecrementExecutor());
  // dispatcher.register<ResetJob>(ResetExecutor());

  // Option 2: Executors with shared service (recommended)
  final counterService = CounterService();
  dispatcher.register<IncrementJob>(
    IncrementWithServiceExecutor(counterService),
  );
  dispatcher.register<DecrementJob>(
    DecrementWithServiceExecutor(counterService),
  );
  dispatcher.register<ResetJob>(ResetWithServiceExecutor(counterService));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Orchestrator Counter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const CounterPage(),
    );
  }
}

/// Counter Page - UI connected to CounterCubit
class CounterPage extends StatelessWidget {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CounterCubit(),
      child: const CounterView(),
    );
  }
}

/// Counter View - Displays state and handles user input
class CounterView extends StatelessWidget {
  const CounterView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Orchestrator Counter'),
        actions: [
          // Reset button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<CounterCubit>().reset(),
            tooltip: 'Reset',
          ),
        ],
      ),
      body: Center(
        child: BlocBuilder<CounterCubit, CounterState>(
          builder: (context, state) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('You have pushed the button this many times:'),
                const SizedBox(height: 16),

                // Show loading indicator or count
                if (state.isLoading)
                  const SizedBox(
                    height: 60,
                    width: 60,
                    child: CircularProgressIndicator(),
                  )
                else
                  Text(
                    '${state.count}',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                // Show error if any
                if (state.error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    state.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Increment button
          FloatingActionButton(
            heroTag: 'increment',
            onPressed: () => context.read<CounterCubit>().increment(),
            tooltip: 'Increment',
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 8),
          // Decrement button
          FloatingActionButton(
            heroTag: 'decrement',
            onPressed: () => context.read<CounterCubit>().decrement(),
            tooltip: 'Decrement',
            child: const Icon(Icons.remove),
          ),
        ],
      ),
    );
  }
}
