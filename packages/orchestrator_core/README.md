# orchestrator_core

Event-Driven Orchestrator architecture for Dart/Flutter applications. Separate UI state management from business logic execution.

## Features

- **SignalBus**: Broadcast stream for event communication (Global or Scoped)
- **Dispatcher**: Type-based job routing with O(1) lookup
- **BaseExecutor**: Abstract executor with error boundary, timeout, retry, cancellation
- **BaseOrchestrator**: State machine with unified `onEvent()` pattern (v0.6.0+)
- **EventJob**: Job that creates domain events with type-safe results
- **CancellationToken**: Token-based task cancellation
- **RetryPolicy**: Configurable retry with exponential backoff
- **SagaFlow**: Complex workflow orchestration with rollback support
- **JobBuilder**: Fluent API for configuring jobs
- **JobResult**: Sealed class for type-safe result handling
- **AsyncState**: Common state patterns for async operations

## Installation

```yaml
dependencies:
  orchestrator_core: ^0.6.0
```

## Quick Start

### 1. Define a Job

```dart
// Simple job
class FetchUserJob extends BaseJob {
  final String userId;
  FetchUserJob(this.userId) : super(id: generateJobId('user'));
}

// Or use EventJob for domain events (recommended)
class FetchUserJob extends EventJob<User, UserLoadedEvent> {
  final String userId;
  FetchUserJob(this.userId) : super(id: generateJobId('user'));

  @override
  UserLoadedEvent createEventTyped(User result) {
    return UserLoadedEvent(id, result);
  }
}
```

### 2. Create an Executor

```dart
class FetchUserExecutor extends BaseExecutor<FetchUserJob> {
  @override
  Future<User> process(FetchUserJob job) async {
    return await api.getUser(job.userId);
  }
}
```

### 3. Create an Orchestrator

```dart
class UserOrchestrator extends BaseOrchestrator<UserState> {
  UserOrchestrator() : super(const UserState());

  void loadUser(String id) {
    emit(state.copyWith(isLoading: true));
    dispatch(FetchUserJob(id));
  }

  @override
  void onEvent(BaseEvent event) {
    switch (event) {
      // Handle domain event from our job
      case UserLoadedEvent e when isJobRunning(e.correlationId):
        emit(state.copyWith(user: e.user, isLoading: false));

      // Handle failure from our job
      case JobFailureEvent e when isJobRunning(e.correlationId):
        emit(state.copyWith(error: e.error.toString(), isLoading: false));

      // Handle events from other orchestrators
      case UserUpdatedEvent e:
        emit(state.copyWith(user: e.user));
    }
  }
}
```

### 4. Register and Use

```dart
void main() {
  // Register executor
  Dispatcher().register<FetchUserJob>(FetchUserExecutor());

  // Use orchestrator
  final orchestrator = UserOrchestrator();
  orchestrator.loadUser('123');
}
```

## Advanced Usage

### EventJob - Domain Events (Recommended)

Instead of generic `JobSuccessEvent`, use `EventJob` to emit domain-specific events:

```dart
// Define domain event
class UserLoadedEvent extends BaseEvent {
  final User user;
  UserLoadedEvent(super.correlationId, this.user);
}

// Define job with typed result
class FetchUserJob extends EventJob<User, UserLoadedEvent> {
  final String userId;
  FetchUserJob(this.userId) : super(id: generateJobId('user'));

  @override
  UserLoadedEvent createEventTyped(User result) {
    return UserLoadedEvent(id, result);
  }
}

// Handle in orchestrator
@override
void onEvent(BaseEvent event) {
  switch (event) {
    case UserLoadedEvent e when isJobRunning(e.correlationId):
      emit(state.copyWith(user: e.user, isLoading: false));
  }
}
```

### JobBuilder - Fluent Configuration

```dart
final job = JobBuilder(FetchUserJob(userId))
    .withTimeout(Duration(seconds: 30))
    .withRetry(maxRetries: 3)
    .withCache(key: 'user_$userId', ttl: Duration(minutes: 5))
    .withPlaceholder(User.placeholder())
    .build();

orchestrator.dispatch(job);
```

