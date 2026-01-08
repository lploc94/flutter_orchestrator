import 'dart:async';
import '../infra/signal_bus.dart';
import '../infra/orchestrator_observer.dart';
import '../models/job.dart';
import '../models/job_handle.dart';
import '../models/data_source.dart';
import '../models/event.dart';
import '../utils/cancellation_token.dart';
import '../utils/logger.dart';

// Placeholder to force tool usage, actual implementation details below
import '../infra/cache/cache_provider.dart';

/// Abstract Worker that performs actual business logic.
///
/// Features:
/// - Error Boundary (auto-catch exceptions)
/// - Timeout handling
/// - Retry with exponential backoff
/// - Cancellation support
/// - Progress reporting
/// - Unified Data Flow (Placeholder -> Cache -> Real)
/// - EventJob support with domain event emission
abstract class BaseExecutor<T extends BaseJob> {
  /// Map tracking active jobs to their respective buses (Scoped or Global).
  final Map<String, SignalBus> _activeBus = {};

  /// Map tracking active jobs to their job types.
  final Map<String, String> _activeJobTypes = {};

  /// Map tracking active job handles for progress reporting.
  final Map<String, JobHandle> _activeHandles = {};

  /// Cache Provider (Shared Singleton from Config).
  CacheProvider get cacheProvider => OrchestratorConfig.cacheProvider;

  /// Global fallback.
  SignalBus get _globalBus => SignalBus.instance;

  /// The main entry point for processing.
  /// Subclasses implement this with actual logic.
  ///
  /// DO NOT emit success/failure manually in most cases -
  /// the wrapper handles it. Just return the result or throw.
  Future<dynamic> process(T job);

