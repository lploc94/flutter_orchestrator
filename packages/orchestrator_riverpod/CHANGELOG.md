# Changelog

All notable changes to this project will be documented in this file.

## [0.2.0] - 2025-12-25

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

## [0.1.0] - 2025-12-25

### Changed
- Updated dependency to `orchestrator_core: ^0.1.0` to support Unified Data Flow and Advanced Caching features.

## [0.0.1] - 2024-12-24

### Added
- Initial release
- `OrchestratorNotifier` - Riverpod Notifier integration with job dispatch and event routing
