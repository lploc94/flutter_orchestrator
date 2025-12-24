# Chapter 4: UI Integration

This chapter guides you through integrating `orchestrator_core` with popular Flutter state management solutions: **BLoC/Cubit**, **Provider**, and **Riverpod**.

---

## 4.1. Overview

The `orchestrator_core` framework is Pure Dart, with no Flutter dependencies. To use it in Flutter applications, we need adapter packages:

| Package | Description | Main Class |
|---------|-------------|------------|
| `orchestrator_bloc` | Flutter BLoC integration | `OrchestratorCubit`, `OrchestratorBloc` |
| `orchestrator_provider` | Provider integration | `OrchestratorNotifier` |
| `orchestrator_riverpod` | Riverpod integration | `OrchestratorNotifier` |

All of these wrap `BaseOrchestrator` logic and integrate with their respective lifecycles.

---

## 4.2. BLoC/Cubit Integration

### Installation

```yaml
dependencies:
  orchestrator_bloc:
    path: packages/orchestrator_bloc
```

### OrchestratorCubit

`OrchestratorCubit<S>` extends `Cubit<S>`, adding Job dispatch and Event listening capabilities.

```dart
abstract class OrchestratorCubit<S> extends Cubit<S> {
  final SignalBus _bus = SignalBus();
  final Dispatcher _dispatcher = Dispatcher();
  final Set<String> _activeJobIds = {};

  OrchestratorCubit(super.initialState) {
    _subscribeToBus();
  }

  String dispatch(BaseJob job) {
    final id = _dispatcher.dispatch(job);
    _activeJobIds.add(id);
    return id;
  }

  // Hooks for subclasses
  void onActiveSuccess(JobSuccessEvent event) {}
  void onActiveFailure(JobFailureEvent event) {}
  void onPassiveEvent(BaseEvent event) {}
}
```

### Usage

```dart
class CounterCubit extends OrchestratorCubit<CounterState> {
  CounterCubit() : super(const CounterState());

  void calculate(int value) {
    emit(state.copyWith(isLoading: true));
    dispatch(CalculateJob(value));
  }

  @override
  void onActiveSuccess(JobSuccessEvent event) {
    emit(state.copyWith(count: event.data as int, isLoading: false));
  }
}
```

---

## 4.3. Provider Integration

### Installation

```yaml
dependencies:
  orchestrator_provider:
    path: packages/orchestrator_provider
```

### OrchestratorNotifier

`OrchestratorNotifier<S>` extends `ChangeNotifier`, automatically calling `notifyListeners()` when state changes.

```dart
abstract class OrchestratorNotifier<S> extends ChangeNotifier {
  S _state;

  OrchestratorNotifier(this._state) {
    _subscribeToBus();
  }

  S get state => _state;
  
  set state(S newState) {
    _state = newState;
    notifyListeners();
  }

  String dispatch(BaseJob job) { /* ... */ }

  void onActiveSuccess(JobSuccessEvent event) {}
  void onActiveFailure(JobFailureEvent event) {}
}
```

### Usage

```dart
class CounterNotifier extends OrchestratorNotifier<CounterState> {
  CounterNotifier() : super(const CounterState());

  void calculate(int value) {
    state = state.copyWith(isLoading: true);
    dispatch(CalculateJob(value));
  }

  @override
  void onActiveSuccess(JobSuccessEvent event) {
    state = state.copyWith(count: event.data as int, isLoading: false);
  }
}
```

---

## 4.4. Riverpod Integration

### Installation

```yaml
dependencies:
  orchestrator_riverpod:
    path: packages/orchestrator_riverpod
```

### OrchestratorNotifier

`OrchestratorNotifier<S>` extends Riverpod's `Notifier<S>`, integrating with Riverpod's Provider system.

```dart
abstract class OrchestratorNotifier<S> extends Notifier<S> {
  final SignalBus _bus = SignalBus();
  final Dispatcher _dispatcher = Dispatcher();
  final Set<String> _activeJobIds = {};

  @override
  S build(); // Override to provide initial state

  String dispatch(BaseJob job) {
    final id = _dispatcher.dispatch(job);
    _activeJobIds.add(id);
    return id;
  }

  void onActiveSuccess(JobSuccessEvent event) {}
  void onActiveFailure(JobFailureEvent event) {}
  void onPassiveEvent(BaseEvent event) {}
}
```

### Usage

```dart
class CounterNotifier extends OrchestratorNotifier<CounterState> {
  @override
  CounterState build() => const CounterState();

  void calculate(int value) {
    state = state.copyWith(isLoading: true);
    dispatch(CalculateJob(value));
  }

  @override
  void onActiveSuccess(JobSuccessEvent event) {
    state = state.copyWith(count: event.data as int, isLoading: false);
  }
}

final counterProvider = NotifierProvider<CounterNotifier, CounterState>(
  CounterNotifier.new,
);
```

### Widget Usage

```dart
class CounterScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(counterProvider);
    
    if (state.isLoading) {
      return CircularProgressIndicator();
    }
    
    return Text('Count: ${state.count}');
  }
}
```

---

## 4.5. Comparison and Recommendations

| Criteria | BLoC/Cubit | Provider | Riverpod |
|----------|------------|----------|----------|
| **Ecosystem** | flutter_bloc | provider | riverpod |
| **Boilerplate** | Medium | Low | Low |
| **Type Safety** | Good | Medium | Excellent |
| **Testing** | bloc_test | flutter_test | riverpod test utilities |
| **Compile-time Safety** | No | No | Yes |

**Recommendations**:
- **BLoC**: Large projects requiring strict patterns.
- **Provider**: Small projects, teams new to Flutter.
- **Riverpod**: Projects needing type safety and compile-time checking.

---

## 4.6. Summary

All packages provide:
- **Dispatch**: Send Jobs and track via Correlation ID
- **Active/Passive Routing**: Automatic event classification
- **Lifecycle Integration**: Automatic cleanup on dispose

The next chapter covers advanced techniques like Cancellation, Timeout, and Retry.
