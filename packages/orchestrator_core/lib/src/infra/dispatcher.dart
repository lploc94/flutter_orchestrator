import 'dart:async';
import '../models/job.dart';
import '../base/base_executor.dart';
import '../models/network_action.dart';
import '../models/event.dart';
import '../infra/signal_bus.dart';
import '../utils/logger.dart';
import 'offline/offline_manager.dart';

/// Exception thrown when no executor is found for a job.
class ExecutorNotFoundException implements Exception {
  final Type jobType;
  ExecutorNotFoundException(this.jobType);
  @override
  String toString() =>
      'ExecutorNotFoundException: No executor registered for job type $jobType';
}

/// The Router that connects Orchestrators to Executors.
///
/// Features:
/// - Routes jobs to registered executors
/// - Handles offline NetworkAction jobs automatically
/// - Queues jobs when offline, processes when connectivity restores
/// - Implements poison pill (max retries) to prevent queue blocking
class Dispatcher {
  final Map<Type, BaseExecutor> _registry = {};

  /// Max retry attempts before abandoning a job (poison pill)
  final int maxRetries;

  StreamSubscription? _connectivitySub;
  StreamSubscription? _eventSub;
  bool _isProcessingQueue = false;
  String? _currentSyncJobId;

  // Singleton
  static final Dispatcher _instance = Dispatcher._internal();
  factory Dispatcher() => _instance;

  Dispatcher._internal() : maxRetries = 5 {
    _initConnectivityListener();
  }

  /// Initialize connectivity listener for auto-sync
  void _initConnectivityListener() {
    // Delay to allow OrchestratorConfig to be set up
    Future.delayed(Duration(milliseconds: 100), () {
      try {
        _connectivitySub = OrchestratorConfig
            .connectivityProvider.onConnectivityChanged
            .listen((isConnected) {
          if (isConnected && !_isProcessingQueue) {
            _processOfflineQueue();
          }
        });

        // Listen for job results to know when sync job completes
        _eventSub = SignalBus.instance.stream.listen(_onSyncJobResult);

        // Check initial state
        OrchestratorConfig.connectivityProvider.isConnected.then((connected) {
          if (connected && !_isProcessingQueue) {
            _processOfflineQueue();
          }
        });
      } catch (_) {
        // ConnectivityProvider not configured yet, that's OK
      }
    });
  }

  /// Register an executor for a specific Job Type.
  void register<J extends BaseJob>(BaseExecutor<J> executor) {
    _registry[J] = executor;
  }

  /// Dispatch a job to the subscribed executor.
  /// Returns the Job ID (Correlation ID) immediately.
  String dispatch(BaseJob job) {
    final executor = _registry[job.runtimeType];

    if (executor == null) {
      throw ExecutorNotFoundException(job.runtimeType);
    }

    // Offline Support Logic
    if (job is NetworkAction) {
      _handleNetworkJob(job as NetworkAction, executor);
    } else {
      // Standard Fire-and-forget execution
      executor.execute(job);
    }

    return job.id;
  }

  /// Handle NetworkAction jobs (online/offline logic)
  Future<void> _handleNetworkJob(
    NetworkAction action,
    BaseExecutor executor,
  ) async {
    final job = action as BaseJob;
    final log = OrchestratorConfig.logger;

    try {
      final isConnected =
          await OrchestratorConfig.connectivityProvider.isConnected;

      if (!isConnected) {
        log.info('NetworkAction ${job.id} offline. Queuing...');
        final manager = OrchestratorConfig.networkQueueManager;

        if (manager != null) {
          // 1. Queue it
          await manager.queueAction(action);

          // 2. Create Optimistic Result
          final optimisticResult = action.createOptimisticResult();
          log.info('NetworkAction ${job.id} returning optimistic result.');

          // 3. Emit Events (Started + Fake Success)
          final bus = job.bus ?? SignalBus.instance;
          bus.emit(JobStartedEvent(job.id));
          bus.emit(JobSuccessEvent(job.id, optimisticResult));

          return; // Stop here, do not execute real worker
        } else {
          log.warning(
            'NetworkAction detected but no NetworkQueueManager configured. Executing normally.',
          );
        }
      }

      // Online: Execute normally
      executor.execute(job);
    } catch (e, stack) {
      log.error('Error in Offline Dispatch Logic for ${job.id}', e, stack);
      // Fallback: just execute
      executor.execute(job);
    }
  }

