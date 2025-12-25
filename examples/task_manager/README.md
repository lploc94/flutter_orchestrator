# Task Manager Example - Traditional vs Orchestrator

This example demonstrates the differences between **traditional Flutter state management** and the **Flutter Orchestrator pattern** through two identical Task Manager apps.

## 🎯 Purpose

Run both apps side-by-side to see how the Orchestrator pattern solves common problems in Flutter applications.

## 📂 Structure

```
task_manager/
├── shared/              # Shared models and mock API service
├── traditional/         # 🔴 Traditional approach (BLoC only)
├── orchestrator/        # 🟢 Orchestrator approach
└── README.md           # This file
```

## 🚀 Running the Apps

### Traditional App (Problems Demo)
```bash
cd traditional
flutter pub get
flutter run
```

### Orchestrator App (Solutions Demo)
```bash
cd orchestrator
flutter pub get
flutter run
```

## 🧪 Test Scenarios

### 1. Race Condition Test
**How to test:** Click "Fetch Tasks" button rapidly 5+ times

| Traditional (🔴) | Orchestrator (🟢) |
|-----------------|-------------------|
| Multiple API calls fire | Previous calls auto-cancelled |
| Results arrive in random order | Only latest result processed |
| UI flickers/shows stale data | Smooth, consistent UI |
| `Fetches: 5` but data inconsistent | `Fetches: 5` with correct data |

### 2. Search Race Condition
**How to test:** Type "hello" quickly in search box

| Traditional (🔴) | Orchestrator (🟢) |
|-----------------|-------------------|
| 5 API calls ("h", "he", "hel"...) | Each keystroke cancels previous |
| Results for "hel" may show after "hello" | Only "hello" results shown |
| Spinner keeps spinning | Clean loading state |

### 3. Error Handling & Retry
**How to test:** The mock API has 30% failure rate - trigger multiple fetches

| Traditional (🔴) | Orchestrator (🟢) |
|-----------------|-------------------|
| Single failure = permanent error | Auto-retry with exponential backoff |
| Must manually click "Retry" | Retries automatically (configurable) |
| No feedback during retry | Can show retry progress |

### 4. Memory Leak (Check Console)
**How to test:** Start an operation, then quickly navigate away/close

| Traditional (🔴) | Orchestrator (🟢) |
|-----------------|-------------------|
| Stream subscriptions may leak | Auto-cleanup on close |
| API calls continue after dispose | CancellationToken stops work |
| `setState called after dispose` errors | Clean lifecycle management |

## 📊 Code Comparison

### State Class
```dart
// Traditional: 20+ boolean flags, 7 error fields
class TaskState {
  final bool isLoading;
  final bool isLoadingCategories;
  final bool isLoadingStats;
  final bool isCreating;
  final bool isDeleting;
  final bool isSearching;
  final bool isUploading;
  final String? error;
  final String? categoryError;
  final String? statsError;
  // ... 130+ lines
}

// Orchestrator: Simplified, job tracking handles loading
class TaskState {
  final bool isLoading;
  final bool isSearching;
  final bool isCreating;
  final String? error;
  // ... 75 lines
}
```

### Cubit/Orchestrator
```dart
// Traditional: 350+ lines, handles everything
class TaskCubit extends Cubit<TaskState> {
  // API calls mixed with state management
  // No cancellation
  // No retry
  // Manual coordination
}

// Orchestrator: 240 lines, clean separation
class TaskOrchestrator extends OrchestratorCubit<TaskState> {
  // Only dispatches jobs
  // Cancellation built-in
  // Retry via RetryPolicy
  // Events auto-routed
}
```

### Cancellation
```dart
// Traditional: No cancellation possible
Future<void> fetchTasks() async {
  emit(state.copyWith(isLoading: true));
  final tasks = await _api.fetchTasks(); // Can't cancel!
  emit(state.copyWith(tasks: tasks));
}

// Orchestrator: Built-in cancellation
void fetchTasks() {
  _fetchToken?.cancel(); // Cancel previous
  _fetchToken = CancellationToken();
  dispatch(FetchTasksJob(cancellationToken: _fetchToken));
}
```

## 🔑 Key Features Demonstrated

| Feature | Traditional | Orchestrator |
|---------|-------------|--------------|
| Race Condition Prevention | ❌ | ✅ CancellationToken |
| Auto Retry | ❌ | ✅ RetryPolicy |
| Error Boundary | ❌ | ✅ Built-in |
| Progress Tracking | Manual | ✅ JobProgressEvent |
| Timeout Handling | Manual | ✅ Built-in |
| Memory Safety | Manual | ✅ Auto-cleanup |
| Testability | Hard (God class) | Easy (Separate concerns) |
| Code Lines | ~500 | ~350 |

## 🏗️ Architecture Comparison

### Traditional
```
┌─────────────────────────────────────┐
│           TaskCubit (GOD CLASS)     │
│  ┌─────────────────────────────┐   │
│  │ State Management            │   │
│  │ API Calls                   │   │
│  │ Error Handling              │   │
│  │ Loading States              │   │
│  │ Caching Logic               │   │
│  │ Retry Logic                 │   │
│  │ ... everything              │   │
│  └─────────────────────────────┘   │
└─────────────────────────────────────┘
```

### Orchestrator
```
┌─────────────────┐     ┌─────────────────┐
│  Orchestrator   │────▶│   Dispatcher    │
│  (UI State)     │     └────────┬────────┘
└─────────────────┘              │
        ▲                        ▼
        │              ┌─────────────────┐
        │              │    Executors    │
        │              │  (Business Logic)│
        │              └────────┬────────┘
        │                       │
        │    ┌──────────────────┘
        │    ▼
┌─────────────────┐
│   SignalBus     │
│   (Events)      │
└─────────────────┘
```

## 📝 Mock API Configuration

The `MockApiService` in `shared/` is configured for chaos testing:

```dart
// Adjust these to test different scenarios
bool chaosMode = true;           // Enable random delays/failures
double failureRate = 0.3;        // 30% chance to fail
Duration minDelay = Duration(milliseconds: 500);
Duration maxDelay = Duration(seconds: 3);
```

## 🎓 Learning Path

1. Run **Traditional** app first, observe the problems
2. Run **Orchestrator** app, see the solutions
3. Compare the code side-by-side
4. Read the comments in each file explaining WHY

## 📚 Related Documentation

- [Flutter Orchestrator Book](../../../book/README.md)
- [orchestrator_core Package](../../../packages/orchestrator_core/README.md)
- [orchestrator_bloc Package](../../../packages/orchestrator_bloc/README.md)

