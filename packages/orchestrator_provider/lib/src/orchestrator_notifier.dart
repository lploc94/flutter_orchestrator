import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:orchestrator_core/orchestrator_core.dart';

/// A ChangeNotifier that wraps [BaseOrchestrator] functionality.
///
/// This provides seamless integration between the Orchestrator pattern
/// and Flutter's Provider ecosystem.
///
/// Usage:
/// ```dart
/// class MyNotifier extends OrchestratorNotifier<MyState> {
///   MyNotifier() : super(MyState.initial());
///
///   void loadData() {
///     dispatch(LoadDataJob());
///   }
///
///   @override
///   void onActiveSuccess(JobSuccessEvent event) {
///     state = state.copyWith(data: event.data, status: Status.success);
///   }
/// }
/// ```
abstract class OrchestratorNotifier<S> extends ChangeNotifier {
  S _state;
  final SignalBus _bus = SignalBus();
  final Dispatcher _dispatcher = Dispatcher();

  /// Active job IDs being tracked
  final Set<String> _activeJobIds = {};

  /// Progress tracking for active jobs
  final Map<String, double> _jobProgress = {};

  StreamSubscription? _busSubscription;
  bool _isDisposed = false;

  OrchestratorNotifier(this._state) {
    _subscribeToBus();
  }

  /// Current state
  S get state => _state;

  /// Update state and notify listeners
  set state(S newState) {
    if (_isDisposed) return;
    _state = newState;
    notifyListeners();
  }

  /// Check if any job is currently running
  bool get hasActiveJobs => _activeJobIds.isNotEmpty;

  /// Get progress for a specific job (0.0 to 1.0)
  double? getJobProgress(String jobId) => _jobProgress[jobId];

  /// Dispatch a job and start tracking it
  String dispatch(BaseJob job) {
    final id = _dispatcher.dispatch(job);
    _activeJobIds.add(id);
    _jobProgress[id] = 0.0;
    return id;
  }

  /// Cancel tracking for a job
  void cancelJob(String jobId) {
    _activeJobIds.remove(jobId);
    _jobProgress.remove(jobId);
  }

  void _subscribeToBus() {
    _busSubscription = _bus.stream.listen(_routeEvent);
  }

  void _routeEvent(BaseEvent event) {
    if (_isDisposed) return;

    final isActive = _activeJobIds.contains(event.correlationId);

    // Handle progress updates
    if (event is JobProgressEvent) {
      _jobProgress[event.correlationId] = event.progress;
      if (isActive) onProgress(event);
      return;
    }

    // Handle lifecycle events
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

      // Clean up for terminal events
      if (_isTerminalEvent(event)) {
        _activeJobIds.remove(event.correlationId);
        _jobProgress.remove(event.correlationId);
      }
    } else {
      onPassiveEvent(event);
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

    onActiveEvent(event);
  }

  // ============ Hooks for subclasses ============

  /// Called when one of OUR jobs succeeds
  void onActiveSuccess(JobSuccessEvent event) {}

  /// Called when one of OUR jobs fails
  void onActiveFailure(JobFailureEvent event) {}

  /// Called when one of OUR jobs is cancelled
  void onActiveCancelled(JobCancelledEvent event) {}

  /// Called when one of OUR jobs times out
  void onActiveTimeout(JobTimeoutEvent event) {}

  /// Called when one of OUR jobs reports progress
  void onProgress(JobProgressEvent event) {}

  /// Called when one of OUR jobs starts
  void onJobStarted(JobStartedEvent event) {}

  /// Called when one of OUR jobs is retrying
  void onJobRetrying(JobRetryingEvent event) {}

  /// Generic handler for ALL active events
  void onActiveEvent(BaseEvent event) {}

  /// Handler for passive events (from other orchestrators)
  void onPassiveEvent(BaseEvent event) {}

  @override
  void dispose() {
    _isDisposed = true;
    _busSubscription?.cancel();
    _activeJobIds.clear();
    _jobProgress.clear();
    super.dispose();
  }
}
