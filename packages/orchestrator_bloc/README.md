# orchestrator_bloc

Flutter BLoC/Cubit integration for orchestrator_core. Build scalable Flutter apps with Event-Driven Orchestrator pattern.

## Features

- **OrchestratorCubit**: Cubit with job dispatch and event routing
- **OrchestratorBloc**: Bloc with job dispatch and event routing
- Automatic Active/Passive event classification
- Lifecycle integration with BLoC

## Installation

```yaml
dependencies:
  orchestrator_bloc: ^0.2.0
```

## Usage

```dart
class CounterCubit extends OrchestratorCubit<CounterState> {
  CounterCubit() : super(const CounterState());

  void increment() {
    emit(state.copyWith(isLoading: true));
    dispatch(IncrementJob());
  }

  @override
  void onActiveSuccess(JobSuccessEvent event) {
    emit(state.copyWith(count: event.data, isLoading: false));
  }
}
```

## Documentation

See the full [documentation](https://github.com/lploc94/flutter_orchestrator/tree/main/book).

## License

MIT License
