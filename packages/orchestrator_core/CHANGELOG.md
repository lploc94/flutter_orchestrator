# Changelog

All notable changes to this project will be documented in this file.

## [0.0.3] - 2024-12-24

### Improved
- **Smart Circuit Breaker**: Now counts events **by Type** instead of globally.
  - If `EventA` loops -> Blocks only `EventA`.
  - `EventB` (unrelated) continues to work normally.
  - Self-healing: Resets every 1 second.

## [0.0.2] - 2024-12-24

### Added
- **Safety**: Circuit Breaker (Loop Protection) to prevent infinite loops (max 50 events/sec by default)
- **Safety**: Type Safety Isolation - catch errors in event handlers to prevent app crash
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
