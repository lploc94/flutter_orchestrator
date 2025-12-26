# Code Generation

Hướng dẫn sử dụng các annotation để sinh code tự động, giảm boilerplate và tăng tốc phát triển.

## Mục lục

1. [Tổng quan](#tổng-quan)
2. [Cài đặt](#cài-đặt)
3. [@NetworkJob - Serialization](#networkjob---serialization)
4. [@NetworkRegistry - Đăng ký Job Offline](#networkregistry---đăng-ký-job-offline)
5. [@ExecutorRegistry - Đăng ký Executor](#executorregistry---đăng-ký-executor)
6. [@Orchestrator & @OnEvent - Declarative Routing](#orchestrator--onevent---declarative-routing)
7. [@GenerateAsyncState - State Pattern](#generateasyncstate---state-pattern)
8. [@GenerateJob - Job Boilerplate](#generatejob---job-boilerplate)
9. [@GenerateEvent - Event Boilerplate](#generateevent---event-boilerplate)
10. [Chạy Code Generator](#chạy-code-generator)

---

## Tổng quan

`orchestrator_generator` cung cấp các annotation và generator để tự động sinh code, bao gồm:

| Annotation | Mục đích |
|------------|----------|
| `@NetworkJob` | Sinh `toJson`/`fromJson` cho Job hỗ trợ offline |
| `@NetworkRegistry` | Sinh hàm đăng ký tất cả NetworkJob |
| `@ExecutorRegistry` | Sinh hàm đăng ký Executor với Dispatcher |
| `@Orchestrator` + `@OnEvent` | Declarative event routing (thay vì if-else) |
| `@GenerateAsyncState` | Sinh `copyWith`, `toLoading`, `when`, `maybeWhen` |
| `@GenerateJob` | Sinh boilerplate cho Job (ID, timeout, retry) |
| `@GenerateEvent` | Sinh boilerplate cho Event |

---

## Cài đặt

```yaml
# pubspec.yaml
dependencies:
  orchestrator_core: ^0.3.0

dev_dependencies:
  orchestrator_generator: ^0.3.0
  build_runner: ^2.4.0
```

---

## @NetworkJob - Serialization

Tự động sinh `toJson()`, `fromJson()` và `fromJsonToBase()` cho Job cần hỗ trợ offline queue.

### Sử dụng

```dart
import 'package:orchestrator_core/orchestrator_core.dart';

part 'send_message_job.g.dart';

@NetworkJob(generateSerialization: true)
class SendMessageJob extends BaseJob implements NetworkAction {
  final String message;
  final int priority;
  
  @JsonKey(name: 'msg')  // Đổi tên field trong JSON
  final String content;
  
  @JsonIgnore()  // Bỏ qua field này khi serialize
  final DateTime localTimestamp;

  SendMessageJob({
    required this.message,
    required this.priority,
    required this.content,
    DateTime? localTimestamp,
  }) : localTimestamp = localTimestamp ?? DateTime.now(),
       super(id: generateJobId('send_msg'));

  // Pessimistic action cho offline sync
  @override
  String get deduplicationKey => 'send_msg_$message';
}
```

### Generated Code

```dart
// send_message_job.g.dart
extension _$SendMessageJobSerialization on SendMessageJob {
  Map<String, dynamic> toJson() => {
    'message': message,
    'priority': priority,
    'msg': content,  // Sử dụng JsonKey name
    // localTimestamp bị bỏ qua do @JsonIgnore
  };

  static SendMessageJob fromJson(Map<String, dynamic> json) => SendMessageJob(
    message: json['message'] as String,
    priority: json['priority'] as int,
    content: json['msg'] as String,
  );
}

BaseJob _$SendMessageJobFromJsonToBase(Map<String, dynamic> json) =>
    _$SendMessageJobSerialization.fromJson(json);
```

### Tùy chọn

| Tham số | Mặc định | Mô tả |
|---------|----------|-------|
| `generateSerialization` | `true` | Có sinh `toJson`/`fromJson` không |

---

## @NetworkRegistry - Đăng ký Job Offline

Sinh hàm `registerNetworkJobs()` để đăng ký tất cả NetworkJob với `NetworkJobRegistry`.

### Sử dụng

```dart
import 'package:orchestrator_core/orchestrator_core.dart';

part 'app_config.g.dart';

@NetworkRegistry([
  SendMessageJob,
  UploadFileJob,
  SyncDataJob,
])
class AppConfig {}
```

### Generated Code

```dart
// app_config.g.dart
/// Đăng ký tất cả NetworkJob.
/// Gọi hàm này trong main() trước khi xử lý offline queue.
void registerNetworkJobs() {
  NetworkJobRegistry.register('SendMessageJob', SendMessageJob.fromJson);
  NetworkJobRegistry.register('UploadFileJob', UploadFileJob.fromJson);
  NetworkJobRegistry.register('SyncDataJob', SyncDataJob.fromJson);
}
```

### Khởi tạo

```dart
void main() {
  registerNetworkJobs();  // Gọi trước runApp
  runApp(MyApp());
}
```

---

## @ExecutorRegistry - Đăng ký Executor

Sinh hàm `registerExecutors()` để tự động đăng ký Executor với Dispatcher.

### Sử dụng

```dart
import 'package:orchestrator_core/orchestrator_core.dart';

part 'executor_config.g.dart';

@ExecutorRegistry([
  (FetchUserJob, FetchUserExecutor),
  (SendMessageJob, SendMessageExecutor),
  (UploadFileJob, UploadFileExecutor),
])
class ExecutorConfig {}
```

### Generated Code

```dart
// executor_config.g.dart
void registerExecutors(Dispatcher dispatcher) {
  dispatcher.register<FetchUserJob>(FetchUserExecutor());
  dispatcher.register<SendMessageJob>(SendMessageExecutor());
  dispatcher.register<UploadFileJob>(UploadFileExecutor());
}
```

### Khởi tạo

```dart
void main() {
  final dispatcher = Dispatcher.instance;
  registerExecutors(dispatcher);
  runApp(MyApp());
}
```

---

## @Orchestrator & @OnEvent - Declarative Routing

Thay vì viết `if (event is UserLoggedIn) { ... }`, sử dụng annotation để khai báo handler.

### Trước đây (Manual)

```dart
class UserOrchestrator extends BaseOrchestrator<UserState> {
  @override
  void onActiveEvent(BaseEvent event) {
    if (event is UserLoggedIn) {
      _handleLogin(event);
    } else if (event is UserLoggedOut) {
      _handleLogout(event);
    } else if (event is DataRefreshed) {
      _handleDataRefresh(event);
    }
  }
}
```

### Bây giờ (Declarative)

```dart
import 'package:orchestrator_core/orchestrator_core.dart';

part 'user_orchestrator.g.dart';

@Orchestrator()
class UserOrchestrator extends BaseOrchestrator<UserState> 
    with _$UserOrchestratorEventRouting {
  
  UserOrchestrator() : super(const UserState());

  @OnEvent(UserLoggedIn)
  void _handleLogin(UserLoggedIn event) {
    emit(state.copyWith(user: event.user, isLoggedIn: true));
  }

  @OnEvent(UserLoggedOut)
  void _handleLogout(UserLoggedOut event) {
    emit(UserState());  // Reset state
  }

  @OnEvent(DataRefreshed, passive: true)  // Passive event từ orchestrator khác
  void _handleDataRefresh(DataRefreshed event) {
    emit(state.copyWith(lastRefresh: DateTime.now()));
  }
}
```

### Tùy chọn @OnEvent

| Tham số | Mặc định | Mô tả |
|---------|----------|-------|
| `passive` | `false` | `true` = event từ orchestrator khác |

### Generated Mixin

```dart
// user_orchestrator.g.dart
mixin _$UserOrchestratorEventRouting on BaseOrchestrator<UserState> {
  void _handleLogin(UserLoggedIn event);
  void _handleLogout(UserLoggedOut event);
  void _handleDataRefresh(DataRefreshed event);

  @override
  void onActiveEvent(BaseEvent event) {
    if (event is UserLoggedIn) { _handleLogin(event); return; }
    if (event is UserLoggedOut) { _handleLogout(event); return; }
    super.onActiveEvent(event);
  }

  @override
  void onPassiveEvent(BaseEvent event) {
    if (event is DataRefreshed) { _handleDataRefresh(event); return; }
    super.onPassiveEvent(event);
  }
}
```

---

## @GenerateAsyncState - State Pattern

Tự động sinh `copyWith`, state transitions (`toLoading`, `toSuccess`, `toFailure`), và pattern matching (`when`, `maybeWhen`).

### Sử dụng

```dart
import 'package:orchestrator_core/orchestrator_core.dart';

part 'user_state.g.dart';

@GenerateAsyncState()
class UserState {
  final AsyncStatus status;
  final User? data;
  final Object? error;
  final String? username;

  const UserState({
    this.status = AsyncStatus.initial,
    this.data,
    this.error,
    this.username,
  });
}
```

### Generated Methods

```dart
// user_state.g.dart
extension UserStateGenerated on UserState {
  // copyWith hỗ trợ đặt giá trị null tường minh
  UserState copyWith({
    Object? status = _sentinel,
    Object? data = _sentinel,
    Object? error = _sentinel,
    Object? username = _sentinel,
  }) { ... }

  // State transitions
  UserState toLoading() => copyWith(status: AsyncStatus.loading);
  UserState toRefreshing() => copyWith(status: AsyncStatus.refreshing);
  UserState toSuccess(User? data) => copyWith(status: AsyncStatus.success, data: data);
  UserState toFailure(Object error) => copyWith(status: AsyncStatus.failure, error: error);

  // Pattern matching
  R when<R>({
    required R Function() initial,
    required R Function() loading,
    required R Function(User? data) success,
    required R Function(Object error) failure,
    R Function(User? data)? refreshing,
  }) { ... }

  R maybeWhen<R>({
    R Function()? initial,
    R Function()? loading,
    R Function(User? data)? success,
    R Function(Object error)? failure,
    required R Function() orElse,
  }) { ... }
}
```

### Ví dụ sử dụng

```dart
// Trong Orchestrator
void onActiveSuccess(JobSuccessEvent event) {
  emit(state.toSuccess(event.data as User));
}

void onActiveFailure(JobFailureEvent event) {
  emit(state.toFailure(event.error));
}

// Trong Widget
Widget build(BuildContext context) {
  return state.when(
    initial: () => const SizedBox(),
    loading: () => const CircularProgressIndicator(),
    success: (user) => UserProfile(user: user!),
    failure: (error) => ErrorView(message: error.toString()),
  );
}
```

### Lưu ý: Reset về null

Do pattern sentinel, có thể đặt về null tường minh:

```dart
// Có thể reset username về null
emit(state.copyWith(username: null));  // ✅ Hoạt động đúng
```

---

## @GenerateJob - Job Boilerplate

Sinh boilerplate cho Job (ID tự động, cấu hình timeout/retry).

### Sử dụng

```dart
@GenerateJob(
  generateId: true,
  defaultTimeout: Duration(seconds: 30),
  defaultRetryCount: 3,
)
class FetchUserJob extends BaseJob {
  final String userId;
  
  FetchUserJob(this.userId);
}
```

> **Lưu ý**: Feature này đang trong giai đoạn phát triển. Hiện tại sinh mixin cơ bản.

---

## @GenerateEvent - Event Boilerplate

Sinh boilerplate cho Event class.

### Sử dụng

```dart
@GenerateEvent()
class UserLoggedIn extends BaseEvent {
  final String username;
  
  UserLoggedIn(this.username);
}
```

> **Lưu ý**: Feature này đang trong giai đoạn phát triển. Hiện tại sinh mixin cơ bản.

---

## Chạy Code Generator

### Build một lần

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Watch mode (tự động rebuild)

```bash
flutter pub run build_runner watch --delete-conflicting-outputs
```

### Clean và rebuild

```bash
flutter pub run build_runner clean
flutter pub run build_runner build --delete-conflicting-outputs
```

---

## Troubleshooting

### Lỗi "part of" không tìm thấy

Đảm bảo khai báo `part` directive đúng:

```dart
part 'my_file.g.dart';  // Phải match tên file
```

### Lỗi "No generator" 

Kiểm tra `build.yaml` của `orchestrator_generator` đã được include trong project.

### copyWith không reset về null

Đảm bảo bạn đang sử dụng `@GenerateAsyncState` (v0.3.0+). Các phiên bản cũ dùng pattern `??` không hỗ trợ null tường minh.

---

## Tham khảo

- [RFC 002: Enhanced Code Generation](../../design_proposals/002_enhanced_code_generation.md)
- [Offline Support Guide](./offline_support.md)
- [Testing Guide](./testing.md)