  /// Entry point called by Dispatcher.
  /// Wraps [process] with error boundary, timeout, retry, and cancellation.
  ///
  /// Optionally accepts a [handle] that will be completed when the job
  /// produces its first result (from cache or worker).
  Future<void> execute(T job, {JobHandle? handle}) async {
    final log = OrchestratorConfig.logger;
    log.debug('Executor starting job: ${job.id}');

    // Notify observer
    OrchestratorObserver.instance?.onJobStart(job);

    // Determine target bus for this job
    // job.bus is set explicitly by Orchestrator
    final bus = job.bus ?? _globalBus;
    final jobType = job.runtimeType.toString();
    _activeBus[job.id] = bus;
    _activeJobTypes[job.id] = jobType;
    if (handle != null) {
      _activeHandles[job.id] = handle;
    }

    try {
      // Route based on job type
      if (job is EventJob) {
        await _executeEventJob(job, handle);
      } else {
        await _executeLegacyJob(job, handle);
      }
    } on CancelledException catch (e, stack) {
      // Handle cancellation separately - it's not a failure, it's an expected state
      log.info('Job ${job.id} was cancelled');
      OrchestratorObserver.instance?.onJobError(job, e, stack);
      handle?.completeError(e, stack);
      // Note: JobCancelledEvent is already emitted by the cancellation listener
      // in _executeWithFeatures when token.cancel() was called.
    } catch (e, stack) {
      log.error('Job ${job.id} failed', e, stack);
      OrchestratorObserver.instance?.onJobError(job, e, stack);
      handle?.completeError(e, stack);
      // For legacy jobs, emit failure event
      if (job is! EventJob) {
        // Set wasRetried flag if job had a retry policy (meaning retries were attempted)
        final wasRetried = job.retryPolicy != null;
        final jt = _activeJobTypes[job.id];
        bus.emit(JobFailureEvent(job.id, e,
            stackTrace: stack, wasRetried: wasRetried, jobType: jt));
      }
    } finally {
      // Cleanup
      job.cancellationToken?.clearListeners();
      _activeBus.remove(job.id);
      _activeJobTypes.remove(job.id);
      _activeHandles.remove(job.id);

      // Small delay to allow progress events to be delivered to late subscribers
      // before closing the stream. This fixes the race condition where the last
      // progress update (100%) might not reach the caller.
      await Future.delayed(Duration(milliseconds: 10));
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
  Future<void> _executeEventJob(EventJob job, JobHandle? handle) async {
    final log = OrchestratorConfig.logger;
    final bus = (job as BaseJob).bus ?? _globalBus;
    final cacheKey = job.cacheKey;

    // Check cancellation before starting
    (job as BaseJob).cancellationToken?.throwIfCancelled();

    // 1. Check cache (with error handling - cache failure should not fail the job)
    if (cacheKey != null) {
      dynamic cached;
      try {
        cached = await cacheProvider.read(cacheKey);
      } catch (e, stack) {
        log.warning('EventJob ${job.id} cache read failed: $e');
        OrchestratorObserver.instance?.onJobError(job, e, stack);
        // Continue without cache - treat as cache miss
        cached = null;
      }

      if (cached != null) {
        log.debug('EventJob ${job.id} cache hit: $cacheKey');

        // Create domain event with CURRENT job's correlationId
        final event = job.createEvent(cached);
        bus.emit(event);
        OrchestratorObserver.instance?.onEvent(event);
        OrchestratorObserver.instance
            ?.onJobSuccess(job, cached, DataSource.cached);

        // Complete handle with cached data
        handle?.complete(cached, DataSource.cached);

        // If NOT revalidating (Cache-First), stop here
        if (!job.revalidate) {
          log.debug('EventJob ${job.id} cache-first strategy. Done.');
          return;
        }
        // SWR: continue to worker, handle is already complete
        log.debug('EventJob ${job.id} SWR: revalidating in background');
      }
    }

    // 2. Execute worker with retry/timeout support
    final result = await _executeWithFeatures(job as T);

    // Check cancellation after completion
    if ((job as BaseJob).cancellationToken?.isCancelled == true) {
      log.debug('EventJob ${job.id} cancelled after execution');
      return;
    }

    // 3. Write to cache (with error handling - cache failure should not fail the job)
    if (cacheKey != null) {
      try {
        log.debug('EventJob ${job.id} writing to cache: $cacheKey');
        await cacheProvider.write(cacheKey, result, ttl: job.cacheTtl);
      } catch (e, stack) {
        log.warning('EventJob ${job.id} cache write failed: $e');
        OrchestratorObserver.instance?.onJobError(job, e, stack);
        // Continue - worker succeeded, just cache write failed
      }
    }

    // 4. Create and emit domain event
    final event = job.createEvent(result);
    bus.emit(event);
    OrchestratorObserver.instance?.onEvent(event);
    OrchestratorObserver.instance?.onJobSuccess(job, result, DataSource.fresh);

    log.debug('EventJob ${job.id} completed successfully');

    // 5. Complete handle (if not already completed by cache)
    handle?.complete(result, DataSource.fresh);
  }

  /// Execute a legacy BaseJob (backward compatibility).
  ///
  /// This maintains the old behavior with JobSuccessEvent, JobCacheHitEvent, etc.
  Future<void> _executeLegacyJob(T job, JobHandle? handle) async {
    final log = OrchestratorConfig.logger;
    final bus = job.bus ?? _globalBus;
    final jobType = job.runtimeType.toString();

    // Emit started event (legacy)
    bus.emit(JobStartedEvent(job.id, jobType: jobType));

    // --- Unified Data Flow: 1. Placeholder ---
    if (job.strategy?.placeholder != null) {
      log.debug('Job ${job.id} emitting placeholder');
      bus.emit(JobPlaceholderEvent(job.id, job.strategy!.placeholder,
          jobType: jobType));
    }

    // Check cancellation before starting
    job.cancellationToken?.throwIfCancelled();

    // --- Unified Data Flow: 2. Cache Read ---
    final cachePolicy = job.strategy?.cachePolicy;
    final shouldReadCache = cachePolicy != null && !cachePolicy.forceRefresh;

    if (shouldReadCache) {
      final cachedData = await cacheProvider.read(cachePolicy.key);
      if (cachedData != null) {
        log.debug('Job ${job.id} cache hit: ${cachePolicy.key}');
        bus.emit(JobCacheHitEvent(job.id, cachedData, jobType: jobType));

        // Complete handle with cached data immediately
        handle?.complete(cachedData, DataSource.cached);

        // If NOT revalidating (Cache-First), return immediately
        if (!cachePolicy.revalidate) {
          log.debug('Job ${job.id} cache-first strategy. Stopping execution.');
          bus.emit(JobSuccessEvent(job.id, cachedData, jobType: jobType));
          OrchestratorObserver.instance
              ?.onJobSuccess(job, cachedData, DataSource.cached);
          return;
        }
        // If revalidating, continue execution but handle is already complete
      }
    }

    // Execute worker with retry/timeout support
    final result = await _executeWithFeatures(job);

    // Check cancellation after completion
    if (job.cancellationToken?.isCancelled == true) {
      return; // Don't emit success if cancelled
    }

    // --- Unified Data Flow: 3. Cache Write ---
    if (cachePolicy != null && result != null) {
      log.debug('Job ${job.id} writing to cache: ${cachePolicy.key}');
      await cacheProvider.write(cachePolicy.key, result, ttl: cachePolicy.ttl);
    }

    log.debug('Job ${job.id} completed successfully');

    // Complete handle with fresh result (if not already completed by cache)
    handle?.complete(result, DataSource.fresh);

    emitResult(job.id, result);
    OrchestratorObserver.instance?.onJobSuccess(job, result, DataSource.fresh);
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
          // For legacy jobs, emit timeout event
          if (job is! EventJob) {
            final b = _activeBus[job.id] ?? _globalBus;
            final jt = _activeJobTypes[job.id];
            b.emit(JobTimeoutEvent(job.id, job.timeout!, jobType: jt));
          }
          throw TimeoutException('Job timed out', job.timeout);
        },
      );
    }

