import 'dart:async';
import 'package:orchestrator_core/orchestrator_core.dart';
import 'package:orchestrator_core/src/models/data_strategy.dart';
import 'package:orchestrator_core/src/infra/cache/in_memory_cache_provider.dart';
import 'package:orchestrator_core/src/infra/cache/cache_job_executor.dart';
import 'package:orchestrator_core/src/jobs/invalidate_cache_job.dart';
import 'package:test/test.dart';

// --- Mocks ---

class TestJob extends BaseJob {
  final dynamic result;
  final bool shouldFail;

  TestJob(
    String id, {
    this.result,
    this.shouldFail = false,
    super.strategy, // Converted to super parameter
  }) : super(id: id);
}

class TestExecutor extends BaseExecutor<TestJob> {
  int processCallCount = 0;

  @override
  Future<dynamic> process(TestJob job) async {
    processCallCount++;
    if (job.shouldFail) {
      throw Exception('Worker Failed');
    }
    return job.result;
  }
}

// --- Tests ---

void main() {
  late TestExecutor executor;
  late SignalBus bus;

  setUp(() {
    bus = SignalBus.scoped();
    executor = TestExecutor();

    // Reset configs
    OrchestratorConfig.setCacheProvider(InMemoryCacheProvider());
    OrchestratorConfig.setLogger(ConsoleLogger(minLevel: LogLevel.debug));
  });

  group('Unified Data Flow', () {
    test('TC 1.1: Placeholder + Cache Miss + SWR', () async {
      final job = TestJob(
        'job1',
        result: 'Fresh Data',
        strategy: DataStrategy(
          placeholder: 'Loading...',
          cachePolicy: CachePolicy(key: 'key1'),
        ),
      );
      job.bus = bus;

      final expectation = expectLater(
        bus.stream,
        emitsInOrder([
          isA<JobStartedEvent>(),
          predicate<JobPlaceholderEvent>((e) => e.data == 'Loading...'),
          predicate<JobSuccessEvent>((e) => e.data == 'Fresh Data'),
        ]),
      );

      await executor.execute(job);
      await expectation;

      expect(executor.processCallCount, 1);
      final cached = await OrchestratorConfig.cacheProvider.read('key1');
      expect(cached, 'Fresh Data');
    });

    test('TC 1.2: SWR Hit & Revalidate', () async {
      await OrchestratorConfig.cacheProvider.write('key2', 'Cached Data');

      final job = TestJob(
        'job2',
        result: 'New Data',
        strategy: DataStrategy(
          cachePolicy: CachePolicy(key: 'key2', revalidate: true),
        ),
      );
      job.bus = bus;

      final expectation = expectLater(
        bus.stream,
        emitsInOrder([
          isA<JobStartedEvent>(),
          predicate<JobCacheHitEvent>((e) => e.data == 'Cached Data'),
          predicate<JobSuccessEvent>((e) => e.data == 'New Data'),
        ]),
      );

      await executor.execute(job);
      await expectation;

      expect(executor.processCallCount, 1);
      final cached = await OrchestratorConfig.cacheProvider.read('key2');
      expect(cached, 'New Data');
    });

    test('TC 1.3: Cache First Hit (Stop)', () async {
      await OrchestratorConfig.cacheProvider.write('key3', 'Cached Data');

      final job = TestJob(
        'job3',
        result: 'Should Not Run',
        strategy: DataStrategy(
          cachePolicy: CachePolicy(key: 'key3', revalidate: false),
        ),
      );
      job.bus = bus;

      final expectation = expectLater(
        bus.stream,
        emitsInOrder([
          isA<JobStartedEvent>(),
          predicate<JobCacheHitEvent>((e) => e.data == 'Cached Data'),
          predicate<JobSuccessEvent>((e) => e.data == 'Cached Data'),
        ]),
      );

      await executor.execute(job);
      await expectation;

      expect(executor.processCallCount, 0);
    });

    test('TC 1.4: Force Refresh (Skip Cache)', () async {
      // Setup Cache with old data
      await OrchestratorConfig.cacheProvider.write('key4', 'Cached Data');

      final job = TestJob(
        'job4',
        result: 'Fresh Data',
        strategy: DataStrategy(
          cachePolicy: CachePolicy(
            key: 'key4',
            forceRefresh: true, // Should skip reading 'Cached Data'
          ),
        ),
      );
      job.bus = bus;

      final expectation = expectLater(
        bus.stream,
        emitsInOrder([
          isA<JobStartedEvent>(),
          // NO CacheHit event here
          predicate<JobSuccessEvent>((e) => e.data == 'Fresh Data'),
        ]),
      );

      await executor.execute(job);
      await expectation;

      expect(executor.processCallCount, 1);
      final cached = await OrchestratorConfig.cacheProvider.read('key4');
      expect(cached, 'Fresh Data');
    });

    test('TC 3.1: Worker Failure (Preserve Cache)', () async {
      await OrchestratorConfig.cacheProvider.write('fail_key', 'Old Data');

      final job = TestJob(
        'job_fail',
        shouldFail: true,
        strategy: DataStrategy(
          cachePolicy: CachePolicy(key: 'fail_key'),
        ),
      );
      job.bus = bus;

      final expectation = expectLater(
        bus.stream,
        emitsInOrder([
          isA<JobStartedEvent>(),
          predicate<JobCacheHitEvent>((e) => e.data == 'Old Data'),
          isA<JobFailureEvent>(),
        ]),
      );

      await executor.execute(job);
      await expectation;

      final cached = await OrchestratorConfig.cacheProvider.read('fail_key');
      expect(cached, 'Old Data');
    });

    test('TC 2.1: TTL Boundary', () async {
      await OrchestratorConfig.cacheProvider
          .write('ttl_key', 'Data', ttl: Duration(milliseconds: 100));

      var data = await OrchestratorConfig.cacheProvider.read('ttl_key');
      expect(data, 'Data');

      await Future.delayed(Duration(milliseconds: 150));

      data = await OrchestratorConfig.cacheProvider.read('ttl_key');
      expect(data, isNull);
    });
  });

  // Note: TC 4.1 (Manual Invalidation) is removed as it checks Provider directly.
  // We replace it with TC 5.x checking via CacheJobExecutor.

  group('Cache Job Executor', () {
    late CacheJobExecutor cacheExecutor;

    setUp(() {
      cacheExecutor = CacheJobExecutor();
    });

    test('TC 5.1: Invalidate by Key', () async {
      final provider = OrchestratorConfig.cacheProvider;
      await provider.write('key_to_delete', 'value');
      await provider.write('key_keep', 'value');

      final job = InvalidateCacheJob(key: 'key_to_delete');
      job.bus =
          bus; // Technically cacheExecutor uses bus to emit started/success, but we focus on side-effects here

      await cacheExecutor.execute(job);

      expect(await provider.read('key_to_delete'), isNull);
      expect(await provider.read('key_keep'), 'value');
    });

    test('TC 5.2: Invalidate by Prefix', () async {
      final provider = OrchestratorConfig.cacheProvider;
      await provider.write('prefix_1', 'val');
      await provider.write('prefix_2', 'val');
      await provider.write('other', 'val');

      final job = InvalidateCacheJob(prefix: 'prefix_');
      job.bus = bus;

      await cacheExecutor.execute(job);

      expect(await provider.read('prefix_1'), isNull);
      expect(await provider.read('prefix_2'), isNull);
      expect(await provider.read('other'), 'val');
    });
  });
}
