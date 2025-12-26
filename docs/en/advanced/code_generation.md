# Code Generation

Guide to using annotations for automatic code generation, reducing boilerplate and speeding up development.

## Table of Contents

1. [Overview](#1-overview)
2. [Installation](#2-installation)
3. [@NetworkJob - Serialization](#3-networkjob---serialization)
4. [@NetworkRegistry - Network Job Registration](#4-networkregistry---network-job-registration)
5. [@ExecutorRegistry - Executor Registration](#5-executorregistry---executor-registration)
6. [@Orchestrator & @OnEvent - Declarative Routing](#6-orchestrator--onevent---declarative-routing)
7. [@GenerateAsyncState - State Pattern](#7-generateasyncstate---state-pattern)
8. [@GenerateJob - Job Boilerplate](#8-generatejob---job-boilerplate)
9. [@GenerateEvent - Event Boilerplate](#9-generateevent---event-boilerplate)
10. [Running Code Generator](#10-running-code-generator)

---

## 1. Overview

`orchestrator_generator` provides annotations and generators to automate code creation:

| Annotation | Purpose |
|------------|---------|
| `@NetworkJob` | Generate `toJson`/`fromJson` for offline-capable Jobs |
| `@NetworkRegistry` | Generate registration function for all NetworkJobs |
| `@ExecutorRegistry` | Generate Executor registration function for Dispatcher |
| `@Orchestrator` + `@OnEvent` | Declarative event routing (instead of if-else) |
| `@GenerateAsyncState` | Generate `copyWith`, `toLoading`, `when`, `maybeWhen` |
| `@GenerateJob` | Generate Job boilerplate (ID, timeout, retry) |
| `@GenerateEvent` | Generate Event boilerplate |

---

## 2. Installation

```yaml
# pubspec.yaml
dependencies:
  orchestrator_core: ^0.3.0

dev_dependencies:
  orchestrator_generator: ^0.3.0
  build_runner: ^2.4.0
```

---

## 3. @NetworkJob - Serialization

Automatically generates `toJson()`, `fromJson()`, and `fromJsonToBase()` for Jobs requiring offline queue support.

### Usage

```dart
import 'package:orchestrator_core/orchestrator_core.dart';

part 'send_message_job.g.dart';

@NetworkJob(generateSerialization: true)
class SendMessageJob extends BaseJob implements NetworkAction {
  final String message;
  final int priority;
  
  @JsonKey(name: 'msg')  // Rename field in JSON
  final String content;
  
  @JsonIgnore()  // Ignore this field during serialization
  final DateTime localTimestamp;

  SendMessageJob({
    required this.message,
    required this.priority,
    required this.content,
    DateTime? localTimestamp,
  }) : localTimestamp = localTimestamp ?? DateTime.now(),
       super(id: generateJobId('send_msg'));

  // Pessimistic action for offline sync
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
    'msg': content,  // Use JsonKey name
    // localTimestamp ignored due to @JsonIgnore
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

### Options

| Parameter | Default | Description |
|-----------|---------|-------------|
| `generateSerialization` | `true` | Whether to generate `toJson`/`fromJson` |

---

## 4. @NetworkRegistry - Network Job Registration

Generates `registerNetworkJobs()` to register all NetworkJobs with `NetworkJobRegistry`.

### Usage

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
/// Registers all NetworkJobs.
/// Call this in main() before handling offline queue.
void registerNetworkJobs() {
  NetworkJobRegistry.register('SendMessageJob', SendMessageJob.fromJson);
  NetworkJobRegistry.register('UploadFileJob', UploadFileJob.fromJson);
  NetworkJobRegistry.register('SyncDataJob', SyncDataJob.fromJson);
}
```

### Initialization

```dart
void main() {
  registerNetworkJobs();  // Call before runApp
  runApp(MyApp());
}
```

---

## 5. @ExecutorRegistry - Executor Registration

Generates `registerExecutors()` to automatically register Executors with Dispatcher.

### Usage

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

### Initialization

```dart
void main() {
  final dispatcher = Dispatcher.instance;
  registerExecutors(dispatcher);
  runApp(MyApp());
}
```

---

## 6. @Orchestrator & @OnEvent - Declarative Routing

Instead of writing `if (event is UserLoggedIn) { ... }`, use annotations to declare handlers.

### Before (Manual)

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

### Now (Declarative)

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

  @OnEvent(DataRefreshed, passive: true)  // Passive event from another orchestrator
  void _handleDataRefresh(DataRefreshed event) {
    emit(state.copyWith(lastRefresh: DateTime.now()));
  }
}
```

### Options @OnEvent

| Parameter | Default | Description |
|-----------|---------|-------------|
| `passive` | `false` | `true` = event from other orchestrator |

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

## 7. @GenerateAsyncState - State Pattern

Automatically generates `copyWith`, state transitions (`toLoading`, `toSuccess`, `toFailure`), and pattern matching (`when`, `maybeWhen`).

### Usage

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
  // copyWith supports explicit null assignment
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

### Usage Example

```dart
// In Orchestrator
void onActiveSuccess(JobSuccessEvent event) {
  emit(state.toSuccess(event.data as User));
}

void onActiveFailure(JobFailureEvent event) {
  emit(state.toFailure(event.error));
}

// In Widget
Widget build(BuildContext context) {
  return state.when(
    initial: () => const SizedBox(),
    loading: () => const CircularProgressIndicator(),
    success: (user) => UserProfile(user: user!),
    failure: (error) => ErrorView(message: error.toString()),
  );
}
```

### Note: Reset to null

Due to sentinel pattern, you can explicitly set to null:

```dart
// Reset username to null
emit(state.copyWith(username: null));  // ✅ Works correctly
```

---

## 8. @GenerateJob - Job Boilerplate

Generates boilerplate for Job (Auto ID, timeout/retry config).

### Usage

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

---

## 9. @GenerateEvent - Event Boilerplate

Generates boilerplate for Event class.

### Usage

```dart
@GenerateEvent()
class UserLoggedIn extends BaseEvent {
  final String username;
  
  UserLoggedIn(this.username);
}
```

---

## 10. Running Code Generator

### Build once

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Watch mode (auto-rebuild)

```bash
flutter pub run build_runner watch --delete-conflicting-outputs
```

### Clean and rebuild

```bash
flutter pub run build_runner clean
flutter pub run build_runner build --delete-conflicting-outputs
```

---

## Troubleshooting

### "part of" not found error

Ensure `part` directive is correct:

```dart
part 'my_file.g.dart';  // Must match file name
```

### "No generator" error

Check if `build.yaml` of `orchestrator_generator` is included in project.

### copyWith not resetting to null

Ensure you are using `@GenerateAsyncState` (v0.3.0+). Older versions using `??` pattern do not support explicit null.

---

## See Also

- [Offline Support Guide](./offline_support.md)
- [Testing Guide](./testing.md)
