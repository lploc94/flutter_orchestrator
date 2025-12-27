import 'dart:async';

// --- Cleanup Policy ---

/// Configuration for automatic cleanup behavior.
///
/// Provides presets for common use cases:
/// - [defaultPolicy]: Balanced settings for most apps.
/// - [aggressive]: Minimal resource usage, frequent cleanup.
/// - [conservative]: Maximum caching, infrequent cleanup.
class CleanupPolicy {
  /// Maximum age of files before cleanup (null = never cleanup by age).
  final Duration? maxFileAge;

  /// Maximum number of cache entries (0 = unlimited).
  final int maxCacheEntries;

  /// Interval between automatic cleanup runs (null = disabled).
  final Duration? cleanupInterval;

  /// Enable/disable automatic periodic cleanup.
  final bool autoCleanup;

  const CleanupPolicy({
    this.maxFileAge = const Duration(days: 7),
    this.maxCacheEntries = 1000,
    this.cleanupInterval = const Duration(hours: 1),
    this.autoCleanup = true,
  });

  /// Default balanced policy.
  static const CleanupPolicy defaultPolicy = CleanupPolicy();

  /// Aggressive cleanup: Minimize resource usage.
  static const CleanupPolicy aggressive = CleanupPolicy(
    maxFileAge: Duration(days: 1),
    maxCacheEntries: 100,
    cleanupInterval: Duration(minutes: 15),
  );

  /// Conservative cleanup: Maximum caching.
  static const CleanupPolicy conservative = CleanupPolicy(
    maxFileAge: Duration(days: 30),
    maxCacheEntries: 5000,
    cleanupInterval: Duration(hours: 24),
  );

  /// No automatic cleanup (manual only).
  static const CleanupPolicy manual = CleanupPolicy(
    autoCleanup: false,
    cleanupInterval: null,
  );

  @override
  String toString() => 'CleanupPolicy('
      'maxFileAge: $maxFileAge, '
      'maxCacheEntries: $maxCacheEntries, '
      'cleanupInterval: $cleanupInterval, '
      'autoCleanup: $autoCleanup)';
}

// --- Cleanup Report ---

/// Report of a cleanup operation.
class CleanupReport {
  /// Number of cache entries removed.
  final int cacheEntriesRemoved;

  /// Number of files removed.
  final int filesRemoved;

  /// Total bytes freed from file cleanup.
  final int bytesFreed;

  /// Duration of the cleanup operation.
  final Duration duration;

  /// Timestamp when cleanup completed.
  final DateTime timestamp;

  const CleanupReport({
    required this.cacheEntriesRemoved,
    required this.filesRemoved,
    required this.bytesFreed,
    required this.duration,
    required this.timestamp,
  });

  /// Empty report (no cleanup performed).
  static final CleanupReport empty = CleanupReport(
    cacheEntriesRemoved: 0,
    filesRemoved: 0,
    bytesFreed: 0,
    duration: Duration.zero,
    timestamp: DateTime.now(),
  );

  @override
  String toString() => 'CleanupReport('
      'cache: $cacheEntriesRemoved entries, '
      'files: $filesRemoved ($bytesFreed bytes), '
      'took: ${duration.inMilliseconds}ms)';
}

// --- Resource Stats ---

/// Current resource usage statistics.
class ResourceStats {
  /// Number of entries in cache.
  final int cacheEntryCount;

  /// Maximum allowed cache entries (0 = unlimited).
  final int cacheMaxEntries;

  /// Number of files in offline storage.
  final int fileCount;

  /// Total size of files in bytes.
  final int fileSizeBytes;

  /// Number of pending jobs in network queue.
  final int pendingJobCount;

  /// Number of poisoned jobs in network queue.
  final int poisonedJobCount;

  const ResourceStats({
    this.cacheEntryCount = 0,
    this.cacheMaxEntries = 0,
    this.fileCount = 0,
    this.fileSizeBytes = 0,
    this.pendingJobCount = 0,
    this.poisonedJobCount = 0,
  });

  /// Cache usage ratio (0.0 to 1.0). Returns 0 if unlimited.
  double get cacheUsageRatio =>
      cacheMaxEntries > 0 ? cacheEntryCount / cacheMaxEntries : 0.0;

  /// Human-readable file size.
  String get fileSizeFormatted {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  String toString() => 'ResourceStats('
      'cache: $cacheEntryCount/$cacheMaxEntries, '
      'files: $fileCount ($fileSizeFormatted), '
      'jobs: $pendingJobCount pending, $poisonedJobCount poisoned)';
}

// --- Cleanup Service Interface ---

/// Interface for cleanup services.
///
/// Core defines the interface; platform packages (e.g., orchestrator_flutter)
/// provide implementations with access to file system and timers.
///
/// Example:
/// ```dart
/// final service = FlutterCleanupService(
///   policy: CleanupPolicy.defaultPolicy,
///   cacheProvider: OrchestratorConfig.cacheProvider,
/// );
///
/// // Manual cleanup
/// final report = await service.runCleanup();
/// print('Freed ${report.bytesFreed} bytes');
///
/// // Get stats
/// final stats = await service.getStats();
/// print('Cache usage: ${(stats.cacheUsageRatio * 100).toStringAsFixed(1)}%');
/// ```
abstract class CleanupService {
  /// Current cleanup policy.
  CleanupPolicy get policy;

  /// Run cleanup based on policy.
  ///
  /// Returns a report summarizing what was cleaned.
  Future<CleanupReport> runCleanup();

  /// Force cleanup of cache only.
  Future<int> cleanupCache();

  /// Force cleanup of offline files only.
  Future<({int count, int bytes})> cleanupFiles();

  /// Force cleanup of poisoned network queue jobs.
  Future<int> cleanupNetworkQueue();

  /// Get current resource usage statistics.
  Future<ResourceStats> getStats();

  /// Most recent cleanup report (null if never run).
  CleanupReport? get lastReport;

  /// Stop automatic cleanup and release resources.
  void dispose();
}
