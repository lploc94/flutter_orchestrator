# Changelog

All notable changes to this project will be documented in this file.

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
