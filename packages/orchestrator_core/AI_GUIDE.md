# CLAUDE.md - AI Agent Guide for Flutter Orchestrator

This guide helps AI agents (Claude, GPT, Copilot, etc.) understand and generate correct code using the Flutter Orchestrator pattern.

## Quick Reference

### Version
- `orchestrator_core: ^0.6.0`
- `orchestrator_riverpod: ^0.6.0-beta.1`

### Core Pattern (v0.6.0+)
```dart
// 1. Define domain event
class UserLoadedEvent extends BaseEvent {
  final User user;
  UserLoadedEvent(super.correlationId, this.user);
}

// 2. Define job using EventJob
class FetchUserJob extends EventJob<User, UserLoadedEvent> {
  final String userId;
  FetchUserJob(this.userId) : super(id: generateJobId('user'));

  @override
  UserLoadedEvent createEventTyped(User result) {
    return UserLoadedEvent(id, result);
  }
}

// 3. Create executor
class FetchUserExecutor extends BaseExecutor<FetchUserJob> {
  @override
  Future<User> process(FetchUserJob job) async {
    return await api.getUser(job.userId);
  }
}

// 4. Create orchestrator with unified onEvent
class UserOrchestrator extends BaseOrchestrator<UserState> {
  UserOrchestrator() : super(const UserState());

  void loadUser(String id) {
    emit(state.copyWith(isLoading: true));
    dispatch(FetchUserJob(id));
  }

  @override
  void onEvent(BaseEvent event) {
    switch (event) {
      case UserLoadedEvent e when isJobRunning(e.correlationId):
        emit(state.copyWith(user: e.user, isLoading: false));
      case JobFailureEvent e when isJobRunning(e.correlationId):
        emit(state.copyWith(error: e.error.toString(), isLoading: false));
    }
  }
}
```

## Key Patterns

### 1. Event Handling with `isJobRunning()`

**ALWAYS** use `isJobRunning(correlationId)` guard for events from your own jobs:

```dart
@override
void onEvent(BaseEvent event) {
  switch (event) {
    // OUR job's event - use guard
    case UserLoadedEvent e when isJobRunning(e.correlationId):
      emit(state.copyWith(user: e.user));

    // OUR job's failure - use guard
    case JobFailureEvent e when isJobRunning(e.correlationId):
      emit(state.copyWith(error: e.error.toString()));

    // Cross-orchestrator event - NO guard (we want all)
    case UserUpdatedEvent e:
      emit(state.copyWith(user: e.user));
  }
}
```

### 2. Job Types

| Type | Use Case | Success Event |
|------|----------|---------------|
| `EventJob<T, E>` | Domain events (recommended) | Custom event (e.g., `UserLoadedEvent`) |
| `BaseJob` | Simple operations | `JobSuccessEvent` with `e.data` |

### 3. Progress Reporting (Executor)

```dart
class UploadExecutor extends BaseExecutor<UploadJob> {
  @override
  Future<String> process(UploadJob job) async {
    for (int i = 1; i <= 10; i++) {
      await uploadChunk(i);
      emitProgress(
        job.id,
        progress: i / 10.0,  // 0.0 to 1.0
        message: 'Uploading $i/10',
      );
    }
    return 'https://cdn.example.com/file';
  }
}
```

### 4. Retry Policy

```dart
class MyJob extends BaseJob {
  MyJob() : super(
    id: generateJobId('my'),
    retryPolicy: RetryPolicy(
      maxRetries: 3,
      baseDelay: Duration(seconds: 1),
      exponentialBackoff: true,
    ),
  );
}
```

### 5. Riverpod Integration

