import 'dart:async';
import '../infra/signal_bus.dart';
import '../infra/orchestrator_observer.dart';
import '../models/job.dart';
import '../models/job_handle.dart';
import '../models/data_source.dart';
import '../models/event.dart';
import '../utils/cancellation_token.dart';
import '../utils/logger.dart';
import '../infra/cache/cache_provider.dart';

/// Abstract Worker that performs actual business logic.
///
/// Features:
/// - Error Boundary (auto-catch exceptions)
/// - Timeout handling
/// - Retry with exponential backoff
/// - Cancellation support
/// - Progress reporting via JobHandle
/// - Built-in caching (Cache-First and SWR patterns)
/// - Domain event emission via EventJob
///
/// ## Usage
///
/// ```dart
/// class LoadUsersExecutor extends BaseExecutor<LoadUsersJob> {
///   @override
///   Future<List<User>> process(LoadUsersJob job) async {
///     // Your business logic here
///     return await userRepository.getAll();
///   }
/// }
/// ```
///
/// ## Progress Reporting
///
/// ```dart
/// @override
/// Future<void> process(UploadFilesJob job) async {
///   for (int i = 0; i < job.files.length; i++) {
///     await uploadFile(job.files[i]);
///     reportProgress(job.id, current: i + 1, total: job.files.length);
///   }
/// }
/// ```
abstract class BaseExecutor<T extends EventJob> {
  /// Map tracking active jobs to their respective buses (Scoped or Global).
  final Map<String, SignalBus> _activeBus = {};

  /// Map tracking active job handles for progress reporting.
  final Map<String, JobHandle> _activeHandles = {};

  /// Cache Provider (Shared Singleton from Config).
  CacheProvider get cacheProvider => OrchestratorConfig.cacheProvider;

  /// Global fallback.
  SignalBus get _globalBus => SignalBus.instance;

  /// The main entry point for processing.
  /// Subclasses implement this with actual logic.
  ///
  /// Return the result or throw an exception. The framework handles
  /// event emission, error handling, and JobHandle completion.
  Future<dynamic> process(T job);

  /// Entry point called by Dispatcher.
  /// Wraps [process] with error boundary, timeout, retry, and cancellation.
  Future<void> execute(T job, {JobHandle? handle}) async {
    final log = OrchestratorConfig.logger;
    log.debug('Executor starting job: ${job.id}');

    // Notify observer
    OrchestratorObserver.instance?.onJobStart(job);

    // Determine target bus for this job
    final bus = job.bus ?? _globalBus;
    _activeBus[job.id] = bus;
    if (handle != null) {
      _activeHandles[job.id] = handle;
    }

    try {
      await _executeEventJob(job, handle);
    } on CancelledException catch (e, stack) {
      log.info('Job ${job.id} was cancelled');
      OrchestratorObserver.instance?.onJobError(job, e, stack);
      handle?.completeError(e, stack);
    } catch (e, stack) {
      log.error('Job ${job.id} failed', e, stack);
      OrchestratorObserver.instance?.onJobError(job, e, stack);
      handle?.completeError(e, stack);
    } finally {
      // Cleanup
      job.cancellationToken?.clearListeners();
      _activeBus.remove(job.id);
      _activeHandles.remove(job.id);

      // Small delay to allow progress events to be delivered
      await Future.delayed(const Duration(milliseconds: 10));
      handle?.dispose();
    }
  }

  /// Execute an EventJob with domain event emission.
  ///
  /// Flow:
  /// 1. Check cache (if cacheKey defined)
  /// 2. If cache hit: emit domain event, complete handle, optionally revalidate
  /// 3. Execute worker
  /// 4. Write to cache (if cacheKey defined)
  /// 5. Emit domain event
  /// 6. Complete handle (if not already completed by cache)
  Future<void> _executeEventJob(T job, JobHandle? handle) async {
    final log = OrchestratorConfig.logger;
    final bus = job.bus ?? _globalBus;
    final cacheKey = job.cacheKey;

    // Check cancellation before starting
    job.cancellationToken?.throwIfCancelled();

    // 1. Check cache
    if (cacheKey != null) {
      dynamic cached;
      try {
        cached = await cacheProvider.read(cacheKey);
      } catch (e, stack) {
        log.warning('Job ${job.id} cache read failed: $e');
        OrchestratorObserver.instance?.onJobError(job, e, stack);
        cached = null;
      }

      if (cached != null) {
        log.debug('Job ${job.id} cache hit: $cacheKey');

        // Create and emit domain event with cached source
        final event = job.createEvent(cached, DataSource.cached);
        bus.emit(event);
        OrchestratorObserver.instance?.onEvent(event);
        OrchestratorObserver.instance?.onJobSuccess(job, cached, DataSource.cached);

        // Complete handle with cached data
        handle?.complete(cached, DataSource.cached);

        // Cache-First: stop here
        if (!job.revalidate) {
          log.debug('Job ${job.id} cache-first strategy. Done.');
          return;
        }
        // SWR: continue to worker
        log.debug('Job ${job.id} SWR: revalidating in background');
      }
    }

    // 2. Execute worker with retry/timeout support
    final result = await _executeWithFeatures(job);

    // Check cancellation after completion
    if (job.cancellationToken?.isCancelled == true) {
      log.debug('Job ${job.id} cancelled after execution');
      return;
    }

    // 3. Write to cache
    if (cacheKey != null) {
      try {
        log.debug('Job ${job.id} writing to cache: $cacheKey');
        await cacheProvider.write(cacheKey, result, ttl: job.cacheTtl);
      } catch (e, stack) {
        log.warning('Job ${job.id} cache write failed: $e');
        OrchestratorObserver.instance?.onJobError(job, e, stack);
      }
    }

    // 4. Create and emit domain event with fresh source
    final event = job.createEvent(result, DataSource.fresh);
    bus.emit(event);
    OrchestratorObserver.instance?.onEvent(event);
    OrchestratorObserver.instance?.onJobSuccess(job, result, DataSource.fresh);

    log.debug('Job ${job.id} completed successfully');

    // 5. Complete handle
    handle?.complete(result, DataSource.fresh);
  }

