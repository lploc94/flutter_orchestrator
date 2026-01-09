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

    // Cross-orchestrator event - NO guard (we want all)
    case UserUpdatedEvent e:
      emit(state.copyWith(user: e.user));
  }
}
```

### 2. Job Type

All jobs must extend `EventJob<TResult, TEvent>` with their domain event:

```dart
// Define domain event
class OrderCreatedEvent extends BaseEvent {
  final Order order;
  OrderCreatedEvent(super.correlationId, this.order);
}

// Define job
class CreateOrderJob extends EventJob<Order, OrderCreatedEvent> {
  final List<Item> items;
  CreateOrderJob(this.items) : super(id: generateJobId('create_order'));

  @override
  OrderCreatedEvent createEventTyped(Order result) => OrderCreatedEvent(id, result);
}
```

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
class FetchDataJob extends EventJob<Data, DataLoadedEvent> {
  FetchDataJob() : super(
    id: generateJobId('fetch_data'),
    retryPolicy: RetryPolicy(
      maxRetries: 3,
      baseDelay: Duration(seconds: 1),
      exponentialBackoff: true,
    ),
  );

  @override
  DataLoadedEvent createEventTyped(Data result) => DataLoadedEvent(id, result);
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
    }
  }
}

final userProvider = NotifierProvider<UserNotifier, UserState>(
  UserNotifier.new,
);
```

## Event Types Reference

In v0.6.0+, all jobs emit domain-specific events via `EventJob.createEventTyped()`. There are no generic `JobSuccessEvent` - every operation defines its own event type.

| Event | When Emitted | Key Fields |
|-------|--------------|------------|
| Custom `extends BaseEvent` | Job succeeds | Custom fields defined by you |
| `NetworkSyncFailureEvent` | Offline sync fails | `error`, `retryCount`, `isPoisoned` |

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

### ❌ Wrong: Using old BaseJob pattern (v0.5.x)
```dart
class MyJob extends BaseJob { ... }  // REMOVED in v0.6.0

@override
void onActiveSuccess(JobSuccessEvent event) { ... }  // REMOVED in v0.6.0
```

### ✅ Correct: Using EventJob + onEvent (v0.6.0+)
```dart
class MyJob extends EventJob<Result, MyEvent> {
  @override
  MyEvent createEventTyped(Result result) => MyEvent(id, result);
}

@override
void onEvent(BaseEvent event) {
  switch (event) {
    case MyEvent e when isJobRunning(e.correlationId):
      emit(state.copyWith(data: e.result));
  }
}
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
