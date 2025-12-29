import 'dart:async';
import 'package:meta/meta.dart';
import '../infra/signal_bus.dart';
import '../infra/dispatcher.dart';
import '../models/job.dart';
import '../models/event.dart';
import '../utils/logger.dart';

/// The Reactive Brain.
///
/// Manages State [S] and orchestration logic with full production features:
/// - Active/Passive event routing
/// - Progress tracking
/// - Cancellation support
/// - Typed event filtering
abstract class BaseOrchestrator<S> {
  S _state;
  final StreamController<S> _stateController = StreamController<S>.broadcast();
  final SignalBus _bus;
  final Dispatcher _dispatcher;

  /// Active transactions tracking (Jobs this orchestrator owns).
  final Set<String> _activeJobIds = {};
  final Map<String, Type> _activeJobTypes = {};

  /// Progress tracking for active jobs.
  final Map<String, double> _jobProgress = {};

  /// Bus subscription.
  StreamSubscription? _busSubscription;

  /// Creates a new orchestrator with the given initial state.
  ///
  /// Optionally accepts a [bus] for event communication (defaults to global [SignalBus.instance]).
  /// Optionally accepts a [dispatcher] for job routing (defaults to global [Dispatcher] singleton).
  ///
  /// The [dispatcher] parameter is useful for testing, allowing injection of mock dispatchers.
  BaseOrchestrator(this._state, {SignalBus? bus, Dispatcher? dispatcher})
      : _bus = bus ?? SignalBus.instance,
        _dispatcher = dispatcher ?? Dispatcher() {
    _stateController.add(_state);
    _subscribeToBus();
  }

  /// Current State.
  S get state => _state;

  /// Stream of State changes for UI to listen.
  Stream<S> get stream => _stateController.stream;

  /// Check if any job is currently running.
  bool get hasActiveJobs => _activeJobIds.isNotEmpty;

  /// Check if a specific job ID is running.
  bool isJobRunning(String jobId) => _activeJobIds.contains(jobId);

  /// Check if any job of type [T] is running.
  /// Useful for UI to show specific loading indicators.
  bool isJobTypeRunning<T extends BaseJob>() {
    return _activeJobTypes.values.contains(T);
  }

  /// Get progress for a specific job (0.0 to 1.0).
  double? getJobProgress(String jobId) => _jobProgress[jobId];

  /// Emit new state.
  @protected
  void emit(S newState) {
    if (_stateController.isClosed) return;
    _state = newState;
    _stateController.add(newState);
  }

  /// Dispatch a job and start tracking it.
  @protected
  String dispatch(BaseJob job) {
    final log = OrchestratorConfig.logger;
    log.debug(
        'Orchestrator dispatching job: ${job.id} (Bus: ${_bus == SignalBus.instance ? "Global" : "Scoped"})');

    // Attach current bus to job context for Executor to use
    job.bus = _bus;

    final id = _dispatcher.dispatch(job);
    _activeJobIds.add(id);
    _activeJobTypes[id] = job.runtimeType;
    _jobProgress[id] = 0.0;

    return id;
  }

  /// Cancel a running job.
  @protected
  void cancelJob(String jobId) {
    // Note: Actual cancellation depends on the job having a CancellationToken.
    // This just cleans up tracking on the orchestrator side.
    _activeJobIds.remove(jobId);
    _activeJobTypes.remove(jobId);
    _jobProgress.remove(jobId);
    OrchestratorConfig.logger.info(
      'Orchestrator cancelled tracking for job: $jobId',
    );
  }

  void _subscribeToBus() {
    _busSubscription = _bus.stream.listen(_routeEvent);
  }

  // Safety: Loop Detection
  final Map<Type, int> _eventTypeCounts = {};
  DateTime _lastEventTime = DateTime.now();

