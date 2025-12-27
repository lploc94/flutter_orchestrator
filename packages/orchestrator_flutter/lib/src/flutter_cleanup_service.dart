import 'dart:async';
import 'package:orchestrator_core/orchestrator_core.dart';

import 'flutter_file_safety.dart';

/// Flutter implementation of [CleanupService].
///
/// Features:
/// - Periodic automatic cleanup (Timer-based).
/// - Cache eviction via [InMemoryCacheProvider].
/// - File cleanup via [FlutterFileSafety].
/// - Poisoned job cleanup via [NetworkQueueManager].
///
/// Example:
/// ```dart
/// final cleanupService = FlutterCleanupService(
///   policy: CleanupPolicy.defaultPolicy,
///   cacheProvider: OrchestratorConfig.cacheProvider,
///   fileSafety: FlutterFileSafety(),
/// );
///
/// // Start automatic cleanup (based on policy.autoCleanup)
/// // Manual cleanup:
/// final report = await cleanupService.runCleanup();
/// print(report);
/// ```
class FlutterCleanupService implements CleanupService {
  @override
  final CleanupPolicy policy;

  final CacheProvider _cacheProvider;
  final FlutterFileSafety? _fileSafety;
  final NetworkQueueManager? _networkQueueManager;

  Timer? _periodicTimer;
  CleanupReport? _lastReport;

  /// Creates a FlutterCleanupService.
  ///
  /// [policy]: Cleanup configuration (defaults to [CleanupPolicy.defaultPolicy]).
  /// [cacheProvider]: Required - the cache to manage.
  /// [fileSafety]: Optional - for file cleanup.
  /// [networkQueueManager]: Optional - for poisoned job cleanup.
  FlutterCleanupService({
    CleanupPolicy? policy,
    required CacheProvider cacheProvider,
    FlutterFileSafety? fileSafety,
    NetworkQueueManager? networkQueueManager,
  })  : policy = policy ?? CleanupPolicy.defaultPolicy,
        _cacheProvider = cacheProvider,
        _fileSafety = fileSafety,
        _networkQueueManager = networkQueueManager {
    if (this.policy.autoCleanup && this.policy.cleanupInterval != null) {
      _startPeriodicCleanup();
    }
  }

  void _startPeriodicCleanup() {
    _periodicTimer = Timer.periodic(
      policy.cleanupInterval!,
      (_) => runCleanup(),
    );
  }

  @override
  CleanupReport? get lastReport => _lastReport;

  @override
  Future<CleanupReport> runCleanup() async {
    final stopwatch = Stopwatch()..start();

    // 1. Cache cleanup
    final cacheRemoved = await cleanupCache();

    // 2. File cleanup
    final fileResult = await cleanupFiles();

    // 3. Network queue cleanup
    await cleanupNetworkQueue();

    stopwatch.stop();

    _lastReport = CleanupReport(
      cacheEntriesRemoved: cacheRemoved,
      filesRemoved: fileResult.count,
      bytesFreed: fileResult.bytes,
      duration: stopwatch.elapsed,
      timestamp: DateTime.now(),
    );

    OrchestratorConfig.logger.debug(
      '[CleanupService] $_lastReport',
    );

    return _lastReport!;
  }

  @override
  Future<int> cleanupCache() async {
    if (_cacheProvider is InMemoryCacheProvider) {
      return (await (_cacheProvider as InMemoryCacheProvider).evictExpired());
    }
    return 0;
  }

  @override
  Future<({int count, int bytes})> cleanupFiles() async {
    if (_fileSafety != null && policy.maxFileAge != null) {
      return _fileSafety!.cleanupOldFiles(policy.maxFileAge!);
    }
    return (count: 0, bytes: 0);
  }

  @override
  Future<int> cleanupNetworkQueue() async {
    if (_networkQueueManager == null) return 0;

    // Get all jobs and remove poisoned ones
    final allJobs = await _networkQueueManager!.getAllJobs();
    int removed = 0;

    for (final job in allJobs) {
      final status = job['status'] as String?;
      if (status == 'poisoned') {
        final id = job['id'] as String?;
        if (id != null) {
          await _networkQueueManager!.removeJob(id);
          removed++;
        }
      }
    }

    return removed;
  }

  @override
  Future<ResourceStats> getStats() async {
    // Cache stats
    int cacheEntryCount = 0;
    int cacheMaxEntries = 0;
    if (_cacheProvider is InMemoryCacheProvider) {
      final stats = (_cacheProvider as InMemoryCacheProvider).getStats();
      cacheEntryCount = stats.entryCount;
      cacheMaxEntries = stats.maxEntries;
    }

    // File stats
    int fileCount = 0;
    int fileSizeBytes = 0;
    if (_fileSafety != null) {
      final usage = await _fileSafety!.getStorageUsage();
      fileCount = usage.fileCount;
      fileSizeBytes = usage.totalBytes;
    }

    // Network queue stats
    int pendingJobCount = 0;
    int poisonedJobCount = 0;
    if (_networkQueueManager != null) {
      final allJobs = await _networkQueueManager!.getAllJobs();
      for (final job in allJobs) {
        final status = job['status'] as String?;
        if (status == 'pending') pendingJobCount++;
        if (status == 'poisoned') poisonedJobCount++;
      }
    }

    return ResourceStats(
      cacheEntryCount: cacheEntryCount,
      cacheMaxEntries: cacheMaxEntries,
      fileCount: fileCount,
      fileSizeBytes: fileSizeBytes,
      pendingJobCount: pendingJobCount,
      poisonedJobCount: poisonedJobCount,
    );
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }
}
