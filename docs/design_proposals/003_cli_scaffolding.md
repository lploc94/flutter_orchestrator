# RFC 003: CLI Scaffolding Tool

> **Status:** Draft  
> **Author:** Flutter Orchestrator Team  
> **Created:** 2024-12-26

## 1. Tóm tắt

Đề xuất tạo CLI tool để scaffold các components của Flutter Orchestrator (Job, Executor, Orchestrator, Feature) với template code sẵn.

## 2. Vấn đề hiện tại

### 2.1. Không có template sẵn
- Developer phải nhớ cấu trúc của Job, Executor, Orchestrator
- Copy-paste từ docs → Dễ sai, tốn thời gian
- Inconsistent naming conventions

### 2.2. Setup ban đầu phức tạp
- Phải tạo nhiều files thủ công
- Import paths dễ sai
- Quên đăng ký vào Dispatcher/Registry

## 3. Giải pháp đề xuất

### 3.1. Package `orchestrator_cli`

```bash
# Cài đặt
dart pub global activate orchestrator_cli

# Hoặc chạy trực tiếp
dart run orchestrator_cli:create ...
```

### 3.2. Commands

#### 3.2.1. `create job`

```bash
# Basic job
orchestrator create job FetchUser

# Network job (với offline support)
orchestrator create job SendMessage --type network

# Job với cache
orchestrator create job GetProducts --cache
```

**Output: `lib/jobs/fetch_user_job.dart`**

```dart
import 'package:orchestrator_core/orchestrator_core.dart';

class FetchUserJob extends BaseJob {
  final String userId;
  
  FetchUserJob({required this.userId})
    : super(id: generateJobId('fetch_user'));
  
  // TODO: Add more fields as needed
}
```

**Output (Network): `lib/jobs/send_message_job.dart`**

```dart
import 'package:orchestrator_core/orchestrator_core.dart';

@NetworkJob()
class SendMessageJob extends BaseJob implements NetworkAction<Message> {
  final String content;
  
  SendMessageJob({required this.content})
    : super(id: generateJobId('send_message'));
  
  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'content': content,
  };
  
  factory SendMessageJob.fromJson(Map<String, dynamic> json) {
    return SendMessageJob._restore(
      id: json['id'] as String,
      content: json['content'] as String,
    );
  }
  
  SendMessageJob._restore({required String id, required this.content})
    : super(id: id);
  
  static BaseJob fromJsonToBase(Map<String, dynamic> json) => 
    SendMessageJob.fromJson(json);
  
  @override
  Message createOptimisticResult() {
    // TODO: Return optimistic result
    throw UnimplementedError();
  }
}
```

#### 3.2.2. `create executor`

```bash
# Tạo executor cho job đã có
orchestrator create executor --for FetchUserJob

# Với service injection
orchestrator create executor --for FetchUserJob --inject ApiService
```

**Output: `lib/executors/fetch_user_executor.dart`**

```dart
import 'package:orchestrator_core/orchestrator_core.dart';
import '../jobs/fetch_user_job.dart';

class FetchUserExecutor extends BaseExecutor<FetchUserJob> {
  final ApiService _api;
  
  FetchUserExecutor(this._api);
  
  @override
  Future<User> process(FetchUserJob job) async {
    // TODO: Implement business logic
    job.cancellationToken?.throwIfCancelled();
    
    return await _api.getUser(job.userId);
  }
}
```

#### 3.2.3. `create orchestrator`

```bash
# Bloc integration (default)
orchestrator create orchestrator User --integration bloc

# Provider integration
orchestrator create orchestrator User --integration provider

# Riverpod integration
orchestrator create orchestrator User --integration riverpod
```

**Output (Bloc): `lib/cubits/user_cubit.dart`**

```dart
import 'package:orchestrator_bloc/orchestrator_bloc.dart';
import 'user_state.dart';
import '../jobs/fetch_user_job.dart';

class UserCubit extends OrchestratorCubit<UserState> {
  UserCubit() : super(const UserState());
  
  void loadUser(String userId) {
    emit(state.copyWith(isLoading: true, error: null));
    dispatch(FetchUserJob(userId: userId));
  }
  
  @override
  void onActiveSuccess(JobSuccessEvent event) {
    final user = event.dataAs<User>();
    emit(state.copyWith(user: user, isLoading: false));
  }
  
  @override
  void onActiveFailure(JobFailureEvent event) {
    emit(state.copyWith(
      isLoading: false,
      error: event.error.toString(),
    ));
  }
}
```

**Output: `lib/cubits/user_state.dart`**

```dart
class UserState {
  final User? user;
  final bool isLoading;
  final String? error;
  
  const UserState({
    this.user,
    this.isLoading = false,
    this.error,
  });
  
  UserState copyWith({
    User? user,
    bool? isLoading,
    String? error,
  }) {
    return UserState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}
```

