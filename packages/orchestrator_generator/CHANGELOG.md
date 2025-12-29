## 0.5.1 - 2025-12-30

### Fixed
- Updated dependency to `orchestrator_core: ^0.5.1` for proper annotation support.
- Removed `autoDispose` option from `@OrchestratorProvider` (incompatible with current OrchestratorNotifier).

## 0.5.0 - 2025-12-29

### Added
- **TypedJobGenerator**: Generate sealed job hierarchies from `@TypedJob` annotated interfaces.
  - Converts abstract interface methods to concrete job classes.
  - Supports timeout, retry policy, and custom ID prefix configuration.
  - Example: `abstract class UserJobInterface { Future<User> fetchUser(String id); }` → `sealed class UserJob` + `class FetchUserJob`.
- **OrchestratorProviderGenerator**: Generate Riverpod providers from `@OrchestratorProvider` annotated classes.
  - Creates `NotifierProvider` with automatic state type inference.
  - Supports `autoDispose` option for screen-specific orchestrators.

### Changed
- Updated dependency to `orchestrator_core: ^0.5.0`.

## 0.4.0 - 2025-12-29

### Changed
- Updated dependency to `orchestrator_core: ^0.4.0`.

## 0.3.5 - 2025-12-27

### Fixed
- Renamed `lib/builder.dart` to `lib/orchestrator_generator.dart` to match package name importance.
- Removed checked-in `pubspec.lock` to fix pub verification warning.

## 0.3.4 - 2025-12-27

### Fixed
- Fixed false positive lint warning `unnecessary_null_comparison` in generator logic.

## 0.3.2 - 2025-12-27

### Fixed
- Fixed static analysis errors regarding nullable `element.name` in strict environments.
- Added missing API documentation to builders.

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
