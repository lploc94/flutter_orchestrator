## 0.4.0 - 2025-12-29

### Added
- **Testing Support**: `OrchestratorCubit` and `OrchestratorBloc` now accept optional `bus` and `dispatcher` parameters.
  - Allows injecting mock `Dispatcher` for testing dispatch behavior.
  - Allows injecting scoped `SignalBus` for isolated testing.
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

### Fixed
- Use `SignalBus.instance` instead of `SignalBus()` for consistent singleton access.
- Properly set `_busSubscription = null` after cancel in `dispose()`.

### Changed
- Updated dependency to `orchestrator_core: ^0.2.0`.

## 0.1.0 - 2025-12-25

### Changed
- Updated dependency to `orchestrator_core: ^0.1.0` to support Unified Data Flow and Advanced Caching features.

## 0.0.1 - 2024-12-24

### Added
- Initial release
- `OrchestratorCubit` - Cubit integration with job dispatch and event routing
- `OrchestratorBloc` - Bloc integration with job dispatch and event routing
