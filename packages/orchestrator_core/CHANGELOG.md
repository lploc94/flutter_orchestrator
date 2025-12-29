## 0.5.0 - 2025-12-29

### Added
- **Type Safety**: All result events now include `jobType` field for cross-feature event filtering.
  - `JobSuccessEvent`, `JobFailureEvent`, `JobCancelledEvent`, `JobTimeoutEvent`, `JobCacheHitEvent`, `JobPlaceholderEvent` all have optional `jobType` parameter.
  - New helper method `isFromJobType<J>()` on all result events for type-safe filtering.
  - `BaseExecutor` automatically tracks and emits `jobType` for all events.
- **Use Case**: Passive handlers can now filter events by job type:
  ```dart
  @override
  void onPassiveEvent(BaseEvent event) {
    if (event is JobSuccessEvent && event.isFromJobType<FetchUserJob>()) {
      // Handle only FetchUserJob success events
    }
  }
  ```

## 0.4.0 - 2025-12-29

### Added
- **Testing Support**: `BaseOrchestrator` now accepts optional `dispatcher` parameter for dependency injection.
  - Allows mocking `Dispatcher` in tests to verify dispatch behavior.
  - Backward compatible: defaults to global `Dispatcher()` singleton.
- **Convenience**: Added `SignalBus.listen()` method as shorthand for `stream.listen()`.

### Changed
- `BaseOrchestrator` constructor signature updated to accept optional `bus` and `dispatcher` parameters.

## 0.3.3 - 2025-12-27

### Changed
- Exposed `Dispatcher.registeredExecutors` getter for DevTools integration.
- Exposed `OrchestratorConfig.cleanupService` getter for DevTools integration.

## 0.3.2 - 2025-12-27

### Fixed
- Improved pub.dev scoring: added documentation field, formatted code.
- Updated dependency ranges for wider compatibility.

# Changelog

All notable changes to this project will be documented in this file.

## 0.3.1 - 2025-12-27

### Added
- **Resource Cleanup**: Introduced `CleanupPolicy` and `CleanupService` interface.
- **Cache**: Added LRU eviction and proactive expiration to `InMemoryCacheProvider`.
- **Config**: Added `cleanupPolicy` configuration to `OrchestratorConfig`.

## 0.3.0 - 2025-12-26

### Features: Extended Code Generation
- **New**: Added annotations for enhanced code generation:
  - `@Orchestrator` & `@OnEvent`: For declarative event routing.
  - `@GenerateAsyncState`: Automatically generates `copyWith`, `toLoading`, `toSuccess`, `when`, `maybeWhen`.
  - `@GenerateJob`: Simplifies job creation with auto-generated ID, timeout, and retry policy.
  - `@GenerateEvent`: Reduces boilerplate for event classes.
  - `@NetworkJob`: Added `generateSerialization` flag.
  - `@ExecutorRegistry`: For auto-registering executors.

## 0.2.0 - 2025-12-25

### Added
- **New**: `JobBuilder` - Fluent API for configuring jobs with timeout, retry, cache, placeholder.
- **New**: `JobResult` - Sealed class for type-safe result handling with `when`/`maybeWhen` pattern matching.
- **New**: `AsyncState` - Common state pattern with `AsyncStatus` enum and state transitions.
- **New**: Event extensions - `dataOrNull<T>()`, `dataOr<T>()`, `errorMessage` helpers.
- **New**: `OrchestratorHelpers` mixin - `dispatchAll()`, `dispatchReplacingPrevious()`, etc.
- **New**: `NetworkJobRegistry.registerType<T>()` for type-safe registration.
- **New**: `CancellationToken` improvements - `removeListener()`, `clearListeners()`, return unregister function.
- **New**: `SignalBus.isDisposed` getter and safer `dispose()` handling.
- **New**: `Dispatcher.resetForTesting()` for test isolation.
- **New**: `BaseExecutor` helpers - `emitStep()`, `invalidatePrefix()`, `readCache()`, `writeCache()`.

### Fixed
- `generateJobId()` now uses microseconds + cryptographic random for better uniqueness.
- `JobProgressEvent.progress` now auto-clamps to 0.0-1.0 range.
- Proper cleanup of `_busSubscription` in all dispose methods.
- `SignalBus.stream` throws `StateError` if accessed after disposal.

### Changed
- All adapters now use `SignalBus.instance` for consistency.

## 0.1.0 - 2025-12-25

### Features: Unified Data Flow & Caching
- **New**: **Unified Data Flow** architecture supporting Placeholder -> Cache (SWR) -> Process -> Cache Write.
- **New**: `DataStrategy` configuration for Jobs.
  - `placeholder`: Emit temporary data immediately (Skeleton UI).
  - `cachePolicy`: Configure caching behavior (TTL, Key, Revalidate, Force Refresh).
- **New**: **3 Ways of Cache Management**:
  1. **Config**: `CachePolicy(forceRefresh: true)` for Pull-to-Refresh.
  2. **Utility**: `InvalidateCacheJob` for system-wide clearing (e.g. Logout).
  3. **Side-Effect**: Methods `invalidateKey` / `invalidateMatching` in `BaseExecutor`.
- **New**: `CacheProvider` interface with default `InMemoryCacheProvider`.
- **New**: Events `JobPlaceholderEvent` and `JobCacheHitEvent`.

## 0.0.3 - 2024-12-24

### Architecture (Scoped Bus)
- **New**: Support **Scoped Bus** for isolated module communication.
  - Create isolated bus: `SignalBus.scoped()`.
  - Access global bus: `SignalBus.instance`.
  - Inject bus into Orchestrator: `MyOrchestrator(bus: myScopedBus)`.
- **Breaking Change**: `BaseJob` is no longer `const` / `@immutable`.
  - Added `SignalBus? bus` field to `BaseJob` for explicit context tracking.
  - This allows Executors to automatically route events to the correct bus without hidden magic.
- **Improved**: `BaseExecutor` now dynamically resolves the target bus based on the Job's context.

## 0.0.2 - 2024-12-24

### Added
- **Safety**: Smart Circuit Breaker (Loop Protection by Event Type)
  - Prevent infinite loops by blocking specific looping events
  - Default limit: 50 events/sec (configurable globally)
  - **New**: Support per-type limit override via `OrchestratorConfig.setTypeLimit<T>(limit)`
  - Self-healing every 1 second
- **Safety**: Type Safety Isolation (try-catch in event handlers)
- **Safety / Casting**: `JobSuccessEvent.dataAs<T>()` for safe data casting
- **UI Helper**: `BaseOrchestrator.isJobTypeRunning<T>()` to prevent UI race conditions
- **Config**: Added `OrchestratorConfig.maxEventsPerSecond`

## 0.0.1 - 2024-12-24

### Added
- Initial release
- `BaseJob` and `BaseEvent` models
- `SignalBus` - Singleton broadcast stream for event communication
- `Dispatcher` - Type-based job routing with O(1) lookup
- `BaseExecutor` - Abstract executor with error boundary, timeout, retry, cancellation
- `BaseOrchestrator` - State machine with Active/Passive event routing
- `CancellationToken` - Token-based task cancellation
- `RetryPolicy` - Configurable retry with exponential backoff
- `OrchestratorLogger` - Flexible logging system
