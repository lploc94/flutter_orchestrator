# Chương 3: Xây dựng Core Framework

Chương này hướng dẫn xây dựng package `orchestrator_core` - nền tảng kỹ thuật của toàn bộ kiến trúc. Mục tiêu là tạo ra một framework nhẹ, hiệu năng cao và độc lập với Flutter (Pure Dart).

> **Ghi chú**: Toàn bộ mã nguồn trong chương này đã được kiểm thử và xác nhận hoạt động chính xác.

---

## 3.1. Mô hình Dữ liệu Cơ bản

### BaseJob

Lớp cơ sở cho tất cả các yêu cầu công việc trong hệ thống. Thuộc tính `id` đóng vai trò Correlation ID để định danh giao dịch.

```dart
// lib/src/models/job.dart
import 'package:meta/meta.dart';

@immutable
abstract class BaseJob {
  /// Định danh duy nhất cho giao dịch (Correlation ID)
  final String id;

  /// Metadata tùy chọn
  final Map<String, dynamic>? metadata;

  const BaseJob({required this.id, this.metadata});
  
  @override
  String toString() => '$runtimeType(id: $id)';
}

/// Hàm tiện ích tạo ID duy nhất
String generateJobId([String? prefix]) {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final random = timestamp.hashCode.abs() % 10000;
  return '${prefix ?? 'job'}-$timestamp-$random';
}
```

### BaseEvent

Lớp cơ sở cho tất cả các sự kiện phát ra từ Executor. Thuộc tính `correlationId` cho phép Orchestrator xác định nguồn gốc của sự kiện.

```dart
// lib/src/models/event.dart
@immutable
abstract class BaseEvent {
  /// ID của Job sinh ra sự kiện này
  final String correlationId;
  final DateTime timestamp;

  BaseEvent(this.correlationId) : timestamp = DateTime.now();
}

/// Sự kiện khi Job hoàn thành thành công
class JobSuccessEvent<T> extends BaseEvent {
  final T data;
  JobSuccessEvent(super.correlationId, this.data);
}

/// Sự kiện khi Job gặp lỗi
class JobFailureEvent extends BaseEvent {
  final Object error;
  final StackTrace? stackTrace;
  JobFailureEvent(super.correlationId, this.error, [this.stackTrace]);
}
```

---

## 3.2. Hạ tầng Giao tiếp

### Signal Bus

Kênh truyền tín hiệu trung tâm sử dụng `StreamController.broadcast()` của Dart. Thiết kế Singleton đảm bảo toàn ứng dụng chỉ có một điểm phát sóng duy nhất.

```dart
// lib/src/infra/signal_bus.dart
import 'dart:async';

class SignalBus {
  static final SignalBus _instance = SignalBus._internal();
  factory SignalBus() => _instance;
  SignalBus._internal();

  final _controller = StreamController<BaseEvent>.broadcast();

  /// Stream cho phép nhiều Orchestrator đồng thời lắng nghe
  Stream<BaseEvent> get stream => _controller.stream;

  /// Phát sự kiện lên Bus
  void emit(BaseEvent event) {
    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }

  void dispose() => _controller.close();
}
```

### Dispatcher

Bộ định tuyến sử dụng Registry Pattern để ánh xạ loại Job với Executor tương ứng. Độ phức tạp tra cứu O(1).

```dart
// lib/src/infra/dispatcher.dart
class ExecutorNotFoundException implements Exception {
  final Type jobType;
  ExecutorNotFoundException(this.jobType);
  @override
  String toString() => 'Không tìm thấy Executor cho loại $jobType';
}

class Dispatcher {
  final Map<Type, BaseExecutor> _registry = {};
  
  static final Dispatcher _instance = Dispatcher._internal();
  factory Dispatcher() => _instance;
  Dispatcher._internal();

  /// Đăng ký Executor cho một loại Job cụ thể
  void register<J extends BaseJob>(BaseExecutor<J> executor) {
    _registry[J] = executor;
  }

  /// Định tuyến Job đến Executor phù hợp
  String dispatch(BaseJob job) {
    final executor = _registry[job.runtimeType];
    if (executor == null) {
      throw ExecutorNotFoundException(job.runtimeType);
    }
    
    executor.execute(job);
    return job.id;
  }
  
  void clear() => _registry.clear();
}
```

