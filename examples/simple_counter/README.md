# Simple Counter Example

Ứng dụng Counter đơn giản sử dụng **Flutter Orchestrator** - Ví dụ Hello World.

## 📁 Cấu trúc

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

## 🚀 Chạy ứng dụng

```bash
cd examples/simple_counter
flutter pub get
flutter run
```

## 🎯 Luồng hoạt động

```
1. User nhấn nút (+) 
   → CounterCubit.increment()
   
2. Cubit dispatch Job
   → dispatch(IncrementJob())
   
3. Dispatcher tìm Executor
   → IncrementWithServiceExecutor.process()
   
4. Executor xử lý & emit Event
   → emit(JobSuccessEvent(newCount))
   
5. Cubit nhận Event qua hook
   → onActiveSuccess(event)
   
6. Cubit cập nhật State
   → emit(state.copyWith(count: newCount))
   
7. UI rebuild với count mới
```

## 📖 Tài liệu tham khảo

- [Getting Started](../../docs/vi/guide/getting_started.md)
- [Core Concepts](../../docs/vi/guide/core_concepts.md)
- [Integration Guide](../../docs/vi/guide/integration.md)

## 🔑 Key Takeaways

1. **Job** = Data class mô tả action (không có logic)
2. **Executor** = Pure Dart business logic (dễ test)
3. **Cubit** = Orchestrator kết nối UI và logic
4. **State** = Immutable với `copyWith`

## 🧪 Test

Executor thuần Dart → Test đơn giản:

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
