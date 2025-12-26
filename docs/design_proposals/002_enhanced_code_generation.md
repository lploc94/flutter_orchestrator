# RFC 002: Enhanced Code Generation

> **Status:** Approved (Phase 1 Implemented)  
> **Author:** Flutter Orchestrator Team  
> **Created:** 2024-12-26  
> **Updated:** 2024-12-26

## 1. Summary

Extend the code generation system to reduce boilerplate across the entire Orchestrator ecosystem, including Jobs, Events, States, Orchestrators, and Executor registration.

## 2. Current Problems

### 2.1. NetworkAction Boilerplate
Creating a `NetworkAction` job requires ~50 lines of repetitive code for serialization.

### 2.2. Manual Executor Registration
Each Job→Executor mapping must be registered manually, leading to forgotten registrations.

### 2.3. Event Declaration Boilerplate
Every custom Event requires extending `BaseEvent` and calling `super(correlationId)`.

### 2.4. State Class Boilerplate
State classes need manual `copyWith`, pattern matching methods (`when`, `maybeWhen`).

### 2.5. Job Constructor Boilerplate
`BaseJob` has many optional fields (timeout, retryPolicy, strategy) requiring verbose constructors.

### 2.6. Duplicate Hook Logic
`BaseOrchestrator` and `OrchestratorCubit` share ~70% identical event routing code.

## 3. Proposed Annotations

### 3.1. `@NetworkJob` - Auto-generate Serialization (✅ IMPLEMENTED)

```dart
@NetworkJob(generateSerialization: true)
class SendMessageJob extends BaseJob implements NetworkAction<Message> {
  final String content;
  
  @JsonKey(name: 'recipient_id')
  final String recipientId;
  
  @JsonIgnore()
  final File? cachedFile;
  
  @override
  Message createOptimisticResult() => Message(content: content);
}
```

**Generated:** `toJson()`, `fromJson()`, `fromJsonToBase()`

---

### 3.2. `@ExecutorRegistry` - Auto-register Executors (✅ IMPLEMENTED)

```dart
@ExecutorRegistry([
  (FetchUserJob, FetchUserExecutor),
  (LoginJob, LoginExecutor),
])
void setupExecutors(ApiService api) {}
```

**Generated:** `registerExecutors(api)` function

---

### 3.3. `@OnEvent` - Declarative Event Routing (🔲 PROPOSED)

**Problem:** Manual type checking in event handlers.
```dart
// BEFORE: Verbose
@override
void onPassiveEvent(BaseEvent event) {
  if (event is UserLoggedInEvent) {
    _handleLogin(event);
  } else if (event is UserLoggedOutEvent) {
    _handleLogout(event);
  }
}
```

**Solution:**
```dart
// AFTER: Declarative
@Orchestrator()
class AuthOrchestrator extends BaseOrchestrator<AuthState> {
  @OnEvent(UserLoggedInEvent)
  void _handleLogin(UserLoggedInEvent event) {
    emit(state.copyWith(user: event.user));
  }
  
  @OnEvent(UserLoggedOutEvent, passive: true)
  void _handleLogout(UserLoggedOutEvent event) {
    emit(state.copyWith(user: null));
  }
}
```

**Generated:** Override `onPassiveEvent` with type-safe routing.

---

### 3.4. `@AsyncState` - Auto-generate State Patterns (🔲 PROPOSED)

**Problem:** Manually writing `copyWith`, `when`, `maybeWhen` for every state.

```dart
@AsyncState()
class UserState {
  final User? user;
  final List<Permission> permissions;
  final String? errorMessage;
}
```

**Generated:**
```dart
extension _$UserStateCopyWith on UserState {
  UserState copyWith({User? user, List<Permission>? permissions, String? errorMessage}) => ...
  
  UserState toLoading() => ...
  UserState toSuccess(User user) => ...
  UserState toFailure(String error) => ...
  
  R when<R>({
    required R Function() initial,
    required R Function() loading,
    required R Function(User user) success,
    required R Function(String error) failure,
  }) => ...
}
```

---

### 3.5. `@Job` - Simplified Job Declaration (🔲 PROPOSED)

**Problem:** Verbose constructor with many optional `BaseJob` parameters.

```dart
@Job(timeout: Duration(seconds: 30), maxRetries: 3)
class FetchUserJob {
  final String userId;
  FetchUserJob(this.userId);
}
```

**Generated:**
```dart
class FetchUserJob extends BaseJob {
  final String userId;
  
  FetchUserJob(this.userId, {String? id})
    : super(
        id: id ?? generateJobId('fetch_user'),
        timeout: Duration(seconds: 30),
        retryPolicy: RetryPolicy(maxRetries: 3),
      );
}
```

---

### 3.6. `@Event` - Simplified Event Declaration (🔲 PROPOSED)

**Problem:** Every event requires extending `BaseEvent` and constructor boilerplate.

```dart
@Event()
class OrderPlaced {
  final Order order;
  final DateTime timestamp;
}
```

**Generated:**
```dart
class OrderPlaced extends BaseEvent {
  final Order order;
  final DateTime timestamp;
  
  OrderPlaced(String correlationId, {required this.order, required this.timestamp})
    : super(correlationId);
}
```

---

## 4. Implementation Roadmap

| Phase | Annotation | Status | Priority |
|-------|------------|--------|----------|
| 1 | `@NetworkJob` | ✅ Done | Critical |
| 1 | `@ExecutorRegistry` | ✅ Done | Critical |
| 2 | `@OnEvent` | 🔲 Planned | High |
| 2 | `@AsyncState` | 🔲 Planned | High |
| 3 | `@Job` | 🔲 Planned | Medium |
| 3 | `@Event` | 🔲 Planned | Medium |

## 5. Package Changes

| Package | Changes |
|---------|---------|
| `orchestrator_core` | Add annotations: `NetworkJob`, `ExecutorRegistry`, `JsonKey`, `JsonIgnore`, `OnEvent`, `AsyncState`, `Job`, `Event`, `Orchestrator` |
| `orchestrator_generator` | Add generators for each annotation |

## 6. Alternatives Considered

### 6.1. Use `json_serializable`
- **Pros:** Mature, well-tested
- **Cons:** Doesn't understand Orchestrator context, lacks `fromJsonToBase`

### 6.2. Use `freezed`
- **Pros:** Excellent for immutable data classes
- **Cons:** Doesn't handle Orchestrator-specific patterns (events, jobs)

### 6.3. Wait for Dart Macros
- **Pros:** No build_runner needed, compile-time
- **Cons:** Still experimental, not stable

## 7. Open Questions

1. Should `@OnEvent` support priority ordering?
2. Should `@AsyncState` generate equality (`==` and `hashCode`)?
3. Should we support nested object serialization in `@NetworkJob`?

## 8. References

- [RFC 001: Offline Support](./001_offline_support_design.md)
- [json_serializable](https://pub.dev/packages/json_serializable)
- [freezed](https://pub.dev/packages/freezed)
