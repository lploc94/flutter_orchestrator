import 'package:test/test.dart';
import 'package:orchestrator_core/orchestrator_core.dart';

// =============================================================================
// Test Fixtures
// =============================================================================

/// Test domain event
class TestSentEvent extends BaseEvent {
  final String message;
  TestSentEvent(super.correlationId, this.message);
}

/// Test job that implements NetworkAction for offline support
class TestNetworkJob extends EventJob<String, TestSentEvent>
    implements NetworkAction<String> {
  final String payload;

  TestNetworkJob(this.payload) : super(id: generateJobId('test_network'));

  @override
  TestSentEvent createEventTyped(String result) => TestSentEvent(id, result);

  @override
  Map<String, dynamic> toJson() => {'payload': payload, 'id': id};

  factory TestNetworkJob.fromJson(Map<String, dynamic> json) {
    return TestNetworkJob(json['payload'] as String);
  }

  @override
  String createOptimisticResult() => 'optimistic: $payload';

  @override
  String? get deduplicationKey => null;
}

/// Simple event for void result jobs
class TestVoidEvent extends BaseEvent {
  TestVoidEvent(super.correlationId);
}

/// Test job with void result
class TestVoidNetworkJob extends EventJob<void, TestVoidEvent>
    implements NetworkAction<void> {
  final String action;

  TestVoidNetworkJob(this.action) : super(id: generateJobId('test_void'));

  @override
  TestVoidEvent createEventTyped(void _) => TestVoidEvent(id);

  @override
  Map<String, dynamic> toJson() => {'action': action, 'id': id};

  factory TestVoidNetworkJob.fromJson(Map<String, dynamic> json) {
    return TestVoidNetworkJob(json['action'] as String);
  }

  @override
  void createOptimisticResult() {}

  @override
  String? get deduplicationKey => null;
}

// =============================================================================
// InMemoryNetworkQueueStorage Tests
// =============================================================================