    // Setup cancellation listener
    // Emit cancelled event immediately when cancel() is called, even if the worker
    // hasn't checked for cancellation yet. This provides immediate feedback to listeners.
    void Function()? cancelListenerCleanup;
    if (job.cancellationToken != null) {
      cancelListenerCleanup = job.cancellationToken!.onCancel(() {
        OrchestratorConfig.logger.info('Job ${job.id} was cancelled');
        // For legacy jobs, emit cancelled event immediately
        if (job is! EventJob) {
          final b = _activeBus[job.id] ?? _globalBus;
          final jt = _activeJobTypes[job.id];
          b.emit(JobCancelledEvent(job.id, jobType: jt));
        }
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
          // Don't emit JobFailureEvent here - let execute() catch block handle it
          // to avoid double emission. The wasRetried flag will be set based on
          // whether retryPolicy was configured.
          rethrow;
        }

        final delay = policy.getDelay(attempt);
        log.info(
          'Job ${job.id} retrying (${attempt + 1}/${policy.maxRetries}) after ${delay.inSeconds}s',
        );

        // For legacy jobs, emit retrying event
        if (job is! EventJob) {
          final bus = _activeBus[job.id] ?? _globalBus;
          bus.emit(
            JobRetryingEvent(
              job.id,
              attempt: attempt + 1,
              maxRetries: policy.maxRetries,
              lastError: e,
              delayBeforeRetry: delay,
            ),
          );
        }

        await Future.delayed(delay);
        attempt++;
      }
    }
  }

  /// Emit success result (legacy - for BaseJob).
  void emitResult<R>(String correlationId, R data) {
    final bus = _activeBus[correlationId] ?? _globalBus;
    final jobType = _activeJobTypes[correlationId];
    bus.emit(JobSuccessEvent<R>(correlationId, data, jobType: jobType));
  }

  /// Emit failure (legacy - for BaseJob).
  void emitFailure(String correlationId, Object error, [StackTrace? stack]) {
    final bus = _activeBus[correlationId] ?? _globalBus;
    final jobType = _activeJobTypes[correlationId];
    bus.emit(JobFailureEvent(correlationId, error,
        stackTrace: stack, jobType: jobType));
  }

  /// Emit progress update (for long-running tasks).
  ///
  /// This reports progress to both:
  /// - The JobHandle (for callers awaiting the handle)
  /// - The event bus (for legacy listeners)
  void emitProgress(
    String correlationId, {
    required double progress,
    String? message,
    int? currentStep,
    int? totalSteps,
  }) {
    // Report to JobHandle
    final handle = _activeHandles[correlationId];
    handle?.reportProgress(
      progress,
      message: message,
      currentStep: currentStep,
      totalSteps: totalSteps,
    );

    // Emit event for legacy listeners
    final bus = _activeBus[correlationId] ?? _globalBus;
    bus.emit(
      JobProgressEvent(
        correlationId,
        progress: progress,
        message: message,
        currentStep: currentStep,
        totalSteps: totalSteps,
      ),
    );
  }

  /// Emit progress using step-based calculation.
  ///
  /// Convenience method that calculates progress from steps.
  ///
  /// Example:
  /// ```dart
  /// for (int i = 0; i < items.length; i++) {
  ///   await processItem(items[i]);
  ///   emitStep(job.id, current: i + 1, total: items.length);
  /// }
  /// ```
  void emitStep(
    String correlationId, {
    required int current,
    required int total,
    String? message,
  }) {
    emitProgress(
      correlationId,
      progress: total > 0 ? current / total : 0.0,
      message: message,
      currentStep: current,
      totalSteps: total,
    );
  }

  /// Emit any custom event.
  /// Note: Without correlationId, we default to Global Bus unless specified.
  /// Ideally Pass correlationId if you want event scoped.
  void emit(BaseEvent event) {
    final bus = _activeBus[event.correlationId] ?? _globalBus;
    bus.emit(event);
    OrchestratorObserver.instance?.onEvent(event);
  }

  // --- Helper Methods for Cache Management ---

  /// Invalidate a specific cache key.
  /// Call this from [process] when you need to clear related data.
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
  ///
  /// Useful when you need to check cache in your process logic.
  Future<R?> readCache<R>(String key) async {
    final value = await cacheProvider.read(key);
    if (value is R) return value;
    return null;
  }

  /// Write to cache directly.
  ///
  /// Useful when you need to cache intermediate results.
  Future<void> writeCache(String key, dynamic value, {Duration? ttl}) async {
    await cacheProvider.write(key, value, ttl: ttl);
  }
}
