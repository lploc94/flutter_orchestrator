# RFC 003: CLI Scaffolding Tool

> **Status:** Phase 3 Completed ✅
> **Author:** Flutter Orchestrator Team
> **Created:** 2024-12-26
> **Updated:** 2025-12-26

## 1. Summary

A professional CLI tool using **Mason** to scaffold components of the Flutter Orchestrator (Job, Executor, Orchestrator, State, Feature) with standard template code.

## 2. Current problems

### 2.1. No templates available
- Developers must remember the structure of Job, Executor, and Orchestrator
- Copy-pasting from docs → Error-prone and time-consuming
- Inconsistent naming conventions

### 2.2. Complex initial setup
- Developers must create many files manually
- Import paths are error-prone

## 3. Implementation Plan

### 3.1. Phase 1 - MVP (Completed ✅)

| Command | Description | Status |
|---------|-------------|--------|
| `create job <name>` | Create Job class | ✅ Done |
| `create executor <name>` | Create Executor class | ✅ Done |
| `create cubit <name>` | Create OrchestratorCubit + State | ✅ Done |
| `create notifier <name>` | Create OrchestratorNotifier (Provider) + State | ✅ Done |
| `create riverpod <name>` | Create OrchestratorNotifier (Riverpod) + State | ✅ Done |
| `create state <name>` | Create State class with copyWith | ✅ Done |

### 3.2. Phase 2 - Enhanced (Completed ✅)

| Command | Description | Status |
|---------|-------------|--------|
| `create feature <name>` | Full feature scaffold | ✅ Done |
| `init` | Initialize project structure | ✅ Done |
| Interactive mode | Interactive wizard to create components (`-i` flag) | ✅ Done |
| Config file | `orchestrator.yaml` support | ✅ Done |

### 3.3. Phase 3 - Advanced (Completed ✅)

| Command | Description | Status |
|---------|-------------|--------|
| `doctor` | Check project setup, identify issues, suggest fixes | ✅ Done |
| `list` | List available templates and project components | ✅ Done |
| `template init` | Initialize custom templates for customization | ✅ Done |
| `template list` | List custom templates | ✅ Done |
| Custom template override | `.orchestrator/templates/` takes priority over bundled | ✅ Done |

## 4. Architecture with Mason

### 4.1. Why choose Mason?

- **Industry standard** - Widely used in the Flutter community
- **Powerful templating** - Mustache syntax with lambdas (camelCase, snakeCase, pascalCase...)
- **Conditionals & Loops** - Hỗ trợ logic phức tạp trong templates
- **File name templating** - File names can be dynamic (`{{name.snakeCase()}}_job.dart`) 
- **Well maintained** - Từ Very Good Ventures, 821 likes trên pub.dev
- **Extensible** - Hỗ trợ hooks cho pre/post generation

### 4.2. Package Structure

```
packages/orchestrator_cli/
├── lib/
│   ├── src/
│   │   ├── commands/
│   │   │   ├── create_command.dart       # Main "create" command
│   │   │   └── subcommands/
│   │   │       ├── job_command.dart      # "create job" subcommand
│   │   │       ├── executor_command.dart # "create executor" subcommand
│   │   │       ├── cubit_command.dart    # "create cubit" subcommand
│   │   │       ├── notifier_command.dart # "create notifier" subcommand
│   │   │       ├── riverpod_command.dart # "create riverpod" subcommand
│   │   │       └── state_command.dart    # "create state" subcommand
│   │   ├── bricks/                       # Mason brick templates (bundled)
│   │   │   ├── job/
│   │   │   │   ├── brick.yaml
│   │   │   │   └── __brick__/
│   │   │   │       └── {{name.snakeCase()}}_job.dart
│   │   │   ├── executor/
│   │   │   │   ├── brick.yaml
│   │   │   │   └── __brick__/
│   │   │   │       └── {{name.snakeCase()}}_executor.dart
│   │   │   ├── cubit/
│   │   │   │   ├── brick.yaml
│   │   │   │   └── __brick__/
│   │   │   │       ├── {{name.snakeCase()}}_cubit.dart
│   │   │   │       └── {{name.snakeCase()}}_state.dart
│   │   │   ├── notifier/
│   │   │   │   ├── brick.yaml
│   │   │   │   └── __brick__/
│   │   │   │       ├── {{name.snakeCase()}}_notifier.dart
│   │   │   │       └── {{name.snakeCase()}}_state.dart
│   │   │   ├── riverpod/
│   │   │   │   ├── brick.yaml
│   │   │   │   └── __brick__/
│   │   │   │       ├── {{name.snakeCase()}}_notifier.dart
│   │   │   │       └── {{name.snakeCase()}}_state.dart
│   │   │   └── state/
│   │   │       ├── brick.yaml
│   │   │       └── __brick__/
│   │   │           └── {{name.snakeCase()}}_state.dart
│   │   └── utils/
│   │       ├── brick_loader.dart         # Load bundled bricks
│   │       └── logger.dart               # CLI output formatting (mason_logger)
│   └── orchestrator_cli.dart             # Main export
├── bin/
│   └── orchestrator.dart                 # Entry point
├── pubspec.yaml
└── README.md
```

