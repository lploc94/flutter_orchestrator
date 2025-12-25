# orchestrator_provider

Provider/ChangeNotifier integration for orchestrator_core. Build scalable Flutter apps with Event-Driven Orchestrator pattern.

## Features

- **OrchestratorNotifier**: ChangeNotifier with job dispatch and event routing
- Automatic Active/Passive event classification
- Lifecycle integration with Provider

## Installation

```yaml
dependencies:
  orchestrator_provider: ^0.2.0
```

## Usage

```dart
class CounterNotifier extends OrchestratorNotifier<CounterState> {
  CounterNotifier() : super(const CounterState());

  void increment() {
    state = state.copyWith(isLoading: true);
    dispatch(IncrementJob());
  }

  @override
  void onActiveSuccess(JobSuccessEvent event) {
    state = state.copyWith(count: event.data, isLoading: false);
  }
}
```

## Documentation

See the full [documentation](https://github.com/lploc94/flutter_orchestrator/tree/main/book).

## License

MIT License
