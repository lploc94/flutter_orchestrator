# orchestrator_riverpod

Riverpod integration for orchestrator_core. Build scalable Flutter apps with Event-Driven Orchestrator pattern and compile-time safety.

## Features

- **OrchestratorNotifier**: Riverpod Notifier with job dispatch and event routing
- Automatic Active/Passive event classification
- Compile-time safety with Riverpod

## Installation

```yaml
dependencies:
  orchestrator_riverpod: ^0.2.0
```

## Usage

```dart
class CounterNotifier extends OrchestratorNotifier<CounterState> {
  @override
  CounterState buildState() => const CounterState();

  void increment() {
    state = state.copyWith(isLoading: true);
    dispatch(IncrementJob());
  }

  @override
  void onActiveSuccess(JobSuccessEvent event) {
    state = state.copyWith(count: event.data, isLoading: false);
  }
}

final counterProvider = NotifierProvider<CounterNotifier, CounterState>(
  CounterNotifier.new,
);
```

## Documentation

See the full [documentation](https://github.com/lploc94/flutter_orchestrator/tree/main/book).

## License

MIT License