## 5. Command Details

### 5.1. `create job <name>`

```bash
# Basic usage
dart run orchestrator_cli:orchestrator create job FetchUser

# With output directory
dart run orchestrator_cli:orchestrator create job FetchUser -o lib/features/user/jobs
```

**Options:**
- `-o, --output <path>` - Output directory (default: `lib/jobs`)

**Generated file: `lib/jobs/fetch_user_job.dart`**

```dart
import 'package:orchestrator_core/orchestrator_core.dart';

/// Job to fetch user data
class FetchUserJob extends BaseJob {
  FetchUserJob() : super(id: generateJobId('fetch_user'));

  // TODO: Add job parameters as needed
  // Example:
  // final String userId;
  // FetchUserJob({required this.userId}) : super(id: generateJobId('fetch_user'));
}
```

### 5.2. `create executor <name>`

```bash
# Basic usage
dart run orchestrator_cli:orchestrator create executor FetchUser

# With output directory
dart run orchestrator_cli:orchestrator create executor FetchUser -o lib/features/user/executors
```

**Options:**
- `-o, --output <path>` - Output directory (default: `lib/executors`)

**Generated file: `lib/executors/fetch_user_executor.dart`**

```dart
import 'package:orchestrator_core/orchestrator_core.dart';

// TODO: Import the corresponding job
// import '../jobs/fetch_user_job.dart';

/// Executor for FetchUserJob
class FetchUserExecutor extends BaseExecutor<FetchUserJob> {
  // TODO: Add dependencies via constructor injection
  // final ApiService _api;
  // FetchUserExecutor(this._api);

  @override
  Future<dynamic> process(FetchUserJob job) async {
    // Check for cancellation
    job.cancellationToken?.throwIfCancelled();

    // TODO: Implement business logic
    throw UnimplementedError('FetchUserExecutor.process() not implemented');
  }
}

// TODO: Don't forget to register this executor with Dispatcher:
// dispatcher.register<FetchUserJob>(FetchUserExecutor());
```

### 5.3. `create cubit <name>`

```bash
# Basic usage
dart run orchestrator_cli:orchestrator create cubit User

# With output directory
dart run orchestrator_cli:orchestrator create cubit User -o lib/features/user/cubit
```

**Options:**
- `-o, --output <path>` - Output directory (default: `lib/cubits`)

**Generated files:**

**`lib/cubits/user_cubit.dart`**

```dart
import 'package:orchestrator_bloc/orchestrator_bloc.dart';
import 'user_state.dart';

/// UserCubit - Orchestrator for User feature
class UserCubit extends OrchestratorCubit<UserState> {
  UserCubit() : super(const UserState());

  // TODO: Add methods to trigger jobs
  // Example:
  // void loadUser(String userId) {
  //   emit(state.copyWith(isLoading: true, error: null));
  //   dispatch(FetchUserJob(userId: userId));
  // }

  @override
  void onActiveSuccess(JobSuccessEvent event) {
    // TODO: Handle success events
    // Example:
    // final data = event.dataAs<User>();
    // emit(state.copyWith(data: data, isLoading: false));
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

**`lib/cubits/user_state.dart`**

```dart
/// State for UserCubit
class UserState {
  final bool isLoading;
  final String? error;

