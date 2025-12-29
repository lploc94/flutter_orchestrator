## 0.3.0 - 2025-12-29

### Changed
- Updated dependency to `orchestrator_core: ^0.5.0`.

## 0.2.1 - 2025-12-29

### Fixed
- Added missing `listen()` method implementation to `FakeSignalBus`.

## 0.2.0 - 2025-12-29

### Changed
- **Dependency**: Relaxed `test` package constraint from `^1.24.0` to `>=1.24.0 <2.0.0`.
  - Fixes compatibility issues with `isar_generator` and other packages that depend on different `analyzer` versions.
- Updated dependency to `orchestrator_core: ^0.4.0`.

## 0.1.1 - 2025-12-27

### Fixed
- Improved pub.dev scoring: added documentation field, example, formatted code.

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 0.1.0 - 2025-12-27

### Added

- Initial release of `orchestrator_test` package
- **Mocks**
  - `MockDispatcher` - Mocktail mock for Dispatcher
  - `MockSignalBus` - Mocktail mock for SignalBus
  - `MockExecutor<T>` - Mocktail mock for BaseExecutor
- **Fakes**
  - `FakeDispatcher` - Captures dispatched jobs and simulates events
  - `FakeSignalBus` - Captures emitted events with stream support
  - `FakeCacheProvider` - In-memory cache with optional TTL tracking
  - `FakeConnectivityProvider` - Simulate online/offline states
  - `FakeNetworkQueueStorage` - In-memory queue storage
  - `FakeExecutor<T>` - Captures processed jobs with custom results
- **Test Helpers**
  - `testOrchestrator` - BDD-style orchestrator state testing
  - `testOrchestratorEvents` - Test orchestrator event handling
  - `EventCapture` - Capture and wait for events
- **Event Matchers**
  - `isJobSuccess()` - Match JobSuccessEvent
  - `isJobFailure()` - Match JobFailureEvent
  - `isJobProgress()` - Match JobProgressEvent
  - `isJobCancelled()` - Match JobCancelledEvent
  - `isJobTimeout()` - Match JobTimeoutEvent
  - `emitsEventsInOrder()` - Match event sequence
  - `emitsEventsContaining()` - Match events in any order
- **Job Matchers**
  - `isJobOfType<T>()` - Match job type
  - `hasJobId()` - Match job ID
  - `hasTimeout()` - Match job timeout
  - `hasCancellationToken()` - Match job with token
  - `hasRetryPolicy()` - Match job retry policy
  - `containsJobOfType<T>()` - List contains job type
  - `hasJobCount<T>()` - List has N jobs of type
