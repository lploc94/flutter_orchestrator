# Changelog

All notable changes to this project will be documented in this file.

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
