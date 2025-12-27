# Changelog

All notable changes to this project will be documented in this file.

## [0.3.3] - 2025-12-27

### orchestrator_core
- **Fixed**: Exposed `Dispatcher.registeredExecutors` and `OrchestratorConfig.cleanupService` to fix missing symbols in DevTools integration.

### orchestrator_generator
- **Fixed**: Suppressed false positive `unnecessary_null_comparison` lint warnings in generated code.

### orchestrator_flutter
- **Fixed**: Bumped version to 0.3.3 to sync with `orchestrator_core` updates and resolve analysis errors.

## [0.3.2] - 2025-12-27

### All Packages (Pub.dev Ecosystem Optimization)
- **Optimized**: Achieved 160/160 points on pub.dev for the entire ecosystem.
- **Improved**: Added `documentation` and `issue_tracker` fields to all package `pubspec.yaml` files.
- **Improved**: Provided example files for `orchestrator_test` and `orchestrator_cli`.
- **Improved**: Formatted all Dart files according to the official Dart style guide.
- **Improved**: Expanded dependency version ranges for better compatibility.
- **orchestrator_flutter**: Included pre-built DevTools Extension assets for seamless integration.

## [0.3.1] - 2025-12-27

### orchestrator_test (New Package)
- **Released**: Version 0.1.0
- **Features**:
  - **Mocks**: `MockDispatcher`, `MockSignalBus`, `MockExecutor` (using mocktail).
  - **Fakes**: `FakeCacheProvider`, `FakeConnectivityProvider`, `FakeNetworkQueueStorage`.
  - **Helpers**: `testOrchestrator` (BDD-style), `EventCapture`.
  - **Matchers**: Comprehensive event and job matchers.

## [0.3.0] - 2025-12-27

### orchestrator_core (Code Generation)
- **Added**: Extended Code Generation support
  - `@Orchestrator` & `@OnEvent`: Declarative routing.
  - `@GenerateAsyncState`: Auto-generate state helpers.
  - `@GenerateJob`: Simplifies job boilerplate.
  - `@GenerateEvent`: Reduces event boilerplate.
  - `@NetworkJob`: Added `generateSerialization` flag.
  - `@ExecutorRegistry`: Auto-registration of executors.

### orchestrator_flutter
- **Fixed**: Serialization bug for DevTools (`jobType` unknown).
- **Fixed**: `pubspec.yaml` dependency configuration (bumped to depend on `core ^0.3.0`).

### orchestrator_devtools_extension
- **Improved**: Added "Peak Throughput" metric.
- **Improved**: Refined Health Score and Cache Hit Rate logic.
- **Improved**: Improved Network Queue display and Dark Mode UI.

## [0.2.0] - 2025-12-25

### Added
- **orchestrator_core**: New utilities - `JobBuilder`, `JobResult`, `AsyncState`, Event Extensions
- **orchestrator_core**: `NetworkJobRegistry.registerType<T>()` for type-safe registration
- **orchestrator_core**: `CancellationToken` improvements - `removeListener()`, `clearListeners()`
- **orchestrator_core**: `BaseExecutor` helpers - `emitStep()`, `invalidatePrefix()`, `readCache()`, `writeCache()`
- **orchestrator_core**: `Dispatcher.resetForTesting()` for test isolation

### Fixed
- **All packages**: Use `SignalBus.instance` for consistent singleton access
- **All packages**: Proper cleanup of `_busSubscription` in dispose methods
- **orchestrator_core**: `generateJobId()` uniqueness with microseconds + random
- **orchestrator_core**: `JobProgressEvent.progress` auto-clamps to 0.0-1.0

### ⚠️ Breaking Changes
- **orchestrator_riverpod**: `OrchestratorNotifier.build()` renamed to `buildState()` (bus subscription is now automatic)

## [0.1.0] - 2025-12-25

### Added
- **orchestrator_core**: Unified Data Flow architecture (Placeholder → Cache → Process)
- **orchestrator_core**: `DataStrategy`, `CachePolicy`, `CacheProvider` interface
- **orchestrator_core**: Offline Support - `NetworkQueueManager`, `NetworkQueueStorage`
- **orchestrator_flutter**: New package with `FlutterFileSafetyDelegate`, `FlutterConnectivityProvider`
- **orchestrator_generator**: New package for `NetworkJobRegistry` code generation

## [0.0.2] - 2024-12-24

### Added
- **Safety**: Smart Circuit Breaker (Loop Protection by Event Type)
  - Prevent infinite loops by blocking specific looping events
  - Default limit: 50 events/sec (configurable globally)
  - **New**: Support per-type limit override via `OrchestratorConfig.setTypeLimit<T>(limit)`
  - Self-healing every 1 second
- **Safety**: Type Safety Isolation (try-catch in event handlers)
- **Config**: Added `OrchestratorConfig.maxEventsPerSecond`

## [0.0.1] - 2024-12-24

### Added

#### Packages
- **orchestrator_core**: Core framework với Pure Dart
  - `BaseJob`, `BaseEvent` models
  - `SignalBus` (Singleton Broadcast Stream)
  - `Dispatcher` (Type-based routing)
  - `BaseExecutor` với Error Boundary, Timeout, Retry, Cancellation
  - `BaseOrchestrator` với Active/Passive event routing
  - Utilities: `CancellationToken`, `RetryPolicy`, `OrchestratorLogger`
  
- **orchestrator_bloc**: Flutter BLoC integration
  - `OrchestratorCubit`
  - `OrchestratorBloc`
  
- **orchestrator_provider**: Provider integration
  - `OrchestratorNotifier` (ChangeNotifier)
  
- **orchestrator_riverpod**: Riverpod integration
  - `OrchestratorNotifier` (Notifier)

#### Documentation
- Sách hướng dẫn 6 chương (Tiếng Việt)
- 7 Mermaid diagrams
- Bảng thuật ngữ Anh-Việt

#### Tests
- 28 unit tests passing
  - orchestrator_core: 16 tests
  - orchestrator_bloc: 4 tests
  - orchestrator_provider: 4 tests
  - orchestrator_riverpod: 4 tests