```dart
class UserNotifier extends OrchestratorNotifier<UserState> {
  @override
  UserState buildState() => const UserState();

  void loadUser(String id) {
    state = state.copyWith(isLoading: true);
    dispatch(FetchUserJob(id));
  }

  @override
  void onEvent(BaseEvent event) {
    switch (event) {
      case UserLoadedEvent e when isJobRunning(e.correlationId):
        state = state.copyWith(user: e.user, isLoading: false);
      case JobFailureEvent e when isJobRunning(e.correlationId):
        state = state.copyWith(error: e.error.toString(), isLoading: false);
    }
  }
}

final userProvider = NotifierProvider<UserNotifier, UserState>(
  UserNotifier.new,
);
```

## Event Types Reference

| Event | When Emitted | Key Fields |
|-------|--------------|------------|
| `JobStartedEvent` | Job begins execution | `correlationId` |
| `JobProgressEvent` | Progress update | `progress`, `message` |
| `JobSuccessEvent<T>` | BaseJob succeeds | `data` |
| `JobFailureEvent` | Any job fails | `error`, `stackTrace` |
| `JobRetryingEvent` | Before retry attempt | `attempt`, `maxRetries` |
| `JobCancelledEvent` | Job cancelled | - |
| `JobTimeoutEvent` | Job timed out | `timeout` |
| Custom `extends BaseEvent` | EventJob succeeds | Custom fields |

## State Pattern

```dart
class MyState {
  final bool isLoading;
  final Data? data;
  final String? error;

  const MyState({this.isLoading = false, this.data, this.error});

  MyState copyWith({bool? isLoading, Data? data, String? error}) => MyState(
    isLoading: isLoading ?? this.isLoading,
    data: data ?? this.data,
    error: error,  // Allow null to clear
  );
}
```

## Common Mistakes to Avoid

### ❌ Wrong: Missing `isJobRunning()` guard
```dart
case UserLoadedEvent e:  // Will catch events from OTHER orchestrators too!
  emit(state.copyWith(user: e.user));
```

### ✅ Correct: With guard
```dart
case UserLoadedEvent e when isJobRunning(e.correlationId):
  emit(state.copyWith(user: e.user));
```

### ❌ Wrong: Using old API (v0.5.x)
```dart
@override
void onActiveSuccess(JobSuccessEvent event) { ... }  // REMOVED in v0.6.0
```

### ✅ Correct: Using new API (v0.6.0+)
```dart
@override
void onEvent(BaseEvent event) {
  switch (event) { ... }
}
```

### ❌ Wrong: Forgetting to handle JobFailureEvent
```dart
// Only handling success - errors will be silently ignored!
case UserLoadedEvent e when isJobRunning(e.correlationId):
  emit(state.copyWith(user: e.user));
```

### ✅ Correct: Always handle failures
```dart
case UserLoadedEvent e when isJobRunning(e.correlationId):
  emit(state.copyWith(user: e.user, isLoading: false));
case JobFailureEvent e when isJobRunning(e.correlationId):
  emit(state.copyWith(error: e.error.toString(), isLoading: false));
```

## File Structure

```
lib/features/<feature>/
├── jobs/
│   └── fetch_user_job.dart      # EventJob definitions
├── executors/
│   └── fetch_user_executor.dart # Business logic
├── logic/
│   └── user_orchestrator.dart   # State management
└── presentation/
    └── user_screen.dart         # UI
```

## Registration

```dart
void main() {
  // Register executors BEFORE using orchestrators
  Dispatcher().register<FetchUserJob>(FetchUserExecutor());
  Dispatcher().register<UploadJob>(UploadExecutor());

  runApp(MyApp());
}
```

## Examples

See runnable examples:
- `packages/orchestrator_core/example/orchestrator_core_example.dart`
- `packages/orchestrator_riverpod/example/orchestrator_riverpod_example.dart`

## Documentation

- [Full Documentation](https://github.com/lploc94/flutter_orchestrator/blob/main/docs/en/README.md)
- [orchestrator_core README](packages/orchestrator_core/README.md)
- [orchestrator_riverpod README](packages/orchestrator_riverpod/README.md)