  // TODO: Add your data fields
  // final User? user;

  const UserState({
    this.isLoading = false,
    this.error,
  });

  UserState copyWith({
    bool? isLoading,
    String? error,
  }) {
    return UserState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserState &&
        other.isLoading == isLoading &&
        other.error == error;
  }

  @override
  int get hashCode => isLoading.hashCode ^ error.hashCode;
}
```

### 5.4. `create notifier <name>` (Provider)

```bash
dart run orchestrator_cli:orchestrator create notifier User
```

**Generated files:**

**`lib/notifiers/user_notifier.dart`**

```dart
import 'package:orchestrator_provider/orchestrator_provider.dart';
import 'user_state.dart';

/// UserNotifier - Orchestrator for User feature (Provider)
class UserNotifier extends OrchestratorNotifier<UserState> {
  UserNotifier() : super(const UserState());

  // TODO: Add methods to trigger jobs
  // Example:
  // void loadUser(String userId) {
  //   state = state.copyWith(isLoading: true, error: null);
  //   dispatch(FetchUserJob(userId: userId));
  // }

  @override
  void onActiveSuccess(JobSuccessEvent event) {
    // TODO: Handle success events
    // final data = event.dataAs<User>();
    // state = state.copyWith(data: data, isLoading: false);
  }

  @override
  void onActiveFailure(JobFailureEvent event) {
    state = state.copyWith(
      isLoading: false,
      error: event.error.toString(),
    );
  }
}
```

### 5.5. `create riverpod <name>`

```bash
dart run orchestrator_cli:orchestrator create riverpod User
```

**Generated files:**

**`lib/notifiers/user_notifier.dart`**

```dart
import 'package:orchestrator_riverpod/orchestrator_riverpod.dart';
import 'user_state.dart';

/// UserNotifier - Orchestrator for User feature (Riverpod)
class UserNotifier extends OrchestratorNotifier<UserState> {
  @override
  UserState buildState() => const UserState();

  // TODO: Add methods to trigger jobs
  // Example:
  // void loadUser(String userId) {
  //   state = state.copyWith(isLoading: true, error: null);
  //   dispatch(FetchUserJob(userId: userId));
  // }

  @override
  void onActiveSuccess(JobSuccessEvent event) {
    // TODO: Handle success events
    // final data = event.dataAs<User>();
    // state = state.copyWith(data: data, isLoading: false);
  }

  @override
  void onActiveFailure(JobFailureEvent event) {
    state = state.copyWith(
      isLoading: false,
      error: event.error.toString(),
    );
  }
}

// Provider definition
// final userProvider = NotifierProvider<UserNotifier, UserState>(UserNotifier.new);
```

### 5.6. `create state <name>`

```bash
dart run orchestrator_cli:orchestrator create state User
dart run orchestrator_cli:orchestrator create state User -o lib/features/user
```

**Generated file: `lib/states/user_state.dart`**

```dart
/// State class for User
class UserState {
  final bool isLoading;
  final String? error;

  // TODO: Add your data fields
  // final User? user;

  const UserState({
    this.isLoading = false,
    this.error,
  });

  UserState copyWith({
    bool? isLoading,
    String? error,
  }) {
    return UserState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserState &&
        other.isLoading == isLoading &&
        other.error == error;
  }

  @override
  int get hashCode => isLoading.hashCode ^ error.hashCode;
}
```

## 6. Usage Examples

### 6.1. Development Mode (từ source)

```bash
# Từ thư mục packages/orchestrator_cli
dart run bin/orchestrator.dart create job FetchUser

# Hoặc từ root của monorepo
dart run packages/orchestrator_cli/bin/orchestrator.dart create job FetchUser
```

### 6.2. Global Activation (sau khi publish)

```bash
# Cài đặt global
dart pub global activate orchestrator_cli