### JobResult - Type-Safe Results

```dart
// Wait for job completion with proper result handling
final jobId = orchestrator.dispatch(FetchUserJob(userId));
final result = await JobResult.fromBus<User>(SignalBus.instance, jobId);

result.when(
  success: (user) => print('Got user: ${user.name}'),
  failure: (error, _) => print('Failed: $error'),
  cancelled: (_) => print('User cancelled'),
  timeout: (duration) => print('Timed out after $duration'),
);
```

### AsyncState - Common State Patterns

```dart
// Define state with async helpers
@GenerateAsyncState()
class UserState {
  final AsyncStatus status;
  final User? data;
  final Object? error;

  const UserState({
    this.status = AsyncStatus.initial,
    this.data,
    this.error,
  });
}

// Use in orchestrator
@override
void onEvent(BaseEvent event) {
  switch (event) {
    case JobSuccessEvent e when isJobRunning(e.correlationId):
      emit(state.toSuccess(e.data as User));
    case JobFailureEvent e when isJobRunning(e.correlationId):
      emit(state.toFailure(e.error));
  }
}

// View usage
Widget build(BuildContext context) {
  return state.when(
    initial: () => SizedBox(),
    loading: () => CircularProgressIndicator(),
    success: (user) => UserProfile(user),
    failure: (error) => ErrorView(error),
  );
}
```

### Event Extensions - Easy Data Extraction

```dart
@override
void onEvent(BaseEvent event) {
  if (event is JobSuccessEvent && isJobRunning(event.correlationId)) {
    // Safe type casting with fallback
    final user = event.dataOrNull<User>();
    if (user != null) {
      emit(state.copyWith(user: user));
    }

    // Or use pattern with default
    final count = event.dataOr<int>(0);
  }
}
```

### Saga Pattern - Complex Workflows (v0.5.2+)

```dart
final saga = SagaFlow(name: 'TransferAsset');

try {
  // Step 1: Deduct from Source
  await saga.run(
    action: () => dispatch(DeductJob(sourceId, amount)),
    compensate: (_) => dispatch(RefundJob(sourceId, amount)),
  );

  // Step 2: Add to Target
  await saga.run(
    action: () => dispatch(AddJob(targetId, amount)),
    compensate: (_) => dispatch(DeductJob(targetId, amount)),
  );

  // Success: Clear compensations
  saga.commit();
} catch (e) {
  // Failure: Rollback all successful steps (LIFO)
  await saga.rollback();
  rethrow;
}
```

## Migration from v0.5.x

### Before (v0.5.x)
```dart
@override
void onActiveSuccess(JobSuccessEvent event) {
  emit(state.copyWith(data: event.data, isLoading: false));
}

@override
void onActiveFailure(JobFailureEvent event) {
  emit(state.copyWith(error: event.error.toString(), isLoading: false));
}

@override
void onPassiveEvent(BaseEvent event) {
  if (event is SomeEvent) { ... }
}
```

### After (v0.6.0+)
```dart
@override
void onEvent(BaseEvent event) {
  switch (event) {
    case JobSuccessEvent e when isJobRunning(e.correlationId):
      emit(state.copyWith(data: e.data, isLoading: false));
    case JobFailureEvent e when isJobRunning(e.correlationId):
      emit(state.copyWith(error: e.error.toString(), isLoading: false));
    case SomeEvent e:
      // Handle domain events (no active/passive distinction)
  }
}
```

## API Reference

### BaseOrchestrator

| Method | Description |
|--------|-------------|
| `emit(state)` | Update state and notify listeners |
| `dispatch(job)` | Dispatch a job and track it |
| `isJobRunning(id)` | Check if a job is tracked by this orchestrator |
| `hasActiveJobs` | Check if any jobs are active |
| `onEvent(event)` | Unified handler for all events |
| `onProgress(event)` | Optional: Called on progress updates |
| `onJobStarted(event)` | Optional: Called when job starts |
| `onJobRetrying(event)` | Optional: Called on retry |

## Documentation

See the full [documentation](https://github.com/lploc94/flutter_orchestrator/blob/main/docs/en/README.md).

## License

MIT License
