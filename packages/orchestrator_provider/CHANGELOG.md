# Changelog

All notable changes to this project will be documented in this file.

## [0.2.0] - 2025-12-25

### Fixed
- Use `SignalBus.instance` instead of `SignalBus()` for consistent singleton access.
- Properly set `_busSubscription = null` after cancel in `dispose()`.

### Changed
- Updated dependency to `orchestrator_core: ^0.2.0`.

## [0.1.0] - 2025-12-25

### Changed
- Updated dependency to `orchestrator_core: ^0.1.0` to support Unified Data Flow and Advanced Caching features.

## [0.0.1] - 2024-12-24

### Added
- Initial release
- `OrchestratorNotifier` - ChangeNotifier integration with job dispatch and event routing