  void _routeEvent(BaseEvent event) {
    // 1. Smart Circuit Breaker (Loop Protection by Type)
    final now = DateTime.now();
    if (now.difference(_lastEventTime).inSeconds >= 1) {
      _eventTypeCounts.clear();
      _lastEventTime = now;
    }

    final type = event.runtimeType;
    final currentCount = (_eventTypeCounts[type] ?? 0) + 1;
    _eventTypeCounts[type] = currentCount;

    final limit = OrchestratorConfig.getLimit(type);

    if (currentCount > limit) {
      // Only log once per second per type to avoid spamming
      if (currentCount == limit + 1) {
        OrchestratorConfig.logger.error(
          'Circuit Breaker: Event $type exceeded limit ($currentCount/s > $limit). '
          'Blocking this specific event type to prevent infinite loop. '
          'Other events are unaffected.',
          Exception('Infinite Loop Detected for $type'),
          StackTrace.current,
        );
      }
      return; // Block ONLY this specific event type
    }

    try {
      // Re-use existing logic inside try-catch block for Type Safety
      final isActive = _activeJobIds.contains(event.correlationId);

      // Handle progress updates
      if (event is JobProgressEvent) {
        _jobProgress[event.correlationId] = event.progress;
        if (isActive) {
          onProgress(event);
        }
        return;
      }

      // Handle job lifecycle events
      if (event is JobStartedEvent) {
        if (isActive) onJobStarted(event);
        return;
      }

      if (event is JobRetryingEvent) {
        if (isActive) onJobRetrying(event);
        return;
      }

      // Route result events
      if (isActive) {
        _handleActiveEvent(event);

        // Clean up tracking for terminal events
        if (_isTerminalEvent(event)) {
          _activeJobIds.remove(event.correlationId);
          _activeJobTypes.remove(event.correlationId);
          _jobProgress.remove(event.correlationId);
        }
      } else {
        _handlePassiveEvent(event);
      }
    } catch (e, stack) {
      // 2. Safety Type Check & Error Isolation
      OrchestratorConfig.logger.error(
        'Error handling event ${event.runtimeType} in $runtimeType. '
        'This prevents the app from crashing due to logical errors in subscribers.',
        e,
        stack,
      );
    }
  }

  bool _isTerminalEvent(BaseEvent event) {
    return event is JobSuccessEvent ||
        event is JobFailureEvent ||
        event is JobCancelledEvent ||
        event is JobTimeoutEvent;
  }

  void _handleActiveEvent(BaseEvent event) {
    if (event is JobSuccessEvent) {
      onActiveSuccess(event);
    } else if (event is JobFailureEvent) {
      onActiveFailure(event);
    } else if (event is JobCancelledEvent) {
      onActiveCancelled(event);
    } else if (event is JobTimeoutEvent) {
      onActiveTimeout(event);
    }

    // Also call generic handler
    onActiveEvent(event);
  }

  void _handlePassiveEvent(BaseEvent event) {
    onPassiveEvent(event);
  }

  // ============ Hooks for subclasses ============

  /// Called when one of OUR jobs succeeds.
  @protected
  void onActiveSuccess(JobSuccessEvent event) {}

  /// Called when one of OUR jobs fails.
  @protected
  void onActiveFailure(JobFailureEvent event) {}

  /// Called when one of OUR jobs is cancelled.
  @protected
  void onActiveCancelled(JobCancelledEvent event) {}

  /// Called when one of OUR jobs times out.
  @protected
  void onActiveTimeout(JobTimeoutEvent event) {}

  /// Called when one of OUR jobs reports progress.
  @protected
  void onProgress(JobProgressEvent event) {}

  /// Called when one of OUR jobs starts.
  @protected
  void onJobStarted(JobStartedEvent event) {}

  /// Called when one of OUR jobs is retrying.
  @protected
  void onJobRetrying(JobRetryingEvent event) {}

  /// Generic handler for ALL active events (after specific handlers).
  @protected
  void onActiveEvent(BaseEvent event) {}

  /// Handler for passive events (events from other orchestrators).
  @protected
  void onPassiveEvent(BaseEvent event) {}

  /// Cleanup resources.
  @mustCallSuper
  void dispose() {
    _busSubscription?.cancel();
    _busSubscription = null;
    _stateController.close();
    _activeJobIds.clear();
    _activeJobTypes.clear();
    _jobProgress.clear();
    _eventTypeCounts.clear();
  }
}
