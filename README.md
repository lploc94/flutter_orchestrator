# Flutter Orchestrator

<p align="center">
  <strong>Event-Driven Orchestrator Architecture for Flutter Applications</strong>
</p>

<p align="center">
  <a href="book/README.md">📖 Read Book (English)</a> •
  <a href="book/vi/README.md">📖 Đọc Sách (Tiếng Việt)</a> •
  <a href="packages/orchestrator_core">📦 Core Package</a>
</p>

---

## Introduction

**Flutter Orchestrator** is an event-driven architecture designed to solve the "God Classes" problem in large Flutter applications. Instead of letting Controllers/BLoCs handle both UI state and business logic, this architecture clearly separates:

- **Orchestrator**: Manages UI State
- **Executor**: Executes Business Logic  
- **Signal Bus**: Asynchronous Communication

## Project Structure

```
flutter_orchestrator/
├── book/                    # Documentation
│   ├── chapters/            # 6 chapters (English - Primary)
│   ├── vi/                  # Vietnamese version (Tiếng Việt)
│   │   └── chapters/
│   └── GLOSSARY.md          # English-Vietnamese Glossary
│
├── packages/                # Dart/Flutter packages
│   ├── orchestrator_core/   # Core framework (Pure Dart)
│   ├── orchestrator_bloc/   # BLoC integration
│   ├── orchestrator_provider/  # Provider integration
│   └── orchestrator_riverpod/  # Riverpod integration
│
└── examples/                # Example applications
```

## Quick Start

### 1. Add dependency

```yaml
dependencies:
  orchestrator_bloc: ^0.0.3  # or orchestrator_provider / orchestrator_riverpod
```

### 2. Create Executor

```dart
class FetchUserExecutor extends BaseExecutor<FetchUserJob> {
  @override
  Future<dynamic> process(FetchUserJob job) async {
    return await api.getUser(job.userId);
  }
}
```

### 3. Create Orchestrator

```dart
class UserCubit extends OrchestratorCubit<UserState> {
  UserCubit() : super(const UserState());

  void loadUser(String id) {
    emit(state.copyWith(isLoading: true));
    dispatch(FetchUserJob(id));
  }

  @override
  void onActiveSuccess(JobSuccessEvent event) {
    emit(state.copyWith(user: event.data, isLoading: false));
  }
}
```

## Tests

```bash
# Run all tests
cd packages/orchestrator_core && dart test
cd packages/orchestrator_bloc && flutter test
cd packages/orchestrator_provider && flutter test
cd packages/orchestrator_riverpod && flutter test
```

**Total: 28 tests passing ✅**

## License

MIT License - see [LICENSE](LICENSE) for details.
