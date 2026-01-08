# orchestrator_riverpod

Riverpod integration for orchestrator_core. Build scalable Flutter apps with Event-Driven Orchestrator pattern and compile-time safety.

## Features

- **OrchestratorNotifier**: Riverpod Notifier with job dispatch and unified event handling
- **Unified `onEvent` Pattern**: Single event handler with Dart 3 pattern matching (v0.6.0+)
- **`isJobRunning()` Helper**: Distinguish between your jobs and events from other orchestrators
- Compile-time safety with Riverpod

## Installation

```yaml
dependencies:
  orchestrator_riverpod: ^0.6.0
```

## Usage

```dart
// 1. Define your domain event
class UserLoadedEvent extends BaseEvent {
  final User user;
  UserLoadedEvent(super.correlationId, this.user);
}

// 2. Define your job (using EventJob)
class LoadUserJob extends EventJob<User, UserLoadedEvent> {
  final String userId;
  LoadUserJob(this.userId) : super(id: generateJobId('user'));

  @override
  UserLoadedEvent createEventTyped(User result) {
    return UserLoadedEvent(id, result);
  }
}

// 3. Create your Notifier with unified onEvent
class UserNotifier extends OrchestratorNotifier<UserState> {
  @override
  UserState buildState() => const UserState();

  void loadUser(String id) {
    state = state.copyWith(isLoading: true);
    dispatch(LoadUserJob(id));
  }

  @override
  void onEvent(BaseEvent event) {
    switch (event) {
      // Handle our domain event
      case UserLoadedEvent e when isJobRunning(e.correlationId):
        state = state.copyWith(user: e.user, isLoading: false);

      // Handle failure from our jobs
      case JobFailureEvent e when isJobRunning(e.correlationId):
        state = state.copyWith(error: e.error.toString(), isLoading: false);

      // Handle events from other orchestrators
      case UserUpdatedEvent e:
        state = state.copyWith(user: e.user);
    }
  }
}

// 4. Create provider
final userProvider = NotifierProvider<UserNotifier, UserState>(
  UserNotifier.new,
);
```

## Migration from v0.5.x

### Before (v0.5.x)
```dart
@override
void onActiveSuccess(JobSuccessEvent event) {
  state = state.copyWith(data: event.data, isLoading: false);
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
      state = state.copyWith(data: e.data, isLoading: false);
    case SomeEvent e:
      // Handle domain events (no active/passive distinction)
  }
}
```

## API Reference

### OrchestratorNotifier

| Method | Description |
|--------|-------------|
| `buildState()` | Override to provide initial state |
| `dispatch(job)` | Dispatch a job and track it |
| `isJobRunning(id)` | Check if a job is tracked by this notifier |
| `hasActiveJobs` | Check if any jobs are active |
| `onEvent(event)` | Unified handler for all events |
| `onProgress(event)` | Optional: Called on progress updates |
| `onJobStarted(event)` | Optional: Called when job starts |
| `onJobRetrying(event)` | Optional: Called on retry |

## Documentation

See the full [documentation](https://github.com/lploc94/flutter_orchestrator/blob/main/docs/en/README.md).

## License

MIT License
