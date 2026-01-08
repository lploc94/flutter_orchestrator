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
