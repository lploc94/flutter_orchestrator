import 'dart:async';
import '../models/job.dart';
import '../models/job_handle.dart';
import '../models/data_source.dart';
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

  /// Get map of registered executors (JobType Name -> ExecutorType Name)
  Map<String, String> get registeredExecutors {
    return _registry.map((jobType, executor) {
      return MapEntry(jobType.toString(), executor.runtimeType.toString());
    });
  }

  /// Max retry attempts before abandoning a job (poison pill)
  final int maxRetries;

  StreamSubscription? _connectivitySub;
  bool _isProcessingQueue = false;
  String? _currentSyncWrapperId;

  // Singleton
  static final Dispatcher _instance = Dispatcher._internal();
  factory Dispatcher() => _instance;

  Dispatcher._internal() : maxRetries = 5 {
    _initConnectivityListener();
  }

  /// Initialize connectivity listener for auto-sync
  void _initConnectivityListener() {
    Future.delayed(const Duration(milliseconds: 100), () {
      try {
        _connectivitySub = OrchestratorConfig
            .connectivityProvider.onConnectivityChanged
            .listen((isConnected) {
          if (isConnected && !_isProcessingQueue) {
            _processOfflineQueue();
          }
        });

        OrchestratorConfig.connectivityProvider.isConnected.then((connected) {
          if (connected && !_isProcessingQueue) {
            _processOfflineQueue();
          }
        });
      } catch (_) {
        // ConnectivityProvider not configured yet
      }
    });
  }

  /// Register an executor for a specific Job Type.
  void register<J extends EventJob>(BaseExecutor<J> executor) {
    _registry[J] = executor;
  }

  /// Register an executor by runtime type.
  void registerByType(Type jobType, BaseExecutor executor) {
    _registry[jobType] = executor;
  }

  /// Dispatch a job to the subscribed executor.
  ///
  /// Returns the Job ID (Correlation ID) immediately.
  String dispatch(EventJob job, {JobHandle? handle}) {
    final executor = _registry[job.runtimeType];

    if (executor == null) {
      handle?.completeError(ExecutorNotFoundException(job.runtimeType));
      throw ExecutorNotFoundException(job.runtimeType);
    }

    // Offline Support Logic
    if (job is NetworkAction) {
      _handleNetworkJob(job, executor, handle: handle);
    } else {
      executor.execute(job, handle: handle);
    }

    return job.id;
  }

  /// Handle NetworkAction jobs (online/offline logic)
  Future<void> _handleNetworkJob(
    EventJob job,
    BaseExecutor executor, {
    JobHandle? handle,
  }) async {
    final action = job as NetworkAction;
    final log = OrchestratorConfig.logger;

    try {
      final isConnected =
          await OrchestratorConfig.connectivityProvider.isConnected;

      if (!isConnected) {
        log.info('NetworkAction ${job.id} offline. Queuing...');
        final manager = OrchestratorConfig.networkQueueManager;

        if (manager != null) {
          // Create Optimistic Result first (before queueing)
          final optimisticResult = action.createOptimisticResult();

          try {
            await manager.queueAction(
              action,
              optimisticResult: optimisticResult,
            );
          } catch (queueError, queueStack) {
            log.error(
              'NetworkAction ${job.id} failed to queue. Falling back to normal execution.',
              queueError,
              queueStack,
            );
            executor.execute(job, handle: handle);
            return;
          }

          log.info('NetworkAction ${job.id} returning optimistic result.');

          // Complete handle with optimistic result
          handle?.complete(optimisticResult, DataSource.optimistic);

          // Emit domain event for optimistic result with DataSource.optimistic
          final event = job.createEvent(optimisticResult, DataSource.optimistic);
          final bus = job.bus ?? SignalBus.instance;
          bus.emit(event);

          return;
        } else {
          log.warning(
            'NetworkAction detected but no NetworkQueueManager configured.',
          );
        }
      }

      // Online: Execute normally
      executor.execute(job, handle: handle);
    } catch (e, stack) {
      log.error('Error in Offline Dispatch Logic for ${job.id}', e, stack);
      executor.execute(job, handle: handle);
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
      final jobWrapper = await manager.claimNextPendingJob();
      if (jobWrapper == null) {
        _isProcessingQueue = false;
        return;
      }

      final jobId = jobWrapper['id'] as String?;
      if (jobId == null) {
        _isProcessingQueue = false;
        return;
      }

      _currentSyncWrapperId = jobId;

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

      final executor = _registry[job.runtimeType];
      if (executor != null) {
        log.debug('Syncing offline job: ${job.id}');

        // Create handle to track completion
        final syncHandle = JobHandle<dynamic>(job.id);

        // Execute and track via handle
        executor.execute(job, handle: syncHandle);

        // Wait for completion
        syncHandle.future.then((_) {
          _handleSyncSuccess();
        }).catchError((error, stackTrace) {
          _handleSyncFailure(error, stackTrace);
        });
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

  Future<void> _handleSyncSuccess() async {
    final manager = OrchestratorConfig.networkQueueManager;
    if (manager == null || _currentSyncWrapperId == null) {
      _finishSyncJob();
      return;
    }

    final log = OrchestratorConfig.logger;
    final wrapperId = _currentSyncWrapperId!;

    try {
      final jobWrapper = await manager.getJob(wrapperId);
      if (jobWrapper != null) {
        final payload = jobWrapper['payload'];
        if (payload is Map && manager.fileDelegate != null) {
          await manager.fileDelegate!.cleanupFiles(
            Map<String, dynamic>.from(payload),
          );
        }
        await manager.removeJob(wrapperId);
        log.debug('Sync success, removed: $wrapperId');
      }
    } finally {
      _finishSyncJob();
      _processOfflineQueue();
    }
  }

  Future<void> _handleSyncFailure(Object error, StackTrace? stackTrace) async {
    final manager = OrchestratorConfig.networkQueueManager;
    if (manager == null || _currentSyncWrapperId == null) {
      _finishSyncJob();
      return;
    }

    final log = OrchestratorConfig.logger;
    final wrapperId = _currentSyncWrapperId!;

    try {
      // Get job wrapper to extract original job ID and metadata
      final jobWrapper = await manager.getJob(wrapperId);
      final originalJobId =
          jobWrapper?['originalJobId'] as String? ?? wrapperId;
      final type = jobWrapper?['type'] as String?;
      final rawPayload = jobWrapper?['payload'];
      final payload =
          rawPayload is Map ? Map<String, dynamic>.from(rawPayload) : null;
      final optimisticResult = jobWrapper?['optimisticResult'];

      final retryCount = await manager.incrementRetryCount(
        wrapperId,
        errorMessage: error.toString(),
      );

      if (retryCount >= maxRetries) {
        await manager.markJobPoisoned(wrapperId);

        log.warning(
            'Poison pill: abandoning job after $retryCount retries: $wrapperId');

        // Emit NetworkSyncFailureEvent with ORIGINAL job ID
        SignalBus.instance.emit(NetworkSyncFailureEvent(
          originalJobId,
          error: error,
          stackTrace: stackTrace,
          retryCount: retryCount,
          isPoisoned: true,
        ));

        // Emit domain failure event if job supports it
        if (type != null && payload != null) {
          final job = NetworkJobRegistry.restore(type, payload);
          if (job != null) {
            final failureEvent = job.createFailureEvent(error, optimisticResult);
            if (failureEvent != null) {
              log.debug('Emitting failure event: ${failureEvent.runtimeType}');
              SignalBus.instance.emit(failureEvent);
            }
          }
        }

        await manager.removeJob(wrapperId);
      } else {
        await manager.markJobPending(wrapperId);

        log.debug(
            'Sync failed, will retry ($retryCount/$maxRetries): $wrapperId');

        // Emit NetworkSyncFailureEvent with ORIGINAL job ID
        SignalBus.instance.emit(NetworkSyncFailureEvent(
          originalJobId,
          error: error,
          stackTrace: stackTrace,
          retryCount: retryCount,
          isPoisoned: false,
        ));
      }
    } finally {
      _finishSyncJob();
      await Future.delayed(const Duration(seconds: 2));
      _processOfflineQueue();
    }
  }

  void _finishSyncJob() {
    _currentSyncWrapperId = null;
    _isProcessingQueue = false;
  }

  /// Manually trigger processing of the offline queue.
  ///
  /// Call this on app startup to sync any pending jobs from previous sessions.
  /// The method is safe to call multiple times - it will not start processing
  /// if already in progress or if device is offline.
  ///
  /// Example:
  /// ```dart
  /// void main() async {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///
  ///   // Configure orchestrator...
  ///   OrchestratorConfig.setNetworkQueueManager(manager);
  ///   OrchestratorConfig.setConnectivityProvider(provider);
  ///
  ///   // Process any queued jobs from previous session
  ///   await Dispatcher().processQueuedJobs();
  ///
  ///   runApp(MyApp());
  /// }
  /// ```
  Future<void> processQueuedJobs() async {
    if (_isProcessingQueue) return;
    await _processOfflineQueue();
  }

  void dispose() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _isProcessingQueue = false;
    _currentSyncWrapperId = null;
  }

  void clear() {
    _registry.clear();
  }

  void resetForTesting() {
    clear();
    dispose();
    _initConnectivityListener();
  }
}
