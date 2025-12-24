# Changelog

All notable changes to this project will be documented in this file.

## [0.0.3] - 2024-12-24

### Architecture (Scoped Bus)
- **New**: Support **Scoped Bus** for isolated module communication.
  - Create isolated bus: `SignalBus.scoped()`.
  - Access global bus: `SignalBus.instance`.
  - Inject bus into Orchestrator: `MyOrchestrator(bus: myScopedBus)`.
- **Breaking Change**: `BaseJob` is no longer `const` / `@immutable`.
  - Added `SignalBus? bus` field to `BaseJob` for explicit context tracking.
  - This allows Executors to automatically route events to the correct bus without hidden magic.
- **Improved**: `BaseExecutor` now dynamically resolves the target bus based on the Job's context.

## [0.0.2] - 2024-12-24

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

## [0.0.1] - 2024-12-24

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