#### 3.2.4. `create feature` (Full scaffold)

```bash
orchestrator create feature authentication --integration bloc
```

**Output structure:**

```
lib/features/authentication/
├── jobs/
│   ├── login_job.dart
│   └── logout_job.dart
├── executors/
│   ├── login_executor.dart
│   └── logout_executor.dart
├── cubit/
│   ├── auth_cubit.dart
│   └── auth_state.dart
└── authentication.dart  # Barrel file
```

#### 3.2.5. `init`

```bash
# Khởi tạo project structure
orchestrator init

# Với integration cụ thể
orchestrator init --integration bloc
```

**Output:**

```
lib/
├── jobs/
│   └── .gitkeep
├── executors/
│   └── .gitkeep
├── cubits/
│   └── .gitkeep
├── network_config.dart      # @NetworkRegistry([])
└── executor_config.dart     # registerExecutors()
```

### 3.3. Configuration file

**`orchestrator.yaml`**

```yaml
# Cấu hình mặc định cho CLI
orchestrator:
  integration: bloc  # bloc | provider | riverpod
  output:
    jobs: lib/jobs
    executors: lib/executors
    orchestrators: lib/cubits
    features: lib/features
  
  templates:
    job: templates/job.dart.tmpl
    executor: templates/executor.dart.tmpl
```

## 4. CLI Architecture

```
orchestrator_cli/
├── lib/
│   ├── src/
│   │   ├── commands/
│   │   │   ├── create_command.dart
│   │   │   ├── init_command.dart
│   │   │   └── subcommands/
│   │   │       ├── job_subcommand.dart
│   │   │       ├── executor_subcommand.dart
│   │   │       ├── orchestrator_subcommand.dart
│   │   │       └── feature_subcommand.dart
│   │   ├── generators/
│   │   │   ├── job_generator.dart
│   │   │   ├── executor_generator.dart
│   │   │   └── orchestrator_generator.dart
│   │   ├── templates/
│   │   │   ├── job_template.dart
│   │   │   ├── network_job_template.dart
│   │   │   └── ...
│   │   └── utils/
│   │       ├── naming.dart
│   │       └── file_utils.dart
│   └── orchestrator_cli.dart
├── bin/
│   └── orchestrator.dart
└── pubspec.yaml
```

## 5. Template Engine

### 5.1. Mustache-style templating

```dart
// templates/job_template.dart
const jobTemplate = '''
import 'package:orchestrator_core/orchestrator_core.dart';

class {{className}} extends BaseJob {
  {{#fields}}
  final {{type}} {{name}};
  {{/fields}}
  
  {{className}}({
    {{#fields}}
    required this.{{name}},
    {{/fields}}
  }) : super(id: generateJobId('{{snakeCase}}'));
}
''';
```

### 5.2. Custom templates

Developer có thể override templates:

```
project/
└── .orchestrator/
    └── templates/
        └── job.dart.tmpl  # Override mặc định
```

## 6. Interactive Mode

```bash
$ orchestrator create job

? Job name: FetchUser
? Job type: (Use arrow keys)
  ❯ Basic
    Network (offline support)
    Cached
? Add fields? (Y/n) Y
? Field 1 - Name: userId
? Field 1 - Type: String
? Add another field? (Y/n) n

✅ Created lib/jobs/fetch_user_job.dart

? Generate executor for this job? (Y/n) Y
? Inject services: (space to select)
  ❯◉ ApiService
   ◯ DatabaseService
   ◯ AuthService

✅ Created lib/executors/fetch_user_executor.dart
✅ Updated lib/executor_config.dart
```

## 7. Integration với IDE

### 7.1. VS Code Extension (Future)

- Command palette: `Orchestrator: Create Job`
- Right-click context menu
- Snippets auto-complete

### 7.2. Android Studio Plugin (Future)

- New → Orchestrator Component

## 8. Dependencies

```yaml
dependencies:
  args: ^2.4.0
  mason: ^0.1.0  # Template engine
  path: ^1.8.0
  yaml: ^3.1.0
  prompts: ^2.0.0  # Interactive mode

dev_dependencies:
  test: ^1.24.0
```

## 9. Timeline

| Milestone | Target |
|-----------|--------|
| RFC Approval | Week 1 |
| Core CLI structure | Week 2 |
| `create job`, `create executor` | Week 3 |
| `create orchestrator` (3 integrations) | Week 4 |
| `create feature`, `init` | Week 5 |
| Interactive mode | Week 6 |
| Documentation & Testing | Week 7 |
| Release v1.0.0 | Week 8 |

## 10. Open Questions

1. Nên dùng Mason hay template engine custom?
2. Có cần hỗ trợ multiple languages (i18n) cho prompts?
3. Nên publish riêng hay bundled với `orchestrator_generator`?
4. Có cần watch mode để tự động generate khi thay đổi?