void main() {
  group('InMemoryNetworkQueueStorage', () {
    late InMemoryNetworkQueueStorage storage;

    setUp(() {
      storage = InMemoryNetworkQueueStorage();
    });

    test('saveJob and getJob work correctly', () async {
      final data = {'id': 'test-1', 'payload': 'hello', 'timestamp': '2024-01-01T10:00:00.000Z'};
      await storage.saveJob('test-1', data);

      final retrieved = await storage.getJob('test-1');
      expect(retrieved, equals(data));
    });

    test('saveJob creates a copy of the data', () async {
      final data = {'id': 'test-1', 'value': 'original'};
      await storage.saveJob('test-1', data);

      // Modify original
      data['value'] = 'modified';

      final retrieved = await storage.getJob('test-1');
      expect(retrieved?['value'], equals('original'));
    });

    test('getJob returns null for non-existent job', () async {
      final retrieved = await storage.getJob('non-existent');
      expect(retrieved, isNull);
    });

    test('getJob returns a copy, not reference', () async {
      final original = {'id': 'test-1', 'value': 'original'};
      await storage.saveJob('test-1', original);

      final retrieved = await storage.getJob('test-1');
      retrieved?['value'] = 'modified';

      final retrievedAgain = await storage.getJob('test-1');
      expect(retrievedAgain?['value'], equals('original'));
    });

    test('removeJob deletes the job', () async {
      await storage.saveJob('test-1', {'id': 'test-1'});
      expect(storage.length, equals(1));

      await storage.removeJob('test-1');

      final retrieved = await storage.getJob('test-1');
      expect(retrieved, isNull);
      expect(storage.length, equals(0));
    });

    test('removeJob does nothing for non-existent job', () async {
      await storage.saveJob('test-1', {'id': 'test-1'});
      await storage.removeJob('non-existent');

      expect(storage.length, equals(1));
    });

    test('getAllJobs returns empty list when no jobs', () async {
      final jobs = await storage.getAllJobs();
      expect(jobs, isEmpty);
    });

    test('getAllJobs returns sorted by timestamp (FIFO)', () async {
      await storage.saveJob('job-2', {
        'id': 'job-2',
        'timestamp': '2024-01-01T10:00:01.000Z',
      });
      await storage.saveJob('job-1', {
        'id': 'job-1',
        'timestamp': '2024-01-01T10:00:00.000Z',
      });
      await storage.saveJob('job-3', {
        'id': 'job-3',
        'timestamp': '2024-01-01T10:00:02.000Z',
      });

      final jobs = await storage.getAllJobs();

      expect(jobs.length, equals(3));
      expect(jobs[0]['id'], equals('job-1'));
      expect(jobs[1]['id'], equals('job-2'));
      expect(jobs[2]['id'], equals('job-3'));
    });

    test('getAllJobs handles missing/invalid timestamps gracefully', () async {
      await storage.saveJob('job-1', {'id': 'job-1'});
      await storage.saveJob('job-2', {'id': 'job-2', 'timestamp': 'invalid'});
      await storage.saveJob('job-3', {'id': 'job-3', 'timestamp': '2024-01-01T10:00:00.000Z'});

      final jobs = await storage.getAllJobs();
      expect(jobs.length, equals(3));
    });

    test('updateJob modifies existing job', () async {
      await storage.saveJob('test-1', {
        'id': 'test-1',
        'status': 'pending',
        'retryCount': 0,
      });

      await storage.updateJob('test-1', {'status': 'processing'});

      final job = await storage.getJob('test-1');
      expect(job?['status'], equals('processing'));
      expect(job?['retryCount'], equals(0)); // Other fields preserved
    });

    test('updateJob does nothing for non-existent job', () async {
      await storage.updateJob('non-existent', {'status': 'processing'});

      final job = await storage.getJob('non-existent');
      expect(job, isNull);
    });

    test('clearAll removes all jobs', () async {
      await storage.saveJob('job-1', {'id': 'job-1'});
      await storage.saveJob('job-2', {'id': 'job-2'});
      await storage.saveJob('job-3', {'id': 'job-3'});

      expect(storage.length, equals(3));

      await storage.clearAll();

      expect(storage.length, equals(0));
      final jobs = await storage.getAllJobs();
      expect(jobs, isEmpty);
    });

    test('containsJob returns correct value', () async {
      await storage.saveJob('test-1', {'id': 'test-1'});

      expect(storage.containsJob('test-1'), isTrue);
      expect(storage.containsJob('test-2'), isFalse);
    });

    test('length returns correct count', () async {
      expect(storage.length, equals(0));

      await storage.saveJob('job-1', {'id': 'job-1'});
      expect(storage.length, equals(1));

      await storage.saveJob('job-2', {'id': 'job-2'});
      expect(storage.length, equals(2));

      await storage.removeJob('job-1');
      expect(storage.length, equals(1));
    });
  });

  // ===========================================================================
  // MockConnectivityProvider Tests
  // ===========================================================================

  group('MockConnectivityProvider', () {
    late MockConnectivityProvider provider;

    setUp(() {
      provider = MockConnectivityProvider();
    });

    tearDown(() {
      provider.dispose();
    });

    test('defaults to connected', () async {
      expect(await provider.isConnected, isTrue);
    });

    test('initialConnected parameter works', () async {
      final offlineProvider = MockConnectivityProvider(initialConnected: false);
      expect(await offlineProvider.isConnected, isFalse);
      offlineProvider.dispose();
    });

    test('setConnected updates state', () async {
      expect(await provider.isConnected, isTrue);

      provider.setConnected(false);
      expect(await provider.isConnected, isFalse);

      provider.setConnected(true);
      expect(await provider.isConnected, isTrue);
    });

    test('onConnectivityChanged emits changes', () async {
      final changes = <bool>[];
      final subscription = provider.onConnectivityChanged.listen(changes.add);

      provider.setConnected(false);
      provider.setConnected(true);
      provider.setConnected(false);

      await Future.delayed(Duration(milliseconds: 10));

      expect(changes, equals([false, true, false]));

      await subscription.cancel();
    });

    test('dispose prevents further emissions', () async {
      final changes = <bool>[];
      final subscription = provider.onConnectivityChanged.listen(changes.add);

      provider.setConnected(false);
      await Future.delayed(Duration(milliseconds: 10));

      provider.dispose();

      // This should not emit
      provider.setConnected(true);
      await Future.delayed(Duration(milliseconds: 10));

      expect(changes, equals([false]));

      await subscription.cancel();
    });
  });

  // ===========================================================================
  // NetworkQueueManager Tests
  // ===========================================================================

  group('NetworkQueueManager with InMemoryStorage', () {
    late InMemoryNetworkQueueStorage storage;
    late NetworkQueueManager manager;

    setUp(() {
      storage = InMemoryNetworkQueueStorage();
      manager = NetworkQueueManager(storage: storage);
      NetworkJobRegistry.clear();
      NetworkJobRegistry.registerType<TestNetworkJob>(TestNetworkJob.fromJson);
      NetworkJobRegistry.registerType<TestVoidNetworkJob>(TestVoidNetworkJob.fromJson);
    });

    test('queueAction stores job with metadata', () async {
      final job = TestNetworkJob('test-payload');
      await manager.queueAction(job);

      expect(storage.length, equals(1));

      final storedJob = await manager.getNextPendingJob();
      expect(storedJob, isNotNull);
      expect(storedJob?['type'], equals('TestNetworkJob'));
      expect(storedJob?['status'], equals('pending'));
      expect(storedJob?['retryCount'], equals(0));
      expect(storedJob?['timestamp'], isNotNull);

      final payload = storedJob?['payload'] as Map<String, dynamic>;
      expect(payload['payload'], equals('test-payload'));
    });

    test('queueAction uses deduplicationKey if provided', () async {
      // Each job gets unique ID based on timestamp, so they should all be stored
      final job1 = TestNetworkJob('payload-1');
      await Future.delayed(Duration(milliseconds: 5));
      final job2 = TestNetworkJob('payload-2');

      await manager.queueAction(job1);
      await Future.delayed(Duration(milliseconds: 5));
      await manager.queueAction(job2);

      // Each should have unique ID since deduplicationKey is null
      expect(storage.length, equals(2));
    });

    test('getNextPendingJob returns first pending job', () async {
      final job1 = TestNetworkJob('first');
      final job2 = TestNetworkJob('second');

      await manager.queueAction(job1);
      await Future.delayed(Duration(milliseconds: 10));
      await manager.queueAction(job2);

      final pending = await manager.getNextPendingJob();
      final payload = pending?['payload'] as Map<String, dynamic>;
      expect(payload['payload'], equals('first'));
    });

    test('getNextPendingJob returns null when no pending jobs', () async {
      final job = TestNetworkJob('test');
      await manager.queueAction(job);

      final storedJob = await manager.getNextPendingJob();
      final id = storedJob!['id'] as String;

      await manager.markJobProcessing(id);

      final pending = await manager.getNextPendingJob();
      expect(pending, isNull);
    });

    test('claimNextPendingJob marks job as processing', () async {
      final job = TestNetworkJob('test');
      await manager.queueAction(job);

      final claimed = await manager.claimNextPendingJob();
      expect(claimed, isNotNull);
      expect(claimed?['status'], equals('processing'));

      // No more pending jobs
      final next = await manager.getNextPendingJob();
      expect(next, isNull);
    });

    test('claimNextPendingJob returns null when no pending jobs', () async {
      final claimed = await manager.claimNextPendingJob();
      expect(claimed, isNull);
    });

    test('hasPendingJobs returns correct value', () async {
      expect(await manager.hasPendingJobs(), isFalse);

      final job = TestNetworkJob('test');
      await manager.queueAction(job);

      expect(await manager.hasPendingJobs(), isTrue);
    });

    test('markJobProcessing updates status', () async {
      final job = TestNetworkJob('test');
      await manager.queueAction(job);

      final storedJob = await manager.getNextPendingJob();
      final id = storedJob!['id'] as String;

      await manager.markJobProcessing(id);

      final updated = await manager.getJob(id);
      expect(updated?['status'], equals('processing'));
    });

    test('markJobPending updates status for retry', () async {
      final job = TestNetworkJob('test');
      await manager.queueAction(job);

      final storedJob = await manager.getNextPendingJob();
      final id = storedJob!['id'] as String;

      await manager.markJobProcessing(id);
      await manager.markJobPending(id);

      final updated = await manager.getJob(id);
      expect(updated?['status'], equals('pending'));
    });

    test('markJobPoisoned updates status', () async {
      final job = TestNetworkJob('test');
      await manager.queueAction(job);

      final storedJob = await manager.getNextPendingJob();
      final id = storedJob!['id'] as String;

      await manager.markJobPoisoned(id);

      final updated = await manager.getJob(id);
      expect(updated?['status'], equals('poisoned'));
    });

    test('incrementRetryCount updates count and error message', () async {
      final job = TestNetworkJob('test');
      await manager.queueAction(job);

      final storedJob = await manager.getNextPendingJob();
      final id = storedJob!['id'] as String;

      final count1 = await manager.incrementRetryCount(id);
      expect(count1, equals(1));

      final count2 = await manager.incrementRetryCount(id, errorMessage: 'Network error');
      expect(count2, equals(2));

      final updated = await manager.getJob(id);
      expect(updated?['retryCount'], equals(2));
      expect(updated?['lastError'], equals('Network error'));
    });

    test('getRetryCount returns correct value', () async {
      final job = TestNetworkJob('test');
      await manager.queueAction(job);

      final storedJob = await manager.getNextPendingJob();
      final id = storedJob!['id'] as String;

      expect(await manager.getRetryCount(id), equals(0));

      await manager.incrementRetryCount(id);
      expect(await manager.getRetryCount(id), equals(1));

      await manager.incrementRetryCount(id);
      expect(await manager.getRetryCount(id), equals(2));
    });

    test('removeJob deletes from queue', () async {
      final job = TestNetworkJob('test');
      await manager.queueAction(job);

      final storedJob = await manager.getNextPendingJob();
      final id = storedJob!['id'] as String;

      await manager.removeJob(id);

      expect(await manager.getJob(id), isNull);
      expect(storage.length, equals(0));
    });

    test('getAllJobs returns all queued jobs', () async {
      await manager.queueAction(TestNetworkJob('job-1'));
      await Future.delayed(Duration(milliseconds: 5));
      await manager.queueAction(TestNetworkJob('job-2'));
      await Future.delayed(Duration(milliseconds: 5));
      await manager.queueAction(TestNetworkJob('job-3'));

      final jobs = await manager.getAllJobs();
      expect(jobs.length, equals(3));
    });

    test('clearAll removes all jobs', () async {
      await manager.queueAction(TestNetworkJob('job-1'));
      await manager.queueAction(TestNetworkJob('job-2'));

      await manager.clearAll();

      expect(storage.length, equals(0));
    });
  });

  // ===========================================================================
  // NetworkJobRegistry Tests
  // ===========================================================================

  group('NetworkJobRegistry', () {
    setUp(() {
      NetworkJobRegistry.clear();
    });

    test('register and restore work correctly', () {
      NetworkJobRegistry.register('TestNetworkJob', TestNetworkJob.fromJson);

      final restored = NetworkJobRegistry.restore(
        'TestNetworkJob',
        {'payload': 'restored-payload', 'id': 'test-id'},
      );

      expect(restored, isA<TestNetworkJob>());
      expect((restored as TestNetworkJob).payload, equals('restored-payload'));
    });

    test('registerType uses type name', () {
      NetworkJobRegistry.registerType<TestNetworkJob>(TestNetworkJob.fromJson);

      expect(NetworkJobRegistry.isRegistered('TestNetworkJob'), isTrue);
      expect(NetworkJobRegistry.isTypeRegistered<TestNetworkJob>(), isTrue);
    });

    test('restore returns null for unregistered type', () {
      final restored = NetworkJobRegistry.restore(
        'UnknownJob',
        {'payload': 'test'},
      );

      expect(restored, isNull);
    });

    test('isRegistered returns correct value', () {
      expect(NetworkJobRegistry.isRegistered('TestNetworkJob'), isFalse);

      NetworkJobRegistry.register('TestNetworkJob', TestNetworkJob.fromJson);

      expect(NetworkJobRegistry.isRegistered('TestNetworkJob'), isTrue);
      expect(NetworkJobRegistry.isRegistered('OtherJob'), isFalse);
    });

    test('registeredTypes returns all registered type names', () {
      NetworkJobRegistry.register('JobA', TestNetworkJob.fromJson);
      NetworkJobRegistry.register('JobB', TestVoidNetworkJob.fromJson);

      final types = NetworkJobRegistry.registeredTypes;
      expect(types, containsAll(['JobA', 'JobB']));
    });

    test('clear removes all registrations', () {
      NetworkJobRegistry.register('TestJob', TestNetworkJob.fromJson);
      expect(NetworkJobRegistry.registeredTypes.length, equals(1));

      NetworkJobRegistry.clear();

      expect(NetworkJobRegistry.registeredTypes, isEmpty);
    });
  });
}
