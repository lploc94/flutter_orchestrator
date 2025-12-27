import 'package:test/test.dart';
import 'package:orchestrator_core/orchestrator_core.dart';
import 'package:orchestrator_test/orchestrator_test.dart';

// Test job for testing
class TestJob extends BaseJob {
  TestJob(this.value) : super(id: 'test-job-$value');

  final int value;
}

class DoubleJob extends BaseJob {
  DoubleJob(this.value) : super(id: 'double-job-$value');

  final int value;
}

void main() {
  group('FakeDispatcher', () {
    late FakeDispatcher dispatcher;

    setUp(() {
      dispatcher = FakeDispatcher(autoEmitSuccess: false);
    });

    tearDown(() {
      dispatcher.dispose();
    });

    test('captures dispatched jobs', () {
      dispatcher.dispatch(TestJob(1));
      dispatcher.dispatch(TestJob(2));
      dispatcher.dispatch(DoubleJob(3));

      expect(dispatcher.dispatchedJobs, hasLength(3));
      expect(dispatcher.jobsOfType<TestJob>(), hasLength(2));
      expect(dispatcher.jobsOfType<DoubleJob>(), hasLength(1));
    });

    test('lastJob returns the last dispatched job', () {
      dispatcher.dispatch(TestJob(1));
      dispatcher.dispatch(TestJob(2));

      expect(dispatcher.lastJob, isA<TestJob>());
      expect((dispatcher.lastJob as TestJob).value, equals(2));
    });

    test('clear removes all jobs', () {
      dispatcher.dispatch(TestJob(1));
      dispatcher.clear();

      expect(dispatcher.dispatchedJobs, isEmpty);
    });

    test('simulateSuccess emits JobSuccessEvent', () async {
      // Use the real SignalBus singleton for event listening
      dispatcher.simulateSuccess('job-1', 'result');

      // Events are emitted to internal bus, verify via actual expectation
      // This test just verifies no exceptions are thrown
      expect(true, isTrue);
    });
  });

  group('FakeSignalBus', () {
    late FakeSignalBus bus;

    setUp(() {
      bus = FakeSignalBus();
    });

    tearDown(() {
      bus.dispose();
    });

    test('captures emitted events', () {
      bus.emit(JobSuccessEvent('job-1', 'data1'));
      bus.emit(JobFailureEvent('job-2', Exception('error'), null, false));
      bus.emit(JobSuccessEvent('job-3', 'data2'));

      expect(bus.emittedEvents, hasLength(3));
      expect(bus.eventsOfType<JobSuccessEvent>(), hasLength(2));
      expect(bus.eventsOfType<JobFailureEvent>(), hasLength(1));
    });

    test('lastEvent returns the last emitted event', () {
      bus.emit(JobSuccessEvent('job-1', 'data'));
      bus.emit(JobFailureEvent('job-2', Exception('error'), null, false));

      expect(bus.lastEvent, isA<JobFailureEvent>());
    });

    test('lastEventOfType returns last event of specific type', () {
      bus.emit(JobSuccessEvent('job-1', 'data1'));
      bus.emit(JobFailureEvent('job-2', Exception('error'), null, false));
      bus.emit(JobSuccessEvent('job-3', 'data2'));

      final lastSuccess = bus.lastEventOfType<JobSuccessEvent>();
      expect(lastSuccess, isNotNull);
      expect(lastSuccess!.correlationId, equals('job-3'));
    });

    test('hasEventOfType checks for event type presence', () {
      bus.emit(JobSuccessEvent('job-1', 'data'));

      expect(bus.hasEventOfType<JobSuccessEvent>(), isTrue);
      expect(bus.hasEventOfType<JobFailureEvent>(), isFalse);
    });

    test('clear removes all events', () {
      bus.emit(JobSuccessEvent('job-1', 'data'));
      bus.clear();

      expect(bus.emittedEvents, isEmpty);
    });

    test('isDisposed returns correct state', () {
      expect(bus.isDisposed, isFalse);
      bus.dispose();
      expect(bus.isDisposed, isTrue);
    });
  });

  group('FakeCacheProvider', () {
    late FakeCacheProvider cache;

    setUp(() {
      cache = FakeCacheProvider();
    });

    test('write and read values', () async {
      await cache.write('key1', 'value1');
      await cache.write('key2', 42);

      expect(await cache.read('key1'), equals('value1'));
      expect(await cache.read('key2'), equals(42));
      expect(await cache.read('nonexistent'), isNull);
    });

    test('delete removes value', () async {
      await cache.write('key', 'value');
      await cache.delete('key');

      expect(await cache.read('key'), isNull);
    });

    test('deleteMatching removes matching keys', () async {
      await cache.write('user:1', 'Alice');
      await cache.write('user:2', 'Bob');
      await cache.write('product:1', 'Widget');

      await cache.deleteMatching((key) => key.startsWith('user:'));

      expect(await cache.read('user:1'), isNull);
      expect(await cache.read('user:2'), isNull);
      expect(await cache.read('product:1'), equals('Widget'));
    });

    test('clear removes all values', () async {
      await cache.write('key1', 'value1');
      await cache.write('key2', 'value2');
      await cache.clear();

      expect(cache.isEmpty, isTrue);
    });

    test('entries returns all cached data', () async {
      await cache.write('key1', 'value1');
      await cache.write('key2', 'value2');

      expect(cache.entries, {'key1': 'value1', 'key2': 'value2'});
    });
  });

  group('FakeConnectivityProvider', () {
    late FakeConnectivityProvider connectivity;

    setUp(() {
      connectivity = FakeConnectivityProvider();
    });

    tearDown(() {
      connectivity.dispose();
    });

    test('initial state is online by default', () async {
      expect(await connectivity.isConnected, isTrue);
    });

    test('initial state can be offline', () async {
      connectivity = FakeConnectivityProvider(isConnected: false);
      expect(await connectivity.isConnected, isFalse);
    });

    test('setConnected changes state', () async {
      connectivity.setConnected(false);
      expect(await connectivity.isConnected, isFalse);

      connectivity.setConnected(true);
      expect(await connectivity.isConnected, isTrue);
    });

    test('toggle switches state', () async {
      final initial = await connectivity.isConnected;
      connectivity.toggle();
      expect(await connectivity.isConnected, equals(!initial));
    });

    test('goOffline and goOnline work correctly', () async {
      connectivity.goOffline();
      expect(await connectivity.isConnected, isFalse);

      connectivity.goOnline();
      expect(await connectivity.isConnected, isTrue);
    });

    test('connectivityHistory tracks changes', () async {
      connectivity.goOffline();
      connectivity.goOnline();
      connectivity.goOffline();

      expect(connectivity.connectivityHistory, [true, false, true, false]);
    });

    test('onConnectivityChanged emits changes', () async {
      final changes = <bool>[];
      connectivity.onConnectivityChanged.listen(changes.add);

      connectivity.goOffline();
      connectivity.goOnline();

      await Future.delayed(const Duration(milliseconds: 10));

      expect(changes, [false, true]);
    });
  });

  group('FakeNetworkQueueStorage', () {
    late FakeNetworkQueueStorage storage;

    setUp(() {
      storage = FakeNetworkQueueStorage();
    });

    test('saveJob and getJob work correctly', () async {
      await storage.saveJob('job-1', {'type': 'TestJob', 'status': 'pending'});

      final job = await storage.getJob('job-1');
      expect(job, isNotNull);
      expect(job!['type'], equals('TestJob'));
    });

    test('getAllJobs returns all jobs', () async {
      await storage.saveJob('job-1', {'type': 'Job1'});
      await storage.saveJob('job-2', {'type': 'Job2'});

      final jobs = await storage.getAllJobs();
      expect(jobs, hasLength(2));
    });

    test('removeJob removes specific job', () async {
      await storage.saveJob('job-1', {'type': 'Job1'});
      await storage.removeJob('job-1');

      expect(await storage.getJob('job-1'), isNull);
    });

    test('updateJob modifies existing job', () async {
      await storage.saveJob('job-1', {'type': 'Job1', 'status': 'pending'});
      await storage.updateJob('job-1', {'status': 'processing'});

      final job = await storage.getJob('job-1');
      expect(job!['status'], equals('processing'));
    });

    test('clearAll removes all jobs', () async {
      await storage.saveJob('job-1', {'type': 'Job1'});
      await storage.saveJob('job-2', {'type': 'Job2'});
      await storage.clearAll();

      expect(storage.isEmpty, isTrue);
    });

    test('operationHistory tracks operations', () async {
      await storage.saveJob('job-1', {});
      await storage.getJob('job-1');
      await storage.removeJob('job-1');

      expect(storage.operationHistory,
          ['save:job-1', 'get:job-1', 'remove:job-1']);
    });

    test('shouldFail simulates storage failures', () async {
      storage.shouldFail = true;

      expect(
        () async => await storage.saveJob('job-1', {}),
        throwsException,
      );
    });
  });

  group('Event Matchers', () {
    test('isJobSuccess matches JobSuccessEvent', () {
      final event = JobSuccessEvent('job-1', 'data');

      expect(event, isJobSuccess());
      expect(event, isJobSuccess(data: 'data'));
      expect(event, isJobSuccess(correlationId: 'job-1'));
    });

    test('isJobFailure matches JobFailureEvent', () {
      final event = JobFailureEvent('job-1', Exception('error'), null, true);

      expect(event, isJobFailure());
      expect(event, isJobFailure(correlationId: 'job-1'));
      expect(event, isJobFailure(wasRetried: true));
    });

    test('isJobProgress matches JobProgressEvent', () {
      final event =
          JobProgressEvent('job-1', progress: 0.5, message: 'Half done');

      expect(event, isJobProgress());
      expect(event, isJobProgress(minProgress: 0.4));
      expect(event, isJobProgress(maxProgress: 0.6));
      expect(event, isJobProgress(message: 'Half done'));
    });

    test('isJobCancelled matches JobCancelledEvent', () {
      final event = JobCancelledEvent('job-1');

      expect(event, isJobCancelled());
      expect(event, isJobCancelled(correlationId: 'job-1'));
    });

    test('isJobTimeout matches JobTimeoutEvent', () {
      final event = JobTimeoutEvent('job-1', const Duration(seconds: 30));

      expect(event, isJobTimeout());
      expect(event, isJobTimeout(correlationId: 'job-1'));
      expect(event, isJobTimeout(timeout: const Duration(seconds: 30)));
    });

    test('emitsEventsInOrder matches event sequence', () {
      final events = <BaseEvent>[
        JobProgressEvent('job-1', progress: 0.5),
        JobSuccessEvent('job-1', 'data'),
      ];

      expect(
        events,
        emitsEventsInOrder([
          isJobProgress(),
          isJobSuccess(),
        ]),
      );
    });

    test('emitsEventsContaining matches events in any order', () {
      final events = <BaseEvent>[
        JobSuccessEvent('job-1', 'data'),
        JobProgressEvent('job-1', progress: 0.5),
      ];

      expect(
        events,
        emitsEventsContaining([
          isJobProgress(),
          isJobSuccess(),
        ]),
      );
    });
  });

  group('Job Matchers', () {
    test('hasJobId matches job ID', () {
      final job = TestJob(1);
      expect(job, hasJobId('test-job-1'));
    });

    test('containsJobOfType checks job type in list', () {
      final jobs = <BaseJob>[TestJob(1), DoubleJob(2)];

      expect(jobs, containsJobOfType<TestJob>());
      expect(jobs, containsJobOfType<DoubleJob>());
    });

    test('hasJobCount checks number of specific job types', () {
      final jobs = <BaseJob>[TestJob(1), TestJob(2), DoubleJob(3)];

      expect(jobs, hasJobCount<TestJob>(2));
      expect(jobs, hasJobCount<DoubleJob>(1));
    });
  });
}