  /// Process the offline queue when connectivity restores
  Future<void> _processOfflineQueue() async {
    final manager = OrchestratorConfig.networkQueueManager;
    if (manager == null) return;
    if (_isProcessingQueue) return;

    final isConnected =
        await OrchestratorConfig.connectivityProvider.isConnected;
    if (!isConnected) return;

    final log = OrchestratorConfig.logger;
    _isProcessingQueue = true;

    try {
      final jobWrapper = await manager.getNextPendingJob();
      if (jobWrapper == null) {
        _isProcessingQueue = false;
        return;
      }

      final jobId = jobWrapper['id'] as String?;
      if (jobId == null) {
        _isProcessingQueue = false;
        return;
      }

      // Mark as processing
      await manager.markJobProcessing(jobId);

      // Restore job from registry
      final type = jobWrapper['type'] as String?;
      final rawPayload = jobWrapper['payload'];
      final payload =
          rawPayload is Map ? Map<String, dynamic>.from(rawPayload) : null;

      if (type == null || payload == null) {
        log.warning('Invalid job data in queue, removing: $jobId');
        await manager.removeJob(jobId);
        _isProcessingQueue = false;
        _processOfflineQueue();
        return;
      }

      final job = NetworkJobRegistry.restore(type, payload);
      if (job == null) {
        log.warning('Unknown job type in queue, removing: $type');
        await manager.removeJob(jobId);
        _isProcessingQueue = false;
        _processOfflineQueue();
        return;
      }

      // Store info for result handling
      _currentSyncJobId = job.id;

      // Find executor and execute
      final executor = _registry[job.runtimeType];
      if (executor != null) {
        log.debug('Syncing offline job: ${job.id}');
        executor.execute(job);
        // Result will come via _onSyncJobResult
      } else {
        log.warning('No executor for queued job: ${job.runtimeType}');
        await manager.removeJob(jobId);
        _finishSyncJob();
        _processOfflineQueue();
      }
    } catch (e, stack) {
      log.error('Error processing offline queue', e, stack);
      _isProcessingQueue = false;
    }
  }

  /// Handle result of a syncing job
  void _onSyncJobResult(BaseEvent event) {
    if (_currentSyncJobId == null) return;
    if (event.correlationId != _currentSyncJobId) return;

    if (event is JobSuccessEvent) {
      _handleSyncSuccess();
    } else if (event is JobFailureEvent) {
      _handleSyncFailure(event.error, event.stackTrace);
    }
  }

  Future<void> _handleSyncSuccess() async {
    final manager = OrchestratorConfig.networkQueueManager;
    if (manager == null || _currentSyncJobId == null) {
      _finishSyncJob();
      return;
    }

    final log = OrchestratorConfig.logger;

    try {
      // Find wrapper by looking up all jobs (we need wrapper ID, not job ID)
      final jobs = await manager.getAllJobs();
      for (final jobWrapper in jobs) {
        if (jobWrapper['status'] == NetworkJobStatus.processing.name) {
          final wrapperId = jobWrapper['id'] as String?;
          if (wrapperId != null) {
            // Cleanup files
            final payload = jobWrapper['payload'];
            if (payload is Map && manager.fileDelegate != null) {
              await manager.fileDelegate!.cleanupFiles(
                Map<String, dynamic>.from(payload),
              );
            }

            // Remove from queue
            await manager.removeJob(wrapperId);
            log.debug('Sync success, removed: $wrapperId');
            break;
          }
        }
      }
    } finally {
      _finishSyncJob();
      _processOfflineQueue(); // Process next
    }
  }

  Future<void> _handleSyncFailure(Object error, StackTrace? stackTrace) async {
    final manager = OrchestratorConfig.networkQueueManager;
    if (manager == null) {
      _finishSyncJob();
      return;
    }

    final log = OrchestratorConfig.logger;

    try {
      // Find the processing job
      final jobs = await manager.getAllJobs();
      for (final jobWrapper in jobs) {
        if (jobWrapper['status'] == NetworkJobStatus.processing.name) {
          final wrapperId = jobWrapper['id'] as String?;
          if (wrapperId != null) {
            final retryCount = await manager.incrementRetryCount(
              wrapperId,
              errorMessage: error.toString(),
            );

            if (retryCount >= maxRetries) {
              // POISON PILL: Abandon this job
              await manager.markJobPoisoned(wrapperId);

              log.warning(
                  'Poison pill: abandoning job after $retryCount retries: $wrapperId');

              SignalBus.instance.emit(NetworkSyncFailureEvent(
                wrapperId,
                error: error,
                stackTrace: stackTrace,
                retryCount: retryCount,
                isPoisoned: true,
              ));

              await manager.removeJob(wrapperId);
            } else {
              // Will retry later
              await manager.markJobPending(wrapperId);

              log.debug(
                  'Sync failed, will retry ($retryCount/$maxRetries): $wrapperId');

              SignalBus.instance.emit(NetworkSyncFailureEvent(
                wrapperId,
                error: error,
                stackTrace: stackTrace,
                retryCount: retryCount,
                isPoisoned: false,
              ));
            }
            break;
          }
        }
      }
    } finally {
      _finishSyncJob();
      // Small delay before retry
      await Future.delayed(Duration(seconds: 2));
      _processOfflineQueue();
    }
  }

  void _finishSyncJob() {
    _currentSyncJobId = null;
    _isProcessingQueue = false;
  }

  /// Stop connectivity listener (for cleanup)
  void dispose() {
    _connectivitySub?.cancel();
    _eventSub?.cancel();
  }

  /// For testing cleanup
  void clear() {
    _registry.clear();
  }
}