# Sử dụng
orchestrator init -s cubit                    # Initialize project
orchestrator create feature User              # Full feature scaffold
orchestrator create feature User -i           # Interactive mode
orchestrator create job FetchUser
orchestrator create executor FetchUser
orchestrator create cubit User
orchestrator create notifier User
orchestrator create riverpod User
orchestrator create state User
```

## 7. Dependencies

```yaml
name: orchestrator_cli
version: 0.1.0

environment:
  sdk: ">=3.0.0 <4.0.0"

dependencies:
  args: ^2.4.0
  mason: ^0.1.0-dev.60
  mason_logger: ^0.3.0
  path: ^1.8.0
  yaml: ^3.1.0

dev_dependencies:
  lints: ^5.0.0
  test: ^1.24.0
  mocktail: ^1.0.0
```

**Reasons for choosing dependencies:**
- `args`: Parse command line arguments (standard Dart package)
- `mason`: Industry-standard template engine with Mustache syntax
- `mason_logger`: Beautiful CLI logging with colors, progress bars, spinners
- `path`: Cross-platform path manipulation

## 8. Brick Templates

### 8.1. Job Brick

**`bricks/job/brick.yaml`**
```yaml
name: orchestrator_job
description: Creates an Orchestrator Job class
version: 0.1.0
vars:
  name:
    type: string
    description: The name of the job (e.g., FetchUser)
    prompt: What is the job name?
```

**`bricks/job/__brick__/{{name.snakeCase()}}_job.dart`**
```dart
import 'package:orchestrator_core/orchestrator_core.dart';

/// {{name.pascalCase()}}Job - Represents a work request
///
/// Jobs are immutable data classes that describe what work needs to be done.
/// They are dispatched to Executors for processing.
class {{name.pascalCase()}}Job extends BaseJob {
  // TODO: Add job parameters
  // final String userId;

  {{name.pascalCase()}}Job({
    // required this.userId,
  }) : super(id: generateJobId('{{name.snakeCase()}}'));

  // TODO: Override toString for better debugging
  // @override
  // String toString() => '{{name.pascalCase()}}Job(userId: $userId)';
}
```

### 8.2. Executor Brick

**`bricks/executor/brick.yaml`**
```yaml
name: orchestrator_executor
description: Creates an Orchestrator Executor class
version: 0.1.0
vars:
  name:
    type: string
    description: The name of the executor (e.g., FetchUser)
    prompt: What is the executor name?
```

**`bricks/executor/__brick__/{{name.snakeCase()}}_executor.dart`**
```dart
import 'package:orchestrator_core/orchestrator_core.dart';

// TODO: Import the corresponding job
// import '{{name.snakeCase()}}_job.dart';

/// {{name.pascalCase()}}Executor - Processes {{name.pascalCase()}}Job
///
/// Executors contain the business logic and are responsible for:
/// - Executing the actual work (API calls, database operations, etc.)
/// - Handling errors and retries
/// - Emitting progress updates
class {{name.pascalCase()}}Executor extends BaseExecutor<{{name.pascalCase()}}Job> {
  // TODO: Inject dependencies via constructor
  // final ApiService _api;
  // {{name.pascalCase()}}Executor(this._api);

  @override
  Future<dynamic> process({{name.pascalCase()}}Job job) async {
    // Check for cancellation before starting
    job.cancellationToken?.throwIfCancelled();

    // TODO: Implement business logic
    // Example:
    // final result = await _api.fetchData(job.userId);
    // return result;

    throw UnimplementedError('{{name.pascalCase()}}Executor.process() not implemented');
  }
}

// Don't forget to register this executor with Dispatcher:
// dispatcher.register<{{name.pascalCase()}}Job>({{name.pascalCase()}}Executor());
```

### 8.3. State Brick

**`bricks/state/brick.yaml`**
```yaml
name: orchestrator_state
description: Creates an immutable State class with copyWith
version: 0.1.0
vars:
  name:
    type: string
    description: The name of the state (e.g., User)
    prompt: What is the state name?
```

**`bricks/state/__brick__/{{name.snakeCase()}}_state.dart`**
```dart
/// {{name.pascalCase()}}State - Immutable state class
///
/// Contains the UI state for the {{name.pascalCase()}} feature.
/// Use copyWith() to create new instances with updated values.
class {{name.pascalCase()}}State {
  /// Whether an async operation is in progress
  final bool isLoading;

