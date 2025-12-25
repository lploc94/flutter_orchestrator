import 'dart:async';
import '../../models/network_action.dart';
import '../../models/job.dart';

/// Job status in the network queue.
enum NetworkJobStatus {
  /// Waiting to be processed.
  pending,

  /// Currently being processed.
  processing,

  /// Failed permanently (poison pill).
  poisoned,
}

/// Interface for persisting network jobs.
/// Implementations can use Hive, SharedPreferences, Isar, or raw Files.
abstract class NetworkQueueStorage {
  /// Save a job to persistence.
  Future<void> saveJob(String id, Map<String, dynamic> data);

  /// Remove a job from persistence.
  Future<void> removeJob(String id);

  /// Get a single job by ID.
  Future<Map<String, dynamic>?> getJob(String id);

  /// Get all stored jobs, sorted by timestamp (FIFO).
  Future<List<Map<String, dynamic>>> getAllJobs();

  /// Update specific fields of a job.
  Future<void> updateJob(String id, Map<String, dynamic> updates);

  /// Clear all jobs (for debugging/reset).
  Future<void> clearAll();
}

/// Interface for handling file safety operations (Safe Copy Strategy).
/// Since `orchestrator_core` is pure Dart, the actual path manipulation
/// relying on `path_provider` (Flutter) must be injected via this delegate.
abstract class FileSafetyDelegate {
  /// Scans the [jobData] for potential temporary file paths, copies them to
  /// a safe persistent location, and returns a modified data map with safe paths.
  Future<Map<String, dynamic>> secureFiles(Map<String, dynamic> jobData);

  /// Cleans up safe files associated with a job after it completes successfully.
  Future<void> cleanupFiles(Map<String, dynamic> jobData);
}

/// Simple async lock to prevent concurrent access to critical sections.
/// FIX WARNING #13: Prevents race conditions in job processing.
class _AsyncLock {
  Completer<void>? _completer;

  /// Acquires the lock. If already locked, waits until released.
  Future<void> acquire() async {
    while (_completer != null) {
      await _completer!.future;
    }
    _completer = Completer<void>();
  }

  /// Releases the lock.
  void release() {
    final completer = _completer;
    _completer = null;
    completer?.complete();
  }
}

/// Manages the queue of network actions.
///
/// Responsibilities:
/// - Queue actions when offline
/// - Persist actions to storage
/// - Provide API for Dispatcher to process queue
/// - Track retry counts and job status
class NetworkQueueManager {
  final NetworkQueueStorage storage;
  final FileSafetyDelegate? fileDelegate;
  
  /// FIX WARNING #13: Lock for preventing concurrent job claim
  final _AsyncLock _processingLock = _AsyncLock();

  NetworkQueueManager({
    required this.storage,
    this.fileDelegate,
  });

  /// Queues an action for later execution.
  ///
  /// 1. Secure files (if delegate present).
  /// 2. Wrap with metadata (id, type, status, retryCount).
  /// 3. Persist to storage.
  Future<void> queueAction(NetworkAction action) async {
    Map<String, dynamic> json = action.toJson();

    // 1. Safe Copy Strategy (Protection against OS temp cleanup)
    if (fileDelegate != null) {
      json = await fileDelegate!.secureFiles(json);
    }

    // Use provided key or generate one
    final id = action.deduplicationKey ??
        DateTime.now().millisecondsSinceEpoch.toString();

    // Wrap with metadata
    final wrapper = {
      'id': id,
      'type': action.runtimeType.toString(),
      'payload': json,
      'timestamp': DateTime.now().toIso8601String(),
      'status': NetworkJobStatus.pending.name,
      'retryCount': 0,
      'lastError': null,
    };

    await storage.saveJob(id, wrapper);
  }

  /// Get next job with status 'pending', sorted by timestamp (FIFO).
  Future<Map<String, dynamic>?> getNextPendingJob() async {
    final jobs = await storage.getAllJobs();
    for (final job in jobs) {
      if (job['status'] == NetworkJobStatus.pending.name) {
        return job;
      }
    }
    return null;
  }

  /// FIX WARNING #13: Atomically claim the next pending job.
  /// This prevents race conditions where multiple callers could claim the same job.
  /// Returns the job data if successfully claimed, null if no pending jobs.
  Future<Map<String, dynamic>?> claimNextPendingJob() async {
    await _processingLock.acquire();
    try {
      final job = await getNextPendingJob();
      if (job == null) return null;
      
      final id = job['id'] as String;
      
      // Double-check the job is still pending (might have changed)
      final freshJob = await storage.getJob(id);
      if (freshJob == null || freshJob['status'] != NetworkJobStatus.pending.name) {
        return null;
      }
      
      // Mark as processing atomically within the lock
      await storage.updateJob(id, {'status': NetworkJobStatus.processing.name});
      
      // Return fresh data with updated status
      return {...freshJob, 'status': NetworkJobStatus.processing.name};
    } finally {
      _processingLock.release();
    }
  }

  /// Get a specific job by ID.
  Future<Map<String, dynamic>?> getJob(String id) async {
    return await storage.getJob(id);
  }

  /// Check if queue has any pending jobs.
  Future<bool> hasPendingJobs() async {
    final next = await getNextPendingJob();
    return next != null;
  }

  /// Mark job as currently processing.
  Future<void> markJobProcessing(String id) async {
    await storage.updateJob(id, {'status': NetworkJobStatus.processing.name});
  }

  /// Mark job as pending (for retry).
  Future<void> markJobPending(String id) async {
    await storage.updateJob(id, {'status': NetworkJobStatus.pending.name});
  }

  /// Mark job as poisoned (will be removed).
  Future<void> markJobPoisoned(String id) async {
    await storage.updateJob(id, {'status': NetworkJobStatus.poisoned.name});
  }

  /// Increment retry count and return new value.
  Future<int> incrementRetryCount(String id, {String? errorMessage}) async {
    final job = await storage.getJob(id);
    final currentCount = (job?['retryCount'] as int?) ?? 0;
    final newCount = currentCount + 1;
    await storage.updateJob(id, {
      'retryCount': newCount,
      'lastError': errorMessage,
    });
    return newCount;
  }

  /// Get the retry count for a job.
  Future<int> getRetryCount(String id) async {
    final job = await storage.getJob(id);
    return (job?['retryCount'] as int?) ?? 0;
  }

  /// Remove a job from the queue.
  Future<void> removeJob(String id) async {
    await storage.removeJob(id);
  }

  /// Get all jobs (for debugging/testing).
  Future<List<Map<String, dynamic>>> getAllJobs() async {
    return await storage.getAllJobs();
  }

  /// Clear all jobs (for testing/reset).
  Future<void> clearAll() async {
    await storage.clearAll();
  }
}

/// Global registry for network job factories.
/// Register job types here so they can be deserialized from storage.
class NetworkJobRegistry {
  static final Map<String, BaseJob Function(Map<String, dynamic>)> _factories =
      {};

  /// Register a factory for a job type.
  /// [type] is the class name (String).
  /// [factory] is the fromJson method.
  static void register(
    String type,
    BaseJob Function(Map<String, dynamic>) factory,
  ) {
    _factories[type] = factory;
  }

  /// Reconstruct a job from JSON + Type.
  static BaseJob? restore(String type, Map<String, dynamic> json) {
    final factory = _factories[type];
    if (factory == null) return null;
    return factory(json);
  }

  /// Check if a type is registered.
  static bool isRegistered(String type) => _factories.containsKey(type);

  /// Clear all factories (for testing).
  static void clear() => _factories.clear();
}
