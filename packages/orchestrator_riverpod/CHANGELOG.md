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