  /// Error message if the last operation failed
  final String? error;

  // TODO: Add your data fields
  // final {{name.pascalCase()}}? data;
  // final List<Item> items;

  const {{name.pascalCase()}}State({
    this.isLoading = false,
    this.error,
    // this.data,
    // this.items = const [],
  });

  /// Creates a copy with the given fields replaced
  {{name.pascalCase()}}State copyWith({
    bool? isLoading,
    String? error,
    // {{name.pascalCase()}}? data,
    // List<Item>? items,
  }) {
    return {{name.pascalCase()}}State(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      // data: data ?? this.data,
      // items: items ?? this.items,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is {{name.pascalCase()}}State &&
        other.isLoading == isLoading &&
        other.error == error;
  }

  @override
  int get hashCode => isLoading.hashCode ^ error.hashCode;

  @override
  String toString() => '{{name.pascalCase()}}State(isLoading: $isLoading, error: $error)';
}
```

### 8.4. Cubit Brick (Bloc Integration)

**`bricks/cubit/brick.yaml`**
```yaml
name: orchestrator_cubit
description: Creates an OrchestratorCubit with State (Bloc integration)
version: 0.1.0
vars:
  name:
    type: string
    description: The name of the cubit (e.g., User)
    prompt: What is the cubit name?
```

**`bricks/cubit/__brick__/{{name.snakeCase()}}_cubit.dart`**
```dart
import 'package:orchestrator_bloc/orchestrator_bloc.dart';

import '{{name.snakeCase()}}_state.dart';

/// {{name.pascalCase()}}Cubit - Orchestrator for {{name.pascalCase()}} feature
///
/// Responsibilities:
/// - Manage UI state ({{name.pascalCase()}}State)
/// - Dispatch Jobs to Executors
/// - Handle Events (Success, Failure, Progress)
class {{name.pascalCase()}}Cubit extends OrchestratorCubit<{{name.pascalCase()}}State> {
  {{name.pascalCase()}}Cubit() : super(const {{name.pascalCase()}}State());

  // TODO: Add methods to trigger jobs
  // Example:
  // void load{{name.pascalCase()}}(String id) {
  //   emit(state.copyWith(isLoading: true, error: null));
  //   dispatch(Fetch{{name.pascalCase()}}Job(id: id));
  // }

  @override
  void onActiveSuccess(JobSuccessEvent event) {
    // TODO: Handle success events based on job type
    // Example:
    // final data = event.dataAs<{{name.pascalCase()}}>();
    // emit(state.copyWith(data: data, isLoading: false));
  }

  @override
  void onActiveFailure(JobFailureEvent event) {
    emit(state.copyWith(
      isLoading: false,
      error: event.error.toString(),
    ));
  }

  @override
  void onProgress(JobProgressEvent event) {
    // TODO: Handle progress updates if needed
    // emit(state.copyWith(progress: event.progress));
  }
}
```

### 8.5. Provider Notifier Brick

**`bricks/notifier/__brick__/{{name.snakeCase()}}_notifier.dart`**
```dart
import 'package:orchestrator_provider/orchestrator_provider.dart';

import '{{name.snakeCase()}}_state.dart';

/// {{name.pascalCase()}}Notifier - Orchestrator for {{name.pascalCase()}} feature (Provider)
///
/// Use with ChangeNotifierProvider:
/// ```dart
/// ChangeNotifierProvider(
///   create: (_) => {{name.pascalCase()}}Notifier(),
///   child: YourWidget(),
/// )
/// ```
class {{name.pascalCase()}}Notifier extends OrchestratorNotifier<{{name.pascalCase()}}State> {
  {{name.pascalCase()}}Notifier() : super(const {{name.pascalCase()}}State());

  // TODO: Add methods to trigger jobs
  // Example:
  // void load{{name.pascalCase()}}(String id) {
  //   state = state.copyWith(isLoading: true, error: null);
  //   dispatch(Fetch{{name.pascalCase()}}Job(id: id));
  // }

  @override
  void onActiveSuccess(JobSuccessEvent event) {
    // TODO: Handle success events
    // final data = event.dataAs<{{name.pascalCase()}}>();
    // state = state.copyWith(data: data, isLoading: false);
  }

