# Chương 4: Tích hợp Giao diện

Chương này hướng dẫn tích hợp `orchestrator_core` với các giải pháp quản lý trạng thái phổ biến trong Flutter: **BLoC/Cubit**, **Provider**, và **Riverpod**.

---

## 4.1. Tổng quan

Framework `orchestrator_core` là Pure Dart, không phụ thuộc Flutter. Để sử dụng trong ứng dụng Flutter, chúng ta cần các adapter package:

| Package | Mô tả | Lớp chính |
|---------|-------|-----------|
| `orchestrator_bloc` | Tích hợp với flutter_bloc | `OrchestratorCubit`, `OrchestratorBloc` |
| `orchestrator_provider` | Tích hợp với Provider | `OrchestratorNotifier` |
| `orchestrator_riverpod` | Tích hợp với Riverpod | `OrchestratorNotifier` |

Tất cả đều wrap logic của `BaseOrchestrator` và tích hợp với lifecycle tương ứng.

---

## 4.2. Tích hợp BLoC/Cubit

### Cài đặt

```yaml
dependencies:
  orchestrator_bloc:
    path: packages/orchestrator_bloc
```

### OrchestratorCubit

`OrchestratorCubit<S>` kế thừa từ `Cubit<S>`, bổ sung khả năng dispatch Job và lắng nghe Event.

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

  // Hooks cho lớp con
  void onActiveSuccess(JobSuccessEvent event) {}
  void onActiveFailure(JobFailureEvent event) {}
  void onPassiveEvent(BaseEvent event) {}
}
```

### Sử dụng

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

## 4.3. Tích hợp Provider

### Cài đặt

```yaml
dependencies:
  orchestrator_provider:
    path: packages/orchestrator_provider
```

### OrchestratorNotifier

`OrchestratorNotifier<S>` kế thừa từ `ChangeNotifier`, tự động gọi `notifyListeners()` khi state thay đổi.

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

### Sử dụng

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

## 4.4. Tích hợp Riverpod

### Cài đặt

```yaml
dependencies:
  orchestrator_riverpod:
    path: packages/orchestrator_riverpod
```

### OrchestratorNotifier

`OrchestratorNotifier<S>` kế thừa từ Riverpod `Notifier<S>`, tích hợp với hệ thống Provider của Riverpod.

```dart
abstract class OrchestratorNotifier<S> extends Notifier<S> {
  final SignalBus _bus = SignalBus();
  final Dispatcher _dispatcher = Dispatcher();
  final Set<String> _activeJobIds = {};

  @override
  S build(); // Override để cung cấp initial state

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

### Sử dụng

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

### Sử dụng trong Widget

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

## 4.5. So sánh và Lựa chọn

| Tiêu chí | BLoC/Cubit | Provider | Riverpod |
|----------|------------|----------|----------|
| **Ecosystem** | flutter_bloc | provider | riverpod |
| **Boilerplate** | Trung bình | Thấp | Thấp |
| **Type Safety** | Tốt | Trung bình | Xuất sắc |
| **Testing** | bloc_test | flutter_test | riverpod test utilities |
| **Compile-time Safety** | Không | Không | Có |

**Khuyến nghị**:
- **BLoC**: Dự án lớn, cần strict pattern.
- **Provider**: Dự án nhỏ, team mới làm quen.
- **Riverpod**: Dự án cần type safety và compile-time checking.

---

## 4.6. Tổng kết

Tất cả các package đều cung cấp:
- **Dispatch**: Gửi Job và theo dõi bằng Correlation ID
- **Active/Passive Routing**: Phân loại sự kiện tự động
- **Lifecycle Integration**: Tự động cleanup khi dispose

Chương tiếp theo sẽ trình bày các kỹ thuật nâng cao như Cancellation, Timeout và Retry.
