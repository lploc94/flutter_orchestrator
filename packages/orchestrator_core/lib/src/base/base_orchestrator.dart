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
  final SignalBus _bus = SignalBus();
  final Dispatcher _dispatcher = Dispatcher();

  /// Active transactions tracking (Jobs this orchestrator owns).
  final Set<String> _activeJobIds = {};

  /// Progress tracking for active jobs.
  final Map<String, double> _jobProgress = {};

  /// Bus subscription.
  StreamSubscription? _busSubscription;

  BaseOrchestrator(this._state) {
    _stateController.add(_state);
    _subscribeToBus();
  }

  /// Current State.
  S get state => _state;

  /// Stream of State changes for UI to listen.
  Stream<S> get stream => _stateController.stream;

  /// Check if any job is currently running.
  bool get hasActiveJobs => _activeJobIds.isNotEmpty;

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
    log.debug('Orchestrator dispatching job: ${job.id}');

    final id = _dispatcher.dispatch(job);
    _activeJobIds.add(id);
    _jobProgress[id] = 0.0;

    return id;
  }

  /// Cancel a running job.
  @protected
  void cancelJob(String jobId) {
    // Note: Actual cancellation depends on the job having a CancellationToken.
    // This just cleans up tracking on the orchestrator side.
    _activeJobIds.remove(jobId);
    _jobProgress.remove(jobId);
    OrchestratorConfig.logger.info(
      'Orchestrator cancelled tracking for job: $jobId',
    );
  }

  void _subscribeToBus() {
    _busSubscription = _bus.stream.listen(_routeEvent);
  }

  void _routeEvent(BaseEvent event) {
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
        _jobProgress.remove(event.correlationId);
      }
    } else {
      _handlePassiveEvent(event);
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
    _stateController.close();
    _activeJobIds.clear();
    _jobProgress.clear();
  }
}
