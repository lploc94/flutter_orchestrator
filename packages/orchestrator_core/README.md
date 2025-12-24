# orchestrator_core

Event-Driven Orchestrator architecture for Dart/Flutter applications. Separate UI state management from business logic execution.

## Features

- **SignalBus**: Broadcast stream for event communication (Global or Scoped)
- **Dispatcher**: Type-based job routing with O(1) lookup
- **BaseExecutor**: Abstract executor with error boundary, timeout, retry, cancellation
- **BaseOrchestrator**: State machine with Active/Passive event routing
- **CancellationToken**: Token-based task cancellation
- **RetryPolicy**: Configurable retry with exponential backoff

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

## Documentation

See the full [documentation](https://github.com/lploc94/flutter_orchestrator/tree/main/book).

## License

MIT License
