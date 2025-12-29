# Flutter Orchestrator - Improvement Plan

Based on feedback from Colony.cash migration project.

---

## Phase 1: Critical Testing Infrastructure (v0.4.0)

**Goal**: Unblock testing capabilities

### 1.1 Fix `orchestrator_test` Dependencies

**Package**: `orchestrator_test`
**Version bump**: 0.1.1 → 0.1.2

**Changes**:
```yaml
# pubspec.yaml - Relax test package constraint
dependencies:
  test: ">=1.24.0 <2.0.0"  # Was: ^1.24.0
```

**Files to modify**:
- `packages/orchestrator_test/pubspec.yaml`
- `packages/orchestrator_test/CHANGELOG.md`

---

### 1.2 Testable Dispatcher via Constructor Injection

**Package**: `orchestrator_core`
**Version bump**: 0.3.3 → 0.4.0 (Minor - new feature, backward compatible)

**Changes to `base_orchestrator.dart`**:
```dart
abstract class BaseOrchestrator<S> {
  S _state;
  final SignalBus _bus;
  final Dispatcher _dispatcher;  // No longer creates new instance

  BaseOrchestrator(
    this._state, {
    SignalBus? bus,
    Dispatcher? dispatcher,  // NEW: Optional injection
  })  : _bus = bus ?? SignalBus.instance,
        _dispatcher = dispatcher ?? Dispatcher();  // Falls back to singleton
```

**Backward Compatibility**: ✅ Existing code works unchanged (dispatcher defaults to singleton).

**Testing benefit**:
```dart
// In tests
final mockDispatcher = MockDispatcher();
final orchestrator = MyOrchestrator(
  initialState,
  dispatcher: mockDispatcher,
);

// Verify dispatch was called
verify(() => mockDispatcher.dispatch(any())).called(1);
```

**Files to modify**:
- `packages/orchestrator_core/lib/src/base/base_orchestrator.dart`
- `packages/orchestrator_core/CHANGELOG.md`

---

### 1.3 Add `SignalBus.listen()` Convenience Method

**Package**: `orchestrator_core`
**Version**: Same as 1.2 (0.4.0)

**Changes to `signal_bus.dart`**:
```dart
class SignalBus {
  // ... existing code ...

  /// Convenience method to listen to events.
  /// Equivalent to `stream.listen(onData)`.
  StreamSubscription<BaseEvent> listen(
    void Function(BaseEvent event) onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}
```

**Files to modify**:
- `packages/orchestrator_core/lib/src/infra/signal_bus.dart`

---

### Phase 1 Publish Order

1. `orchestrator_core` 0.3.3 → 0.4.0
2. Wait 5-10 mins for pub.dev
3. `orchestrator_test` 0.1.1 → 0.1.2 (update core dep to ^0.4.0)
4. Update integration packages to use `orchestrator_core: ^0.4.0`:
   - `orchestrator_flutter` 0.3.3 → 0.3.4
   - `orchestrator_bloc` 0.3.1 → 0.3.2
   - `orchestrator_provider` 0.3.1 → 0.3.2
   - `orchestrator_riverpod` 0.3.1 → 0.3.2
   - `orchestrator_generator` 0.3.5 → 0.3.6

---

## Phase 2: Type Safety Improvements (v0.5.0)

**Goal**: Improve developer experience with type-safe APIs

### 2.1 Add `jobType` to All Result Events

**Package**: `orchestrator_core`
**Version bump**: 0.4.0 → 0.5.0

**Changes to `event.dart`**:
```dart
/// Emitted when a Job completes successfully.
class JobSuccessEvent<T> extends BaseEvent {
  final T data;
  final bool isOptimistic;
  final String? jobType;  // NEW

  JobSuccessEvent(
    super.correlationId,
    this.data, {
    this.isOptimistic = false,
    this.jobType,  // NEW
  });
}

/// Emitted when a Job fails.
class JobFailureEvent extends BaseEvent {
  final Object error;
  final StackTrace? stackTrace;
  final bool wasRetried;
  final String? jobType;  // NEW

  JobFailureEvent(
    super.correlationId,
    this.error, [
    this.stackTrace,
    this.wasRetried = false,
    this.jobType,  // NEW
  ]);
}

// Same for JobCancelledEvent, JobTimeoutEvent
```

**Changes to `base_executor.dart`**:
```dart
void emitResult<R>(String correlationId, R data, {String? jobType}) {
  final bus = _activeBus[correlationId] ?? _globalBus;
  bus.emit(JobSuccessEvent<R>(correlationId, data, jobType: jobType));
}

// Update execute() to pass jobType
bus.emit(JobSuccessEvent(job.id, result, jobType: job.runtimeType.toString()));
```

