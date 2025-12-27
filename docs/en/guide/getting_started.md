# Getting Started with Flutter Orchestrator

This guide will help you integrate **Flutter Orchestrator** into your Flutter project in just a few minutes.

### Overview Flow

```mermaid
flowchart LR
    subgraph UI["UI Layer"]
        Widget["Widget"]
        State["State"]
    end
    
    subgraph Core["Orchestrator Core"]
        Orchestrator["Orchestrator"]
        Dispatcher["Dispatcher"]
        Executor["Executor"]
    end
    
    Widget -->|"call method"| Orchestrator
    Orchestrator -->|"dispatch(Job)"| Dispatcher
    Dispatcher -->|"execute()"| Executor
    Executor -->|"emit(Event)"| Orchestrator
    Orchestrator -->|"emit(State)"| State
    State -->|"rebuild"| Widget
    
    style Core fill:#e3f2fd,stroke:#1565c0,color:#000
```

---

## 1. Installation

Add packages to `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Core framework (REQUIRED)
  orchestrator_core: ^0.3.3
  
  # Choose 1 suitable integration:
  orchestrator_bloc: ^0.3.1      # If using flutter_bloc
  # orchestrator_provider: ^0.3.1  # If using provider
  # orchestrator_riverpod: ^0.3.1  # If using riverpod

  # Flutter platform support (offline queue, cleanup, DevTools observer)
  orchestrator_flutter: ^0.3.2

dev_dependencies:
  build_runner: ^2.4.0
  orchestrator_generator: ^0.3.1  # Optional code generation
```

---

## 2. Setup in main()

```dart
import 'package:flutter/material.dart';
import 'package:orchestrator_core/orchestrator_core.dart';
import 'package:orchestrator_flutter/orchestrator_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Register all Executors BEFORE runApp
  _registerExecutors();

  // 2. (Optional) Flutter integrations (offline queue, cleanup...)
  OrchestratorFlutter.initialize();

  // 3. (Optional) Enable debug logging
  OrchestratorConfig.enableDebugLogging();

  // 4. (Optional) DevTools observer (debug/profile only)
  initDevToolsObserver();
  
  runApp(const MyApp());
}

void _registerExecutors() {
  final dispatcher = Dispatcher();

  final counterService = CounterService();
  
  // Each Job type -> One Executor
  dispatcher.register<IncrementJob>(IncrementExecutor(counterService));
  dispatcher.register<DecrementJob>(DecrementExecutor(counterService));
  // ... add other executors
}
```

---

## 3. Hello World - Counter App

Let's create a **Counter App** in Orchestrator style to understand the flow.

### Step 1: Define Job

Job is a **data class** describing the action to be performed:

```dart
import 'package:orchestrator_core/orchestrator_core.dart';

class IncrementJob extends BaseJob {
  IncrementJob() : super(id: generateJobId('increment'));
}

class DecrementJob extends BaseJob {
  DecrementJob() : super(id: generateJobId('decrement'));
}
```

### Step 2: Create Executor

Executor contains the actual **business logic**:

```dart
class CounterService {
  int _count = 0;

  int increment() => ++_count;
  int decrement() => --_count;
}

class IncrementExecutor extends BaseExecutor<IncrementJob> {
  final CounterService _service;

  IncrementExecutor(this._service);

  @override
  Future<int> process(IncrementJob job) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 300));
    return _service.increment();
  }
}

class DecrementExecutor extends BaseExecutor<DecrementJob> {
  final CounterService _service;

  DecrementExecutor(this._service);

  @override
  Future<int> process(DecrementJob job) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _service.decrement();
  }
}
```

### Step 3: Define State

State must be **immutable** with a `copyWith` method:

```dart
class CounterState {
  final int count;
  final bool isLoading;
  final String? error;

  const CounterState({
    this.count = 0,
    this.isLoading = false,
    this.error,
  });

  CounterState copyWith({int? count, bool? isLoading, String? error}) {
    return CounterState(
      count: count ?? this.count,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}
```