  /// Execute job with retry and timeout features.
  Future<dynamic> _executeWithFeatures(T job) async {
    Future<dynamic> executionFuture;

    // Apply retry if configured
    if (job.retryPolicy != null) {
      executionFuture = _executeWithRetry(job);
    } else {
      executionFuture = _executeOnce(job);
    }

    // Apply timeout if configured
    if (job.timeout != null) {
      executionFuture = executionFuture.timeout(
        job.timeout!,
        onTimeout: () {
          OrchestratorConfig.logger.warning(
            'Job ${job.id} timed out after ${job.timeout!.inSeconds}s',
          );
          throw TimeoutException('Job timed out', job.timeout);
        },
      );
    }

    // Setup cancellation listener
    void Function()? cancelListenerCleanup;
    if (job.cancellationToken != null) {
      cancelListenerCleanup = job.cancellationToken!.onCancel(() {
        OrchestratorConfig.logger.info('Job ${job.id} was cancelled');
      });
    }

    try {
      final result = await executionFuture;
      cancelListenerCleanup?.call();
      return result;
    } catch (e) {
      cancelListenerCleanup?.call();
      rethrow;
    }
  }

  Future<dynamic> _executeOnce(T job) async {
    job.cancellationToken?.throwIfCancelled();
    return await process(job);
  }

  Future<dynamic> _executeWithRetry(T job) async {
    final policy = job.retryPolicy!;
    final log = OrchestratorConfig.logger;
    int attempt = 0;

    while (true) {
      try {
        job.cancellationToken?.throwIfCancelled();
        return await process(job);
      } catch (e) {
        if (e is CancelledException) rethrow;

        if (!policy.canRetry(e, attempt)) {
          log.warning('Job ${job.id} failed after ${attempt + 1} attempts');
          rethrow;
        }

        final delay = policy.getDelay(attempt);
        log.info(
          'Job ${job.id} retrying (${attempt + 1}/${policy.maxRetries}) after ${delay.inSeconds}s',
        );

        await Future.delayed(delay);
        attempt++;
      }
    }
  }

  /// Report progress for a long-running job.
  ///
  /// Progress is reported via [JobHandle.progress] stream.
  ///
  /// ```dart
  /// for (int i = 0; i < items.length; i++) {
  ///   await processItem(items[i]);
  ///   reportProgress(job.id, progress: (i + 1) / items.length);
  /// }
  /// ```
  void reportProgress(
    String correlationId, {
    required double progress,
    String? message,
    int? currentStep,
    int? totalSteps,
  }) {
    final handle = _activeHandles[correlationId];
    handle?.reportProgress(
      progress,
      message: message,
      currentStep: currentStep,
      totalSteps: totalSteps,
    );
  }

  /// Report progress using step-based calculation.
  ///
  /// ```dart
  /// for (int i = 0; i < items.length; i++) {
  ///   await processItem(items[i]);
  ///   reportStep(job.id, current: i + 1, total: items.length);
  /// }
  /// ```
  void reportStep(
    String correlationId, {
    required int current,
    required int total,
    String? message,
  }) {
    reportProgress(
      correlationId,
      progress: total > 0 ? current / total : 0.0,
      message: message,
      currentStep: current,
      totalSteps: total,
    );
  }

  /// Emit any custom event.
  void emit(BaseEvent event) {
    final bus = _activeBus[event.correlationId] ?? _globalBus;
    bus.emit(event);
    OrchestratorObserver.instance?.onEvent(event);
  }

  // --- Helper Methods for Cache Management ---

  /// Invalidate a specific cache key.
  Future<void> invalidateKey(String key) async {
    OrchestratorConfig.logger.debug('Executor invalidating key: $key');
    await cacheProvider.delete(key);
  }

  /// Invalidate cache keys matching a predicate.
  Future<void> invalidateMatching(bool Function(String key) predicate) async {
    OrchestratorConfig.logger.debug('Executor invalidating matching keys');
    await cacheProvider.deleteMatching(predicate);
  }

  /// Invalidate cache keys starting with a prefix.
  Future<void> invalidatePrefix(String prefix) async {
    OrchestratorConfig.logger.debug('Executor invalidating prefix: $prefix');
    await cacheProvider.deleteMatching((key) => key.startsWith(prefix));
  }

  /// Read from cache directly.
  Future<R?> readCache<R>(String key) async {
    final value = await cacheProvider.read(key);
    if (value is R) return value;
    return null;
  }

  /// Write to cache directly.
  Future<void> writeCache(String key, dynamic value, {Duration? ttl}) async {
    await cacheProvider.write(key, value, ttl: ttl);
  }
}