---

## 3.3. Bộ Thực thi (BaseExecutor)

Lớp trừu tượng định nghĩa giao diện cho tất cả các Worker. Tích hợp sẵn Error Boundary để đảm bảo mọi exception đều được xử lý và chuyển thành sự kiện lỗi.

```dart
// lib/src/base/base_executor.dart
abstract class BaseExecutor<T extends BaseJob> {
  final SignalBus _bus = SignalBus();

  /// Phương thức trừu tượng - lớp con triển khai logic nghiệp vụ
  Future<dynamic> process(T job);

  /// Điểm vào được gọi bởi Dispatcher
  Future<void> execute(T job) async {
    try {
      final result = await process(job);
      emitResult(job.id, result);
    } catch (e, stack) {
      emitFailure(job.id, e, stack);
    }
  }

  /// Phát sự kiện thành công
  void emitResult<R>(String correlationId, R data) {
    _bus.emit(JobSuccessEvent<R>(correlationId, data));
  }

  /// Phát sự kiện lỗi
  void emitFailure(String correlationId, Object error, [StackTrace? stack]) {
    _bus.emit(JobFailureEvent(correlationId, error, stack));
  }
}
```

---

## 3.4. Bộ Điều phối (BaseOrchestrator)

Lớp trừu tượng triển khai cơ chế State Machine với khả năng phân loại sự kiện tự động.

```mermaid
flowchart LR
    subgraph SignalBus
        Event[Event arrives]
    end
    
    Event --> Check{correlationId<br/>trong activeJobIds?}
    Check --> |CÓ| Active["Direct Mode<br/>onActiveSuccess/Failure"]
    Check --> |KHÔNG| Passive["Observer Mode<br/>onPassiveEvent"]
    
    Active --> UpdateState[Update State]
    Passive --> UpdateState
```

```dart
// lib/src/base/base_orchestrator.dart
abstract class BaseOrchestrator<S> {
  S _state;
  final StreamController<S> _stateController = StreamController<S>.broadcast();
  final SignalBus _bus = SignalBus();
  final Dispatcher _dispatcher = Dispatcher();
  
  /// Tập hợp các Job đang được theo dõi
  final Set<String> _activeJobIds = {};
  
  StreamSubscription? _busSubscription;

  BaseOrchestrator(this._state) {
    _stateController.add(_state);
    _subscribeToBus();
  }

  S get state => _state;
  Stream<S> get stream => _stateController.stream;
  bool get hasActiveJobs => _activeJobIds.isNotEmpty;

  @protected
  void emit(S newState) {
    if (_stateController.isClosed) return;
    _state = newState;
    _stateController.add(newState);
  }

  @protected
  String dispatch(BaseJob job) {
    final id = _dispatcher.dispatch(job);
    _activeJobIds.add(id);
    return id;
  }

  void _subscribeToBus() {
    _busSubscription = _bus.stream.listen(_routeEvent);
  }

  void _routeEvent(BaseEvent event) {
    final isActive = _activeJobIds.contains(event.correlationId);
    
    if (isActive) {
      if (event is JobSuccessEvent) onActiveSuccess(event);
      else if (event is JobFailureEvent) onActiveFailure(event);
      _activeJobIds.remove(event.correlationId);
    } else {
      onPassiveEvent(event);
    }
  }

  @protected void onActiveSuccess(JobSuccessEvent event) {}
  @protected void onActiveFailure(JobFailureEvent event) {}
  @protected void onPassiveEvent(BaseEvent event) {}

  @mustCallSuper
  void dispose() {
    _busSubscription?.cancel();
    _stateController.close();
    _activeJobIds.clear();
  }
}
```

---

## 3.5. Tổng kết

Với khoảng 200 dòng mã nguồn lõi, chúng ta đã xây dựng được một framework hoàn chỉnh:

- **Tính tách biệt**: Executor và Orchestrator hoạt động độc lập.
- **Tính phản ứng**: Orchestrator tự động xử lý sự kiện đến.
- **Hiệu năng cao**: Sử dụng Broadcast Stream và tra cứu O(1).

Các tính năng nâng cao như Cancellation, Timeout, Retry sẽ được trình bày trong **Chương 5**.