**Files to modify**:
- `packages/orchestrator_core/lib/src/models/event.dart`
- `packages/orchestrator_core/lib/src/base/base_executor.dart`

---

### 2.2 Typed Job Pattern Documentation

**No code changes** - Documentation only

Create: `docs/en/advanced/typed-jobs.md`

```markdown
# Type-Safe Job Patterns

## Option 1: Sealed Classes (Recommended for Dart 3+)

sealed class UserJob extends BaseJob {
  UserJob({required super.id});
}

class FetchUserJob extends UserJob {
  final String userId;
  FetchUserJob(this.userId) : super(id: generateJobId('fetch_user'));
}

class UpdateUserJob extends UserJob {
  final String userId;
  final String name;
  UpdateUserJob(this.userId, this.name) : super(id: generateJobId('update_user'));
}

## Option 2: Single Job with Typed Params

class UserJob extends BaseJob {
  final UserJobParams params;
  UserJob(this.params) : super(id: generateJobId('user'));
}

sealed class UserJobParams {}
class FetchParams extends UserJobParams { final String userId; }
class UpdateParams extends UserJobParams { final String userId; final String name; }
```

---

### 2.3 Generic Executor Return Type (Optional Enhancement)

**Package**: `orchestrator_core`

**New base class** (non-breaking addition):
```dart
/// Type-safe executor with explicit result type.
abstract class TypedExecutor<T extends BaseJob, R> extends BaseExecutor<T> {
  /// Override this instead of process().
  Future<R> execute(T job);

  @override
  Future<dynamic> process(T job) => execute(job);
}
```

**Usage**:
```dart
class FetchUserExecutor extends TypedExecutor<FetchUserJob, User> {
  @override
  Future<User> execute(FetchUserJob job) async {
    return await api.getUser(job.userId);
  }
}
```

---

## Phase 3: Documentation & Patterns (v0.5.x)

**Goal**: Better guidance for real-world usage

### 3.1 Per-Feature Orchestrator Guide

Create: `docs/en/advanced/per-feature-orchestrators.md`

**Content**:
- When to use per-feature vs single orchestrator
- Dispatcher is singleton - all orchestrators share it
- Pattern: Central executor registration
- Cross-feature communication via passive events
- Example: Multi-feature app structure

```markdown
# Per-Feature Orchestrators

## Architecture

ColonyApp
├── main.dart (register all executors to Dispatcher singleton)
├── features/
│   ├── nest/
│   │   ├── nest_orchestrator.dart
│   │   ├── nest_jobs.dart
│   │   └── nest_executor.dart
│   ├── settings/
│   │   ├── settings_orchestrator.dart
│   │   └── ...

## Dispatcher is a Singleton

All orchestrators automatically use the same Dispatcher instance.
Register executors once at app startup:

void main() {
  final dispatcher = Dispatcher();  // Returns singleton
  dispatcher.register<NestJob>(NestExecutor());
  dispatcher.register<SettingsJob>(SettingsExecutor());
  runApp(MyApp());
}

## Cross-Feature Communication

Use passive events to react to other features:

class NestOrchestrator extends BaseOrchestrator<NestState> {
  @override
  void onPassiveEvent(BaseEvent event) {
    if (event is JobSuccessEvent && event.jobType == 'SettingsJob') {
      // Settings changed, refresh nest data
      dispatch(RefreshNestJob());
    }
  }
}
```

---

### 3.2 Testing Guide

Create: `docs/en/advanced/testing.md`

**Content**:
- Unit testing executors (pure Dart)
- Testing orchestrators with mock dispatcher
- Integration testing with scoped SignalBus
- BDD patterns with orchestrator_test

---

### 3.3 Job ID Format Documentation

Update: `docs/en/concepts/jobs.md`

```markdown
## Job ID Format

Job IDs follow the pattern: `{prefix}-{timestamp}-{randomHex}`

- **prefix**: From `generateJobId('my_prefix')` or defaults to `'job'`
- **timestamp**: Microseconds since epoch (ensures ordering)
- **randomHex**: 6-character hex (ensures uniqueness within same microsecond)

Example: `chamber-1735489200000000-a1b2c3`

Note: Uses hyphens (-) as separators, not underscores.
```

---

## Phase 4: Code Generation Enhancements (v0.6.0)

**Goal**: Reduce boilerplate

