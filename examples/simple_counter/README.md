# Simple Counter Example

A simple Counter app using **Flutter Orchestrator** - Hello World example.

## 📁 Structure

```
lib/
├── jobs/
│   └── counter_jobs.dart      # IncrementJob, DecrementJob, ResetJob
├── executors/
│   └── counter_executor.dart  # Business logic (pure Dart)
├── cubit/
│   ├── counter_state.dart     # Immutable state
│   └── counter_cubit.dart     # Orchestrator (connects UI & logic)
└── main.dart                  # Entry point & UI
```

## 🚀 Run the App

```bash
cd examples/simple_counter
flutter pub get
flutter run
```

## 🎯 Data Flow

```
1. User taps (+) button 
   → CounterCubit.increment()
   
2. Cubit dispatches Job
   → dispatch(IncrementJob())
   
3. Dispatcher finds Executor
   → IncrementWithServiceExecutor.process()
   
4. Executor processes & emits Event
   → emit(JobSuccessEvent(newCount))
   
5. Cubit receives Event via hook
   → onActiveSuccess(event)
   
6. Cubit updates State
   → emit(state.copyWith(count: newCount))
   
7. UI rebuilds with new count
```

## 📖 Documentation

- [Getting Started](../../docs/vi/guide/getting_started.md)
- [Core Concepts](../../docs/vi/guide/core_concepts.md)
- [Integration Guide](../../docs/vi/guide/integration.md)

## 🔑 Key Takeaways

1. **Job** = Data class describing an action (no logic)
2. **Executor** = Pure Dart business logic (easy to test)
3. **Cubit** = Orchestrator connecting UI and logic
4. **State** = Immutable with `copyWith`

## 🧪 Testing

Executors are pure Dart → Easy to test:

```dart
test('increment should increase count', () async {
  final service = CounterService();
  final executor = IncrementWithServiceExecutor(service);
  
  await executor.process(IncrementJob());
  expect(service.count, equals(1));
  
  await executor.process(IncrementJob());
  expect(service.count, equals(2));
});
```
