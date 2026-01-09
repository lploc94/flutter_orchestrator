## 0.6.0 - 2026-01-09

### ⚠️ BREAKING CHANGES

#### Removed: `BaseJob` class
- All jobs must now extend `EventJob<TResult, TEvent>`
- Every job must define a domain event and implement `createEventTyped(result)`
- Migration: Replace `extends BaseJob` with `extends EventJob<ReturnType, YourEvent>`

#### Removed: Legacy Framework Events
The following deprecated events have been removed:
- `JobSuccessEvent` - Use custom domain events via `EventJob`
- `JobFailureEvent` - Use `JobHandle.future` catch blocks
- `JobCancelledEvent` - Use `CancellationToken` + `JobHandle.future`
- `JobTimeoutEvent` - Use `JobHandle.future` timeout handling
- `JobCacheHitEvent` - Use `EventJob` with `DataSource` field in event
- `JobPlaceholderEvent` - Use `DataStrategy.placeholder`
- `JobProgressEvent` - Use `JobHandle.progress` stream
- `JobStartedEvent` - Use `OrchestratorObserver.onJobStart`
- `JobRetryingEvent` - Use `OrchestratorObserver`

#### Removed: Utilities
- `event_extensions.dart` - No longer needed
- `JobBuilder` class - Configure jobs directly via constructor

#### Changed: Type Signatures
- `dispatch()` now accepts `EventJob` instead of `BaseJob`
- `BaseExecutor<T>` now requires `T extends EventJob`
- `OrchestratorObserver` methods now use `EventJob` parameter type

### Migration Guide

```dart
// BEFORE
class SeedJob extends BaseJob {
  SeedJob() : super(id: generateJobId('seed'));
}

// AFTER
class SeedCompletedEvent extends BaseEvent {
  SeedCompletedEvent(super.correlationId);
}

class SeedJob extends EventJob<void, SeedCompletedEvent> {
  SeedJob() : super(id: generateJobId('seed'));

  @override
  SeedCompletedEvent createEventTyped(void _) => SeedCompletedEvent(id);
}
```

### Why This Change?

This enforces proper domain modeling:
1. Every job explicitly declares its result type and event
2. No "escape hatch" with generic success/failure events
3. Type-safe event handling with pattern matching
4. Clearer separation between job execution and state updates

---

## 0.5.3 - 2026-01-08

### Breaking Changes
- **Unified Event Handler**: Replaced `onActiveSuccess`/`onActiveFailure`/`onPassive*` methods with single `onEvent(BaseEvent)` using Dart 3 pattern matching.
  - Old: `@override void onActiveSuccess(JobSuccessEvent e) { ... }`
  - New: `@override void onEvent(BaseEvent e) { switch(e) { case MyEvent e: ... } }`
- **Example Updated**: `orchestrator_core_example.dart` now demonstrates `EventJob` with domain events and `onEvent` pattern.

### Fixed (v1.0.0 Audit)
- **Audit #1 - EventJob + Cache Flow**: Fixed cache key generation and SWR revalidation timing.
- **Audit #2 - Cancellation Token**: `CancelledException` now handled separately from failures (no double event emission).
- **Audit #3 - Retry Policy**: Prevented double `JobFailureEvent` emission on retry exhaustion.
- **Audit #4 - Offline/NetworkAction Flow**:
  - Fixed race condition with atomic `claimNextPendingJob()`.
  - Fixed job ID mismatch between restored job and storage wrapper.
  - Added fallback to normal execution when queue fails.
- **Audit #6 - OrchestratorObserver**: All legacy events now properly call `onEvent()` for consistency.
- **Executor catch block**: `JobFailureEvent` now calls `OrchestratorObserver.instance?.onEvent()`.

### Added
- **Comprehensive Test Suite**: Added 56 new tests (111 → 167 total):
  - Circuit Breaker: 7 tests for loop protection and event rate limiting.
  - SagaFlow: 17 tests for saga pattern with LIFO rollback.
  - OrchestratorObserver: 12 tests for job lifecycle hooks and event notifications.
  - RetryPolicy: 20 tests for exponential backoff and retry decisions.

### Audited & Verified
All 9 critical flows audited and verified for v1.0.0 release:
1. ✅ EventJob + Cache Flow
2. ✅ Cancellation Token Flow
3. ✅ Retry Policy Flow
4. ✅ Offline/NetworkAction Flow
5. ✅ SignalBus Scoped vs Global
6. ✅ OrchestratorObserver Flow
7. ✅ Circuit Breaker (Loop Protection)
8. ✅ SagaFlow Pattern
9. ✅ JobHandle Progress Flow

## 0.5.2 - 2026-01-06

### Added
- **Saga Pattern**: New `SagaFlow` class for orchestrated workflows with rollback support.
  - Execute steps with `run(action, compensate)`.
  - LIFO rollback with `rollback()`.
  - Clear compensations on success with `commit()`.
  - Named sagas for debugging: `SagaFlow(name: 'TransferAsset')`.
  - Integrated with `OrchestratorConfig.logger`.

## 0.5.1 - 2025-12-30

### Fixed
- Re-publish with complete code generation annotations (`@TypedJob`, `@OrchestratorProvider`).
- All 105 tests passing.

## 0.5.0 - 2025-12-29

### Added
- **Type Safety**: All result events now include `jobType` field for cross-feature event filtering.
  - `JobSuccessEvent`, `JobFailureEvent`, `JobCancelledEvent`, `JobTimeoutEvent`, `JobCacheHitEvent`, `JobPlaceholderEvent` all have optional `jobType` parameter.
  - New helper method `isFromJobType<J>()` on all result events for type-safe filtering.
  - `BaseExecutor` automatically tracks and emits `jobType` for all events.
- **TypedExecutor**: New base class for type-safe executors with compile-time result type checking.
  - `TypedExecutor<T, R>`: Async executor with typed `run(T job)` method returning `Future<R>`.
  - `SyncTypedExecutor<T, R>`: Sync executor with `runSync(T job)` method returning `R`.
- **Code Generation Annotations**:
  - `@TypedJob`: Generate sealed job hierarchies from interface classes.
  - `@OrchestratorProvider`: Generate Riverpod providers for orchestrators.
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
