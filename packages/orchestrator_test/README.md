# orchestrator_test

A comprehensive testing toolkit for the [Orchestrator](https://github.com/lploc94/flutter_orchestrator) framework.

[![pub package](https://img.shields.io/pub/v/orchestrator_test.svg)](https://pub.dev/packages/orchestrator_test)

## Features

- **Mocks** - Pre-built mock implementations using [mocktail](https://pub.dev/packages/mocktail)
- **Fakes** - Lightweight fake implementations for isolated testing
- **Test Helpers** - BDD-style testing utilities similar to `bloc_test`
- **Matchers** - Custom matchers for event and job verification

## Installation

Add `orchestrator_test` to your dev dependencies:

```yaml
dev_dependencies:
  orchestrator_test: ^0.1.0
  test: ^1.24.0
```

## Quick Start

### Testing Orchestrators

Use `testOrchestrator` for BDD-style testing:

```dart
import 'package:test/test.dart';
import 'package:orchestrator_test/orchestrator_test.dart';
import 'package:my_app/orchestrators/counter_orchestrator.dart';

void main() {
  testOrchestrator<CounterOrchestrator, int>(
    'increments counter when increment is called',
    build: () => CounterOrchestrator(),
    act: (orchestrator) => orchestrator.increment(),
    expect: () => [1],
  );

  testOrchestrator<CounterOrchestrator, int>(
    'starts from seed value',
    build: () => CounterOrchestrator(),
    seed: () => 10,
    act: (orchestrator) => orchestrator.increment(),
    expect: () => [11],
  );
}
```

### Verifying Dispatched Jobs

Use `FakeDispatcher` to capture and verify dispatched jobs:

```dart
import 'package:test/test.dart';
import 'package:orchestrator_test/orchestrator_test.dart';

void main() {
  late FakeDispatcher dispatcher;
  late MyOrchestrator orchestrator;

  setUp(() {
    dispatcher = FakeDispatcher();
    orchestrator = MyOrchestrator(dispatcher: dispatcher);
  });

  test('dispatches SaveJob when save is called', () {
    orchestrator.save('data');

    expect(dispatcher.dispatchedJobs, hasLength(1));
    expect(dispatcher.dispatchedJobs.first, isA<SaveJob>());
  });
}
```

### Capturing Events

Use `EventCapture` to capture and wait for events:

```dart
import 'package:test/test.dart';
import 'package:orchestrator_test/orchestrator_test.dart';

void main() {
  test('emits success event after job completes', () async {
    final capture = EventCapture();

    dispatcher.dispatch(MyJob());

    final event = await capture.waitFor<JobSuccessEvent>();
    expect(event.data, equals('expected'));

    await capture.dispose();
  });
}
```

### Testing Offline Behavior

Use `FakeConnectivityProvider` to simulate offline scenarios:

```dart
import 'package:test/test.dart';
import 'package:orchestrator_test/orchestrator_test.dart';

void main() {
  test('queues job when offline', () async {
    final connectivity = FakeConnectivityProvider(isOnline: false);
    OrchestratorConfig.setConnectivityProvider(connectivity);

    dispatcher.dispatch(SendMessageJob('Hello'));

    // Verify job was queued
    expect(queueManager.hasPendingJobs, isTrue);

    // Come back online
    connectivity.goOnline();
    await Future.delayed(Duration(milliseconds: 100));

    // Verify job was processed
    expect(queueManager.hasPendingJobs, isFalse);
  });
}
```

## API Reference

### Mocks

| Class | Description |
|-------|-------------|
| `MockDispatcher` | Mocktail mock for `Dispatcher` |
| `MockSignalBus` | Mocktail mock for `SignalBus` |
| `MockExecutor<T>` | Mocktail mock for `BaseExecutor<T>` |

### Fakes

| Class | Description |
|-------|-------------|
| `FakeDispatcher` | Captures dispatched jobs, simulates events |
| `FakeSignalBus` | Captures emitted events with stream support |
| `FakeCacheProvider` | In-memory cache without expiration |
| `FakeConnectivityProvider` | Simulate online/offline states |
| `FakeNetworkQueueStorage` | In-memory queue storage |
| `FakeExecutor<T>` | Captures processed jobs with custom results |

### Test Helpers

| Function | Description |
|----------|-------------|
| `testOrchestrator` | BDD-style orchestrator state testing |
| `testOrchestratorEvents` | Test orchestrator event handling |
| `EventCapture` | Capture and wait for events |

### Event Matchers

| Matcher | Description |
|---------|-------------|
| `isJobSuccess()` | Match `JobSuccessEvent` |
| `isJobFailure()` | Match `JobFailureEvent` |
| `isJobProgress()` | Match `JobProgressEvent` |
| `isJobCancelled()` | Match `JobCancelledEvent` |
| `isJobTimeout()` | Match `JobTimeoutEvent` |
| `emitsEventsInOrder()` | Match event sequence |
| `emitsEventsContaining()` | Match events in any order |

### Job Matchers

| Matcher | Description |
|---------|-------------|
| `isJobOfType<T>()` | Match job type |
| `hasJobId()` | Match job ID |
| `hasTimeout()` | Match job timeout |
| `hasCancellationToken()` | Match job with token |
| `hasRetryPolicy()` | Match job retry policy |
| `containsJobOfType<T>()` | List contains job type |
| `hasJobCount<T>()` | List has N jobs of type |

## License

MIT License - see [LICENSE](LICENSE) for details.
