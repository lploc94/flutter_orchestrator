# Testing

The Flutter Orchestrator architecture is designed to be **Testable**. Business logic resides in pure Dart Executors and Orchestrators, independent of Flutter, allowing for simple and fast testing.

We provide a dedicated package, **`orchestrator_test`**, to simplify testing with mocks, fakes, and BDD-style helpers.

---

## 1. Setup

Add `orchestrator_test` to your `dev_dependencies`:

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  orchestrator_test: ^0.1.0
  bloc_test: ^9.0.0 # Recommended for testing Cubits/Blocs
```

---

## 2. Unit Testing Executors

Executors contain the pure business logic. You can unit test them by mocking their dependencies (like API services or the Dispatcher).

`orchestrator_test` exports `mocktail`, so you can easily create mocks.

```dart
import 'package:test/test.dart';
import 'package:orchestrator_test/orchestrator_test.dart';

// Mock API dependency
class MockApiService extends Mock implements ApiService {}

void main() {
  group('FetchUserExecutor', () {
    late MockApiService mockApi;
    late FetchUserExecutor executor;
    
    setUp(() {
      mockApi = MockApiService();
      executor = FetchUserExecutor(mockApi);
    });
    
    test('should return user on success', () async {
      // Arrange
      final expectedUser = User(id: '123', name: 'John');
      when(() => mockApi.getUser('123')).thenAnswer((_) async => expectedUser);
      
      // Act
      final result = await executor.process(FetchUserJob(userId: '123'));
      
      // Assert
      expect(result, equals(expectedUser));
      verify(() => mockApi.getUser('123')).called(1);
    });
  });
}
```

---

## 3. Testing Orchestrators (BDD Style)

Orchestrators (Cubits) manage state. You can test them using the `testOrchestrator` helper, which provides a declarative way to test state transitions, similar to `blocTest`.

```dart
import 'package:orchestrator_test/orchestrator_test.dart';

testOrchestrator<CounterOrchestrator, int>(
  'emits 1 when increment is called',
  build: () => CounterOrchestrator(),
  act: (orchestrator) => orchestrator.increment(),
  expect: () => [1],
);

testOrchestrator<CounterOrchestrator, int>(
  'emits specific state sequence',
  build: () => CounterOrchestrator(),
  act: (orchestrator) async {
    orchestrator.increment();
    orchestrator.increment();
  },
  expect: () => [1, 2],
);
```

### 3.1. Testing with Mocks

You can pass a `MockDispatcher` to your orchestrator if it supports dependency injection, or use a `FakeExecutor` registered to the global dispatcher (if your orchestrator uses the global singleton).

```dart
testOrchestrator<UserOrchestrator, UserState>(
  'emits [loading, success] on fetch',
  setUp: () {
    // Register a fake executor to handle the job immediately
    final dispatcher = Dispatcher();
    dispatcher.register(FakeExecutor<FetchUserJob>(
      (job) async => User(name: 'Fake User')
    ));
  },
  build: () => UserOrchestrator(),
  act: (orc) => orc.fetchUser('123'),
  expect: () => [
    UserState.loading(),
    UserState.success(User(name: 'Fake User')),
  ],
);
```

---

## 4. Integration Testing with Fakes

`orchestrator_test` provides powerful **Fakes** to simulate complex behavior without mocking everything manually.

### 4.1. FakeExecutor

Simulate backend responses or logic without network calls.

```dart
final executor = FakeExecutor<MyJob>((job) async {
  if (job.id == 'error') throw Exception('Failed');
  return 'Success';
});

dispatcher.register(executor);
```

### 4.2. FakeConnectivityProvider

Test "Offline Support" features by controlling network state.

```dart
test('queues job when offline', () async {
  final connectivity = FakeConnectivityProvider(isConnected: false);
  OrchestratorConfig.setConnectivityProvider(connectivity);

  dispatcher.dispatch(NetworkJob());

  // Verify job is queued, not processed
  expect(queueManager.hasPendingJobs, isTrue);

  // Go online -> Job should be processed
  connectivity.goOnline();
  await Future.delayed(Duration(milliseconds: 100)); // Wait for sync
  expect(queueManager.hasPendingJobs, isFalse);
});
```

### 4.3. FakeCacheProvider

Test caching logic in memory.

```dart
final cache = FakeCacheProvider(trackTtl: true);
await cache.write('key', 'value', ttl: Duration(seconds: 1));
```

---

## 5. Event Testing

### 5.1. EventCapture

Capture events emitted by the `SignalBus` to verify interactions.

```dart
test('should emit failure event', () async {
  final capture = EventCapture(); // Listens to global bus by default
  
  // Dispatch a job that fails
  dispatcher.dispatch(FailingJob());
  
  // Wait for specific event
  final event = await capture.waitFor<JobFailureEvent>();
  
  expect(event.error, isA<Exception>());
  expect(capture.events, hasLength(1));
});
```

### 5.2. Event Matchers

Custom matchers make assertions readable.

```dart
expect(event, isJobSuccess(data: 'result'));
expect(event, isJobFailure(wasRetried: true));
expect(event, isJobProgress(minProgress: 0.5));
expect(event, isJobCancelled());
expect(event, isJobTimeout());
```

And for sequences:

```dart
expect(
  events,
  emitsEventsInOrder([
    isJobProgress(),
    isJobSuccess(),
  ]),
);
```

---

## 6. Full Example (Integration)

Here is a full integration test example using `bloc_test` and `FakeExecutor`:

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:orchestrator_test/orchestrator_test.dart';

void main() {
  late Dispatcher dispatcher;

  setUp(() {
    dispatcher = Dispatcher();
    dispatcher.resetForTesting();
  });

  blocTest<CounterCubit, CounterState>(
    'emits [loading, success] when increment is called',
    setUp: () {
      // Register FakeExecutor
      dispatcher.register<IncrementJob>(
        FakeExecutor<IncrementJob>((job) async => 10),
      );
    },
    build: () => CounterCubit(),
    act: (cubit) => cubit.increment(),
    expect: () => [
      // Use matchers or explicit values
      isA<CounterState>().having((s) => s.isLoading, 'isLoading', true),
      isA<CounterState>().having((s) => s.count, 'count', 10),
    ],
  );
}
```

---

## 7. Best Practices

- **Use Fakes over Mocks**: Prefer `FakeExecutor` over mocking `process()` when possible. It's more realistic and requires less setup.
- **Isolate Tests**: Ensure `Dispatcher` and `SignalBus` are reset or scoped between tests. `Dispatcher` is a singleton, so use `setUp(() => dispatcher.resetForTesting())`.
- **Test Matchers**: Use `isJobSuccess`, `hasJobId` etc. to keep tests readable.
- **Offline Tests**: Always use `FakeConnectivityProvider` to test offline/online transitions explicitly.
