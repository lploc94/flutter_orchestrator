import 'dart:async';
import '../infra/signal_bus.dart';
import '../models/job.dart';
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
abstract class BaseExecutor<T extends BaseJob> {
  /// Map tracking active jobs to their respective buses (Scoped or Global).
  final Map<String, SignalBus> _activeBus = {};

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
  Future<void> execute(T job) async {
    final log = OrchestratorConfig.logger;
    log.debug('Executor starting job: ${job.id}');

    // Determine target bus for this job
    // job.bus is set explicitly by Orchestrator
    final bus = job.bus ?? _globalBus;
    _activeBus[job.id] = bus;

    // Emit started event
    bus.emit(JobStartedEvent(job.id));

    // --- Unified Data Flow: 1. Placeholder ---
    if (job.strategy?.placeholder != null) {
      log.debug('Job ${job.id} emitting placeholder');
      bus.emit(JobPlaceholderEvent(job.id, job.strategy!.placeholder));
    }

    try {
      // Check cancellation before starting
      job.cancellationToken?.throwIfCancelled();

      // --- Unified Data Flow: 2. Cache Read ---
      final cachePolicy = job.strategy?.cachePolicy;
      // Way 3: Force Refresh support (Skip cache read)
      final shouldReadCache = cachePolicy != null && !cachePolicy.forceRefresh;

      if (shouldReadCache) {
        final cachedData = await cacheProvider.read(cachePolicy.key);
        if (cachedData != null) {
          log.debug('Job ${job.id} cache hit: ${cachePolicy.key}');
          bus.emit(JobCacheHitEvent(job.id, cachedData));

          // If NOT revalidating (Cache-First), return immediately
          if (!cachePolicy.revalidate) {
            log.debug(
                'Job ${job.id} cache-first strategy. Stopping execution.');
            bus.emit(JobSuccessEvent(job.id, cachedData));
            return;
          }
        }
      }

      // Build the execution future
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
            log.warning(
              'Job ${job.id} timed out after ${job.timeout!.inSeconds}s',
            );
            final b = _activeBus[job.id] ?? _globalBus;
            b.emit(JobTimeoutEvent(job.id, job.timeout!));
            throw TimeoutException('Job timed out', job.timeout);
          },
        );
      }

      // Setup cancellation listener
      if (job.cancellationToken != null) {
        job.cancellationToken!.onCancel(() {
          log.info('Job ${job.id} was cancelled');
          final b = _activeBus[job.id] ?? _globalBus;
          b.emit(JobCancelledEvent(job.id));
        });
      }

      // Execute and emit result
      final result = await executionFuture;

      // Check cancellation after completion
      if (job.cancellationToken?.isCancelled == true) {
        return; // Don't emit success if cancelled
      }

      // --- Unified Data Flow: 3. Cache Write ---
      if (cachePolicy != null && result != null) {
        log.debug('Job ${job.id} writing to cache: ${cachePolicy.key}');
        await cacheProvider.write(
          cachePolicy.key,
          result,
          ttl: cachePolicy.ttl,
        );
      }

      log.debug('Job ${job.id} completed successfully');
      emitResult(job.id, result);
    } on CancelledException {
      // Already handled by listener
    } on TimeoutException {
      // Already handled by timeout callback
    } catch (e, stack) {
      log.error('Job ${job.id} failed', e, stack);
      emitFailure(job.id, e, stack);
    } finally {
      // Cleanup bus tracking
      _activeBus.remove(job.id);
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
          // Use active bus if available, else global
          final bus = _activeBus[job.id] ?? _globalBus;
          bus.emit(JobFailureEvent(job.id, e, null, true));
          rethrow;
        }

        final delay = policy.getDelay(attempt);
        log.info(
          'Job ${job.id} retrying (${attempt + 1}/${policy.maxRetries}) after ${delay.inSeconds}s',
        );

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

        await Future.delayed(delay);
        attempt++;
      }
    }
  }

  /// Emit success result.
  void emitResult<R>(String correlationId, R data) {
    final bus = _activeBus[correlationId] ?? _globalBus;
    bus.emit(JobSuccessEvent<R>(correlationId, data));
  }

  /// Emit failure.
  void emitFailure(String correlationId, Object error, [StackTrace? stack]) {
    final bus = _activeBus[correlationId] ?? _globalBus;
    bus.emit(JobFailureEvent(correlationId, error, stack));
  }

  /// Emit progress update (for long-running tasks).
  void emitProgress(
    String correlationId, {
    required double progress,
    String? message,
    int? currentStep,
    int? totalSteps,
  }) {
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

  /// Emit any custom event.
  /// Note: Without correlationId, we default to Global Bus unless specified.
  /// Ideally Pass correlationId if you want event scoped.
  void emit(BaseEvent event) {
    final bus = _activeBus[event.correlationId] ?? _globalBus;
    bus.emit(event);
  }

  // --- Helper Methods for Method 1 (Side Effects) ---

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
}
