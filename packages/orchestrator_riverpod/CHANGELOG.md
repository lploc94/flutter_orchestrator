## 0.6.0 - 2026-01-09

### ⚠️ BREAKING CHANGES

- **`dispatch()` now returns `JobHandle<T>`** instead of `String`.
  - This syncs with `BaseOrchestrator` from orchestrator_core.
  - Migration: Use `dispatch<T>(job)` with type parameter.
  - For fire-and-forget: Just ignore the return value (no code change needed).
  - For await: `final result = await dispatch<T>(job).future;`

### Added

- **`OrchestratorAsyncNotifier<S>`**: AsyncNotifier with orchestrator integration.
  - For async-first patterns where initial state requires async fetch.
  - State type is `AsyncValue<S>` (loading/error/data).

- **`OrchestratorFamilyAsyncNotifier<S, Arg>`**: FamilyAsyncNotifier variant.
  - For per-entity async state (e.g., fetch entity details by ID).
  - Combines family pattern with async initialization.

### Changed

- Updated documentation to use `EventJob` pattern (recommended) instead of deprecated `JobSuccessEvent`.
- All notifiers now attach `job.bus` for proper scoped bus support.
- Auto-cleanup of job tracking via `handle.future` instead of terminal events.

### Migration Examples

```dart
// Fire-and-forget (unchanged)
void loadUsers() {
  dispatch<List<User>>(LoadUsersJob());
}

// Await result (NEW!)
Future<User?> createUser(String name) async {
  final handle = dispatch<User>(CreateUserJob(name: name));
  try {
    final result = await handle.future;
    return result.data;
  } catch (e) {
    return null;
  }
}

// AsyncNotifier (NEW!)
class UserNotifier extends OrchestratorAsyncNotifier<UserState> {
  @override
  Future<UserState> buildState() async {
    final handle = dispatch<User>(LoadUserJob());
    final result = await handle.future;
    return UserState(user: result.data);
  }
}
```

## 0.6.0-beta.1 - 2026-01-08

### ⚠️ BREAKING CHANGES

- **Unified Event Handler**: Replaced granular hooks with single `onEvent(BaseEvent)` method.
  - **Removed**: `onActiveSuccess()`, `onActiveFailure()`, `onActiveCancelled()`, `onActiveTimeout()`, `onActiveEvent()`, `onPassiveEvent()`
  - **Added**: `onEvent(BaseEvent event)` - single entry point for all events
  - **Added**: `isJobRunning(String correlationId)` - helper to check if event is from your job

### Migration

```dart
// Before (v0.5.x)
@override
void onActiveSuccess(JobSuccessEvent event) {
  state = state.copyWith(data: event.data, isLoading: false);
}

@override
void onPassiveEvent(BaseEvent event) {
  if (event is MyEvent) { ... }
}

// After (v0.6.0)
@override
void onEvent(BaseEvent event) {
  switch (event) {
    case JobSuccessEvent e when isJobRunning(e.correlationId):
      state = state.copyWith(data: e.data, isLoading: false);
    case MyEvent e:
      // Handle domain events
  }
}
```

### Changed
- Updated dependency to `orchestrator_core: ^0.6.0`.
- Updated example to use `EventJob` with domain events.
- Updated README with new API documentation.

### Kept (Convenience Hooks)
- `onProgress(JobProgressEvent)` - still available for progress UI
- `onJobStarted(JobStartedEvent)` - still available for loading state
- `onJobRetrying(JobRetryingEvent)` - still available for retry UI

## 0.5.0 - 2025-12-29

### Changed
- Updated dependency to `orchestrator_core: ^0.5.0`.

## 0.4.0 - 2025-12-29

### Added
- **Testing Support**: `OrchestratorNotifier` now exposes `bus` and `dispatcher` getters.
  - Added `configureForTesting({bus, dispatcher})` method for test setup.
  - Allows overriding dependencies in tests without constructor changes.
  - Backward compatible: defaults to global singletons.

### Changed
- Updated dependency to `orchestrator_core: ^0.4.0`.

## 0.3.1 - 2025-12-27

### Fixed
- Improved pub.dev scoring: added documentation field, formatted code.

# Changelog

All notable changes to this project will be documented in this file.

## 0.3.0 - 2025-12-27

### Changed
- Updated dependency to `orchestrator_core: ^0.3.0`.
- Compatible with new Unified Data Flow and DevTools extension.

## 0.2.0 - 2025-12-25

### ⚠️ BREAKING CHANGES
- `OrchestratorNotifier.build()` renamed to `buildState()`.
  - Bus subscription is now automatic in `build()`.
  - Migration: Rename your `build()` override to `buildState()`.

### Fixed
- Use `SignalBus.instance` instead of `SignalBus()` for consistent singleton access.
- Properly set `_busSubscription = null` after cancel in `dispose()`.
- `_ensureSubscribed()` now checks `_isDisposed` before subscribing.

### Changed
- Updated dependency to `orchestrator_core: ^0.2.0`.

## 0.1.0 - 2025-12-25

### Changed
- Updated dependency to `orchestrator_core: ^0.1.0` to support Unified Data Flow and Advanced Caching features.

## 0.0.1 - 2024-12-24

### Added
- Initial release
- `OrchestratorNotifier` - Riverpod Notifier integration with job dispatch and event routing