  @override
  void onActiveFailure(JobFailureEvent event) {
    state = state.copyWith(
      isLoading: false,
      error: event.error.toString(),
    );
  }
}
```

### 8.6. Riverpod Notifier Brick

**`bricks/riverpod/__brick__/{{name.snakeCase()}}_notifier.dart`**
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orchestrator_riverpod/orchestrator_riverpod.dart';

import '{{name.snakeCase()}}_state.dart';

/// {{name.pascalCase()}}Notifier - Orchestrator for {{name.pascalCase()}} feature (Riverpod)
class {{name.pascalCase()}}Notifier extends OrchestratorNotifier<{{name.pascalCase()}}State> {
  @override
  {{name.pascalCase()}}State buildState() => const {{name.pascalCase()}}State();

  // TODO: Add methods to trigger jobs
  // Example:
  // void load{{name.pascalCase()}}(String id) {
  //   state = state.copyWith(isLoading: true, error: null);
  //   dispatch(Fetch{{name.pascalCase()}}Job(id: id));
  // }

  @override
  void onActiveSuccess(JobSuccessEvent event) {
    // TODO: Handle success events
    // final data = event.dataAs<{{name.pascalCase()}}>();
    // state = state.copyWith(data: data, isLoading: false);
  }

  @override
  void onActiveFailure(JobFailureEvent event) {
    state = state.copyWith(
      isLoading: false,
      error: event.error.toString(),
    );
  }
}

/// Provider for {{name.pascalCase()}}Notifier
final {{name.camelCase()}}Provider = NotifierProvider<{{name.pascalCase()}}Notifier, {{name.pascalCase()}}State>(
  {{name.pascalCase()}}Notifier.new,
);
```

## 9. Implementation Checklist

### Phase 1 - MVP ✅

- [x] Set up package structure (including `pubspec.yaml`)
- [x] Create brick templates (job, executor, state, cubit, notifier, riverpod)
- [x] Implement CLI commands using the `args` package
- [x] Implement brick loader (load bundled bricks)
- [x] Integrate `mason_logger` for beautiful output
- [x] Add error handling
- [x] Write unit tests (94 tests)
- [x] Write integration tests
- [x] Write README documentation

### Phase 2 - Enhanced ✅

- [x] `create feature` command (full scaffold)
- [x] `init` command (project initialization)
- [x] Interactive mode with prompts
- [x] Config file support (`orchestrator.yaml`)

### Phase 3 - Advanced ✅

- [x] `doctor` command (project health check)
- [x] `list` command (show templates and components)
- [x] `template init` command (initialize custom templates)
- [x] `template list` command (list custom templates)
- [x] Custom template override support (`.orchestrator/templates/`)
- [ ] Watch mode for hot reload during development (future consideration)

## 10. Decisions Made

### 10.1. Why use Mason?
- **Industry standard** - Maintained by Very Good Ventures
- **Powerful lambdas** - camelCase, snakeCase, pascalCase built-in
- **Beautiful logging** - `mason_logger` provides spinners, colors, progress bars
- **Extensible** - Supports adding hooks for pre/post generation
- **Well documented** - docs.brickhub.dev

### 10.2. Why separate the commands?
- `cubit` - Uses `orchestrator_bloc` (Bloc ecosystem)
- `notifier` - Uses `orchestrator_provider` (ChangeNotifier)
- `riverpod` - Uses `orchestrator_riverpod` (Riverpod Notifier)

Each integration uses a different setup (constructor vs buildState), so separating them improves clarity.

### 10.3. Output mặc định
| Type | Default Path |
|------|--------------|
| Jobs | `lib/jobs/` |
| Executors | `lib/executors/` |
| Cubits | `lib/cubits/` |
| Notifiers | `lib/notifiers/` |
| States | `lib/states/` |

Users can override the output path using the `-o` flag.

### 10.4. Bundled Bricks vs External
Bricks được bundle trong package thay vì fetch từ remote:
- Không cần network khi generate
- Version synchronized with the CLI
- Faster execution
- Custom bricks can be added in the future
