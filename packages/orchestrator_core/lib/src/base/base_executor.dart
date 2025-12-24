import 'dart:async';
import '../infra/signal_bus.dart';
import '../models/job.dart';
import '../models/event.dart';
import '../utils/cancellation_token.dart';
import '../utils/logger.dart';

/// Abstract Worker that performs actual business logic.
///
/// Features:
/// - Error Boundary (auto-catch exceptions)
/// - Timeout handling
/// - Retry with exponential backoff
/// - Cancellation support
/// - Progress reporting
abstract class BaseExecutor<T extends BaseJob> {
  /// Map tracking active jobs to their respective buses (Scoped or Global).
  final Map<String, SignalBus> _activeBus = {};

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

    try {
      // Check cancellation before starting
      job.cancellationToken?.throwIfCancelled();

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
}
