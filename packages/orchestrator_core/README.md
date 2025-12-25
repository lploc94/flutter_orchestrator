# orchestrator_core

Event-Driven Orchestrator architecture for Dart/Flutter applications. Separate UI state management from business logic execution.

## Features

- **SignalBus**: Broadcast stream for event communication (Global or Scoped)
- **Dispatcher**: Type-based job routing with O(1) lookup
- **BaseExecutor**: Abstract executor with error boundary, timeout, retry, cancellation
- **BaseOrchestrator**: State machine with Active/Passive event routing
- **CancellationToken**: Token-based task cancellation
- **RetryPolicy**: Configurable retry with exponential backoff
- **JobBuilder**: Fluent API for configuring jobs
- **JobResult**: Sealed class for type-safe result handling
- **AsyncState**: Common state patterns for async operations

## Installation

```yaml
dependencies:
  orchestrator_core: ^0.0.3
```

## Quick Start

### 1. Define a Job

```dart
class FetchUserJob extends BaseJob {
  final String userId;
  FetchUserJob(this.userId) : super(id: generateJobId('user'));
}
```

### 2. Create an Executor

```dart
class FetchUserExecutor extends BaseExecutor<FetchUserJob> {
  @override
  Future<dynamic> process(FetchUserJob job) async {
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
  void onActiveSuccess(JobSuccessEvent event) {
    emit(state.copyWith(user: event.data, isLoading: false));
  }
}
```

## Advanced Usage

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
class UserState extends AsyncState<User> {
  const UserState({super.status, super.data, super.error});

  UserState copyWith({AsyncStatus? status, User? data, Object? error}) =>
      UserState(
        status: status ?? this.status,
        data: data ?? this.data,
        error: error,
      );
}

// Usage in orchestrator
void onActiveSuccess(JobSuccessEvent event) {
  emit(state.toSuccess(event.data as User));
}

void onActiveFailure(JobFailureEvent event) {
  emit(state.toFailure(event.error));
}
```

### Event Extensions - Easy Data Extraction

```dart
void onActiveSuccess(JobSuccessEvent event) {
  // Safe type casting with fallback
  final user = event.dataOrNull<User>();
  if (user != null) {
    emit(state.copyWith(user: user));
  }

  // Or use pattern with default
  final count = event.dataOr<int>(0);
}
```

## Documentation

See the full [documentation](https://github.com/lploc94/flutter_orchestrator/tree/main/book).

## License

MIT License
