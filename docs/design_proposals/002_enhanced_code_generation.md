# RFC 002: Enhanced Code Generation

> **Status:** Draft  
> **Author:** Flutter Orchestrator Team  
> **Created:** 2024-12-26

## 1. Tóm tắt

Đề xuất mở rộng hệ thống code generation hiện tại để giảm boilerplate khi làm việc với `NetworkAction` jobs và tự động đăng ký Executors.

## 2. Vấn đề hiện tại

### 2.1. NetworkAction có quá nhiều boilerplate

Hiện tại, để tạo một NetworkAction job, developer phải viết:

```dart
@NetworkJob()
class SendMessageJob extends BaseJob implements NetworkAction<Message> {
  final String content;
  final String recipientId;
  
  SendMessageJob({required this.content, required this.recipientId})
    : super(id: generateJobId('msg'));
  
  // 1. toJson() - BẮT BUỘC
  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'content': content,
    'recipientId': recipientId,
  };
  
  // 2. fromJson() factory - BẮT BUỘC
  factory SendMessageJob.fromJson(Map<String, dynamic> json) {
    return SendMessageJob._withId(
      id: json['id'] as String,
      content: json['content'] as String,
      recipientId: json['recipientId'] as String,
    );
  }
  
  // 3. Private constructor - CẦN THÊM
  SendMessageJob._withId({required String id, required this.content, required this.recipientId})
    : super(id: id);
  
  // 4. fromJsonToBase wrapper - DỄ QUÊN!
  static BaseJob fromJsonToBase(Map<String, dynamic> json) {
    return SendMessageJob.fromJson(json);
  }
  
  // 5. createOptimisticResult() - Logic thực sự
  @override
  Message createOptimisticResult() => Message(...);
}
```

**Vấn đề:**
- Quá nhiều code lặp lại
- `fromJsonToBase` dễ quên
- Dễ sai khi serialize/deserialize fields

### 2.2. Không có auto-registration cho Executor

```dart
// Developer phải đăng ký thủ công mỗi Job → Executor
void main() {
  Dispatcher().register<FetchUserJob>(FetchUserExecutor(api));
  Dispatcher().register<LoginJob>(LoginExecutor(api));
  Dispatcher().register<LogoutJob>(LogoutExecutor(api));
  // ... 50+ jobs → Rất dễ quên
}
```

## 3. Giải pháp đề xuất

### 3.1. `@NetworkJob()` sinh toJson/fromJson tự động

**Annotation mới:**

```dart
@NetworkJob(generateSerialization: true)  // Default: true
class SendMessageJob extends BaseJob implements NetworkAction<Message> {
  final String content;
  final String recipientId;
  
  SendMessageJob({required this.content, required this.recipientId});
  
  // CHỈ CẦN VIẾT CÁI NÀY
  @override
  Message createOptimisticResult() => Message(
    id: id,
    content: content,
    status: MessageStatus.sending,
  );
}

// GENERATED: send_message_job.g.dart
part of 'send_message_job.dart';

extension _$SendMessageJobSerialization on SendMessageJob {
  Map<String, dynamic> toJson() => {
    'id': id,
    'content': content,
    'recipientId': recipientId,
  };
  
  static SendMessageJob fromJson(Map<String, dynamic> json) => SendMessageJob._restore(
    id: json['id'] as String,
    content: json['content'] as String,
    recipientId: json['recipientId'] as String,
  );
  
  static BaseJob fromJsonToBase(Map<String, dynamic> json) => fromJson(json);
}
```

### 3.2. `@ExecutorRegistry` cho auto-registration

**Annotation mới:**

```dart
// lib/executor_config.dart
part 'executor_config.g.dart';

@ExecutorRegistry([
  (FetchUserJob, FetchUserExecutor),
  (LoginJob, LoginExecutor),
  (LogoutJob, LogoutExecutor),
])
void setupExecutors(ApiService api) {}
```

**Generated code:**

```dart
// executor_config.g.dart
void registerExecutors(ApiService api) {
  final dispatcher = Dispatcher();
  dispatcher.register<FetchUserJob>(FetchUserExecutor(api));
  dispatcher.register<LoginJob>(LoginExecutor(api));
  dispatcher.register<LogoutJob>(LogoutExecutor(api));
}
```

### 3.3. Field-level annotations

```dart
@NetworkJob()
class UploadPhotoJob extends BaseJob implements NetworkAction<Photo> {
  @JsonKey(name: 'photo_path')
  final String photoPath;
  
  @JsonIgnore()  // Không serialize field này
  final File? cachedFile;
  
  @JsonKey(defaultValue: 'unknown')
  final String source;
}
```

## 4. API Design

### 4.1. Annotations

| Annotation | Vị trí | Mô tả |
|------------|--------|-------|
| `@NetworkJob()` | Class | Đánh dấu NetworkAction job |
| `@NetworkJob(generateSerialization: true)` | Class | Tự sinh toJson/fromJson |
| `@ExecutorRegistry([...])` | Function | Đăng ký Executor mappings |
| `@JsonKey(name: 'x')` | Field | Tên khác trong JSON |
| `@JsonIgnore()` | Field | Bỏ qua khi serialize |

### 4.2. Generated code patterns

```
lib/
├── jobs/
│   ├── send_message_job.dart
│   └── send_message_job.g.dart  ← GENERATED
├── executor_config.dart
└── executor_config.g.dart       ← GENERATED
```

## 5. Migration Path

### Phase 1: Backward Compatible
- `@NetworkJob()` mặc định KHÔNG sinh code (giữ behavior hiện tại)
- Developer opt-in: `@NetworkJob(generateSerialization: true)`

### Phase 2: Default On
- Sau 1-2 minor versions, đổi default thành `true`
- Deprecation warning cho manual toJson/fromJson

## 6. Triển khai

### 6.1. Package changes

| Package | Thay đổi |
|---------|----------|
| `orchestrator_core` | Thêm annotations mới |
| `orchestrator_generator` | Thêm generators mới |

### 6.2. Generator implementation

```dart
class NetworkJobGenerator extends GeneratorForAnnotation<NetworkJob> {
  @override
  String generateForAnnotatedElement(Element element, ...) {
    final classElement = element as ClassElement;
    
    // 1. Extract fields
    final fields = classElement.fields.where((f) => !f.isStatic);
    
    // 2. Generate toJson
    final toJsonCode = _generateToJson(fields);
    
    // 3. Generate fromJson
    final fromJsonCode = _generateFromJson(classElement, fields);
    
    // 4. Generate fromJsonToBase wrapper
    final wrapperCode = _generateWrapper(classElement);
    
    return '''
extension _\$${classElement.name}Serialization on ${classElement.name} {
  $toJsonCode
  $fromJsonCode
  $wrapperCode
}
''';
  }
}
```

## 7. Alternatives Considered

### 7.1. Dùng json_serializable
- **Pros:** Mature, well-tested
- **Cons:** Không hiểu context của Orchestrator, thiếu `fromJsonToBase`

### 7.2. Macro (Dart 3.x)
- **Pros:** Không cần build_runner, compile-time
- **Cons:** Chưa stable, experimental

## 8. Timeline

| Milestone | Target |
|-----------|--------|
| RFC Approval | Week 1 |
| Implement `@NetworkJob` serialization | Week 2-3 |
| Implement `@ExecutorRegistry` | Week 4 |
| Documentation & Testing | Week 5 |
| Release v1.1.0 | Week 6 |

## 9. Open Questions

1. Nên dùng extension hay inject trực tiếp vào class?
2. Có cần hỗ trợ nested objects (List, Map của custom types)?
3. Có cần compatibility với `json_serializable`?