### Step 4: Create Orchestrator

Orchestrator manages UI State and handles results:

```dart
import 'package:orchestrator_bloc/orchestrator_bloc.dart';

class CounterCubit extends OrchestratorCubit<CounterState> {
  CounterCubit() : super(const CounterState());

  void increment() {
    emit(state.copyWith(isLoading: true));
    dispatch(IncrementJob());
  }

  void decrement() {
    emit(state.copyWith(isLoading: true));
    dispatch(DecrementJob());
  }

  @override
  void onActiveSuccess(JobSuccessEvent event) {
    final newCount = event.dataAs<int>();
    emit(state.copyWith(count: newCount, isLoading: false));
  }

  @override
  void onActiveFailure(JobFailureEvent event) {
    emit(state.copyWith(isLoading: false, error: event.error.toString()));
  }
}
```

### Step 5: Connect to UI

```dart
import 'package:flutter_bloc/flutter_bloc.dart';

class CounterPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CounterCubit(),
      child: BlocBuilder<CounterCubit, CounterState>(
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(title: Text('Orchestrator Counter')),
            body: Center(
              child: state.isLoading
                  ? CircularProgressIndicator()
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Count: ${state.count}', style: TextStyle(fontSize: 48)),
                        if (state.error != null)
                          Text('Error: ${state.error}', style: TextStyle(color: Colors.red)),
                      ],
                    ),
            ),
            floatingActionButton: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  onPressed: () => context.read<CounterCubit>().increment(),
                  child: Icon(Icons.add),
                ),
                SizedBox(height: 8),
                FloatingActionButton(
                  onPressed: () => context.read<CounterCubit>().decrement(),
                  child: Icon(Icons.remove),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
```

### Step 6: Register Executors

```dart
void main() {
  // IMPORTANT: Register BEFORE runApp
  final dispatcher = Dispatcher();
  final counterService = CounterService();

  dispatcher.register<IncrementJob>(IncrementExecutor(counterService));
  dispatcher.register<DecrementJob>(DecrementExecutor(counterService));
  
  runApp(MaterialApp(home: CounterPage()));
}
```

---

## 4. Result

🎉 **Congratulations!** You have completed the basic flow:

```mermaid
sequenceDiagram
    participant UI as CounterPage
    participant Cubit as CounterCubit
    participant Dispatcher
    participant Executor as IncrementExecutor
    
    UI->>Cubit: increment()
    Cubit->>Cubit: emit(isLoading: true)
    Cubit->>Dispatcher: dispatch(IncrementJob)
    Dispatcher->>Executor: execute(job)
    Executor->>Executor: process() + delay
    Executor-->>Cubit: JobSuccessEvent(newCount)
    Cubit->>Cubit: emit(count: newCount)
    Cubit-->>UI: rebuild with new count
```

**Benefits achieved:**
- ✅ Business logic completely separated from UI
- ✅ Executor can be tested independently (Pure Dart)
- ✅ UI only cares about State
- ✅ Easy to add retry, timeout, caching...

---

## 📦 Example Project

> See complete code at: **[examples/simple_counter](../../../examples/simple_counter)**

```bash
cd examples/simple_counter
flutter pub get
flutter run
```

Project structure:
```
lib/
├── jobs/counter_jobs.dart        # IncrementJob, DecrementJob, ResetJob
├── executors/counter_executor.dart  # Business logic
├── cubit/
│   ├── counter_state.dart        # Immutable state
│   └── counter_cubit.dart        # Orchestrator
└── main.dart                     # Entry point
```

---

## Next Steps

- [Core Concepts](core_concepts.md) - Quick overview of concepts
- [Integration](integration.md) - Details on Bloc/Provider/Riverpod
- [Job](../concepts/job.md) - All Job features (Retry, Timeout, Cache...)
