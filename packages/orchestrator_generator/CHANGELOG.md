## 0.3.1 - 2025-12-27

### Fixed
- Improved pub.dev scoring: added documentation field, formatted code.

# Changelog

All notable changes to this project will be documented in this file.

## 0.3.0 - 2025-12-26

### Features: Extended Code Generation
- **New**: `OrchestratorGenerator` for `@Orchestrator` & `@OnEvent`.
- **New**: `AsyncStateGenerator` for `@GenerateAsyncState`.
- **New**: `JobGenerator` for `@GenerateJob` (with auto ID/retry/timeout).
- **New**: `EventGenerator` for `@GenerateEvent`.
- **New**: `NetworkJobGenerator` supports `generateSerialization: true`.
- **New**: `ExecutorRegistryGenerator` generates `registerExecutors` function.

## 0.2.0 - 2025-12-25

### Added
- Initial public release
- `NetworkRegistryGenerator` for `@NetworkRegistry` annotation
- Auto-generates `registerNetworkJobs()` function
- Warning logs for empty or invalid annotations
- Documentation comments in generated code
