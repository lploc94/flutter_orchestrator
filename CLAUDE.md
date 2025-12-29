# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Development Commands

This is a Dart/Flutter monorepo without Melos. Each package is managed independently.

### Running Tests

```bash
# Run tests for a specific package
cd packages/orchestrator_core && dart test
cd packages/orchestrator_bloc && flutter test
cd packages/orchestrator_flutter && flutter test

# Run a single test file
dart test test/core_test.dart

# Run with coverage
dart test --coverage=coverage
```

### Linting & Analysis

```bash
# Analyze a package
cd packages/orchestrator_core && dart analyze

# Format code
dart format .
```

### Code Generation

```bash
# Run build_runner for packages that need codegen
dart run build_runner build --delete-conflicting-outputs
```

### Publishing Workflow

Packages must be published in dependency order:
1. orchestrator_core
2. orchestrator_generator (depends on core)
3. orchestrator_flutter (depends on core)
4. orchestrator_bloc, orchestrator_provider, orchestrator_riverpod (depend on core)

```bash
# Pre-publish checks
dart pub publish --dry-run
```

## Architecture Overview

Flutter Orchestrator implements an Event-Driven architecture separating UI state management from business logic:

```
Widget → Orchestrator → Dispatcher → Executor
                ↑                        ↓
              State ← SignalBus ← Events
```

### Core Concepts

**SignalBus**: Global pub/sub event backbone. All events flow through the bus. Orchestrators subscribe and filter by correlation ID.

**BaseJob**: Work request sent to executors. Contains `id` (correlation ID) used to track the job lifecycle through events.

**BaseExecutor**: Pure Dart classes that process jobs. No UI knowledge. Override `process()` to implement business logic.

**BaseOrchestrator**: State machine that dispatches jobs and handles events. Distinguishes "active" events (from jobs it dispatched) vs "passive" events (from other orchestrators).

**Dispatcher**: Routes jobs to registered executors using O(1) type-based lookup.

### Package Dependencies

```
orchestrator_core (Pure Dart - no Flutter dependency)
    ↓
orchestrator_flutter (platform: offline storage, connectivity, DevTools)
    ↓
orchestrator_bloc / orchestrator_provider / orchestrator_riverpod (state management integrations)
    ↓
orchestrator_generator (build_runner code generation)
    ↓
orchestrator_test (testing utilities with mocktail)
```

### Key Integration Pattern (BLoC example)

```dart
class MyCubit extends OrchestratorCubit<MyState> {
  void loadData() {
    dispatch(LoadDataJob());  // Returns correlationId, tracks as "active"
  }

  @override
  void onActiveSuccess(JobSuccessEvent event) {
    emit(state.copyWith(data: event.data));  // Only receives events for jobs this cubit dispatched
  }
}
```

### Code Generation Features

- `@GenerateAsyncState()` - Generates `toLoading()`, `toSuccess()`, `toFailure()`, `when()` methods
- `@Orchestrator()` with `@OnEvent()` - Generates event routing mixins
- `@NetworkJob` - Generates serialization for offline queue support

## Commit Convention

Uses Conventional Commits with package scopes:
- `feat(core):` - orchestrator_core
- `fix(bloc):` - orchestrator_bloc
- `feat(flutter):` - orchestrator_flutter
- `feat(gen):` - orchestrator_generator
- `feat(cli):` - orchestrator_cli
- `feat(devtools):` - orchestrator_devtools_extension

Breaking changes use `!`: `feat(core)!: description`

## Local Development

Packages use `dependency_overrides` with `path:` for local testing. Remove before publishing:

```yaml
dependency_overrides:
  orchestrator_core:
    path: ../orchestrator_core
```