### 4.1 `@TypedJob` Annotation

**Package**: `orchestrator_generator`

Generate job classes from interface:

```dart
@TypedJob()
abstract class ChamberJobInterface {
  Future<List<Chamber>> list();
  Future<Chamber> create({required String name});
  Future<void> delete({required String id});
}

// Generated:
sealed class ChamberJob extends BaseJob { ... }
class ChamberListJob extends ChamberJob { ... }
class ChamberCreateJob extends ChamberJob {
  final String name;
  ...
}
class ChamberDeleteJob extends ChamberJob {
  final String id;
  ...
}
```

### 4.2 Riverpod Integration Codegen

**Package**: New `orchestrator_riverpod_generator` or extend existing

```dart
@OrchestratorProvider()
class NestOrchestrator extends BaseOrchestrator<NestState> {
  NestOrchestrator(this.ref) : super(NestState.initial());
  final Ref ref;
}

// Generated:
final nestOrchestratorProvider = Provider<NestOrchestrator>((ref) {
  final orchestrator = NestOrchestrator(ref);
  ref.onDispose(() => orchestrator.dispose());
  return orchestrator;
});
```

---

## Implementation Order & Git Workflow

### Branch Strategy

```
main
  └── feature/v0.4.0-testing-infrastructure
        ├── 1.1-fix-orchestrator-test-deps
        ├── 1.2-injectable-dispatcher
        └── 1.3-signalbus-listen
  └── feature/v0.5.0-type-safety
        ├── 2.1-jobtype-in-events
        └── 2.2-typed-executor
  └── docs/per-feature-orchestrators
  └── docs/testing-guide
```

### Commit Workflow

```bash
# Phase 1.2 example
git checkout -b feature/v0.4.0-testing-infrastructure
git checkout -b 1.2-injectable-dispatcher

# Make changes
git add .
git commit -m "feat(core): add optional dispatcher injection to BaseOrchestrator

- Allows injecting custom Dispatcher for testing
- Defaults to singleton for backward compatibility
- Enables mocking dispatch behavior in unit tests

Closes #XX"

# Merge to feature branch
git checkout feature/v0.4.0-testing-infrastructure
git merge 1.2-injectable-dispatcher

# After all Phase 1 complete
git checkout main
git merge feature/v0.4.0-testing-infrastructure
git tag -a orchestrator_core-v0.4.0 -m "Release orchestrator_core v0.4.0"
git push origin main --tags
```

### Publish Checklist

```bash
# For each package in order:
cd packages/orchestrator_core

# 1. Remove dependency_overrides
# 2. Update version in pubspec.yaml
# 3. Update CHANGELOG.md
# 4. Verify
dart pub get
dart analyze
dart test
dart pub publish --dry-run

# 5. Publish
dart pub publish

# 6. Wait for pub.dev (~5-10 mins)
# 7. Move to next package
```

---

## Priority Matrix

| Phase | Item | Impact | Effort | Priority |
|-------|------|--------|--------|----------|
| 1 | 1.2 Injectable Dispatcher | High (unblocks testing) | Low | 🔴 P0 |
| 1 | 1.1 Fix test deps | High (unblocks adoption) | Low | 🔴 P0 |
| 1 | 1.3 SignalBus.listen() | Low (convenience) | Low | 🟡 P1 |
| 2 | 2.1 jobType in events | Medium (DX) | Low | 🟡 P1 |
| 3 | 3.1 Per-feature docs | High (adoption) | Medium | 🟡 P1 |
| 3 | 3.2 Testing docs | High (adoption) | Medium | 🟡 P1 |
| 2 | 2.3 TypedExecutor | Medium (DX) | Medium | 🟢 P2 |
| 4 | 4.x Codegen | Medium (DX) | High | 🟢 P2 |

---

## Timeline Estimate

- **Phase 1**: 1-2 days coding + testing
- **Phase 2**: 1 day coding
- **Phase 3**: 2-3 days documentation
- **Phase 4**: 3-5 days (complex codegen)

**Recommended**: Ship Phase 1 first to unblock Colony.cash and other adopters.

---

## Breaking Changes Assessment

| Change | Breaking? | Migration |
|--------|-----------|-----------|
| 1.2 Injectable Dispatcher | No | Optional param, defaults to current behavior |
| 1.3 SignalBus.listen() | No | New method, existing code unchanged |
| 2.1 jobType in events | No | Optional param, nullable |
| 2.3 TypedExecutor | No | New class, opt-in usage |

**All Phase 1-3 changes are backward compatible.** No breaking changes required.