/// Orchestrator Testing Library
///
/// A comprehensive testing toolkit for the Orchestrator framework that provides:
///
/// ## Mocks
/// Pre-built mock implementations using [mocktail]:
/// - [MockDispatcher]: Mock implementation of [Dispatcher]
/// - [MockSignalBus]: Mock implementation of [SignalBus]
/// - [MockExecutor]: Mock implementation of [BaseExecutor]
///
/// ## Fakes
/// Lightweight fake implementations for isolated testing:
/// - [FakeDispatcher]: Captures dispatched jobs and simulates events
/// - [FakeSignalBus]: Captures emitted events with stream support
/// - [FakeCacheProvider]: In-memory cache without expiration
/// - [FakeConnectivityProvider]: Simulate online/offline states
/// - [FakeNetworkQueueStorage]: In-memory queue storage
///
/// ## Helpers
/// BDD-style testing utilities:
/// - [testOrchestrator]: Test orchestrator state transitions
/// - [testOrchestratorEvents]: Test orchestrator event handling
/// - [EventCapture]: Capture and wait for events
///
/// ## Matchers
/// Custom matchers for event verification:
/// - [isJobSuccess]: Match [JobSuccessEvent]
/// - [isJobFailure]: Match [JobFailureEvent]
/// - [isJobProgress]: Match [JobProgressEvent]
/// - [emitsEventsInOrder]: Match event sequences
///
/// ## Example
///
/// ```dart
/// import 'package:test/test.dart';
/// import 'package:orchestrator_test/orchestrator_test.dart';
///
/// void main() {
///   testOrchestrator<CounterOrchestrator, int>(
///     'increments counter',
///     build: () => CounterOrchestrator(),
///     act: (orc) => orc.increment(),
///     expect: () => [1],
///   );
/// }
/// ```
library;

// Mocks
export 'src/mocks/mock_dispatcher.dart';
export 'src/mocks/mock_signal_bus.dart';
export 'src/mocks/mock_executor.dart';

// Fakes
export 'src/fakes/fake_cache_provider.dart';
export 'src/fakes/fake_connectivity_provider.dart';
export 'src/fakes/fake_network_queue_storage.dart';

// Helpers
export 'src/helpers/test_orchestrator.dart';
export 'src/helpers/event_capture.dart';

// Matchers
export 'src/matchers/event_matchers.dart';
export 'src/matchers/job_matchers.dart';
