import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:orchestrator_core/orchestrator_core.dart';

/// Base event for OrchestratorBloc
abstract class OrchestratorBlocEvent {
  const OrchestratorBlocEvent();
}

/// Event to dispatch a job
class DispatchJobEvent extends OrchestratorBlocEvent {
  final BaseJob job;
  const DispatchJobEvent(this.job);
}

/// Event to cancel a job
class CancelJobEvent extends OrchestratorBlocEvent {
  final String jobId;
  const CancelJobEvent(this.jobId);
}

/// A Bloc that wraps [BaseOrchestrator] functionality.
///
/// Use this when you prefer the event-driven Bloc pattern over Cubit.
///
/// Usage:
/// ```dart
/// class MyBloc extends OrchestratorBloc<MyEvent, MyState> {
///   MyBloc() : super(MyState.initial()) {
///     on<LoadDataEvent>(_onLoadData);
///   }
///
///   void _onLoadData(LoadDataEvent event, Emitter<MyState> emit) {
///     dispatch(LoadDataJob());
///     emit(state.copyWith(status: Status.loading));
///   }
/// }
/// ```
abstract class OrchestratorBloc<E extends OrchestratorBlocEvent, S>
    extends Bloc<E, S> {
  final SignalBus _bus = SignalBus();
  final Dispatcher _dispatcher = Dispatcher();

  final Set<String> _activeJobIds = {};
  final Map<String, double> _jobProgress = {};

  StreamSubscription? _busSubscription;

  OrchestratorBloc(super.initialState) {
    _subscribeToBus();
  }

  bool get hasActiveJobs => _activeJobIds.isNotEmpty;
  double? getJobProgress(String jobId) => _jobProgress[jobId];

  /// Dispatch a job and start tracking it
  String dispatch(BaseJob job) {
    final id = _dispatcher.dispatch(job);
    _activeJobIds.add(id);
    _jobProgress[id] = 0.0;
    return id;
  }

  void cancelJob(String jobId) {
    _activeJobIds.remove(jobId);
    _jobProgress.remove(jobId);
  }

  void _subscribeToBus() {
    _busSubscription = _bus.stream.listen(_routeEvent);
  }

  void _routeEvent(BaseEvent event) {
    if (isClosed) return;

    final isActive = _activeJobIds.contains(event.correlationId);

    if (event is JobProgressEvent) {
      _jobProgress[event.correlationId] = event.progress;
      if (isActive) onProgress(event);
      return;
    }

    if (event is JobStartedEvent) {
      if (isActive) onJobStarted(event);
      return;
    }

    if (event is JobRetryingEvent) {
      if (isActive) onJobRetrying(event);
      return;
    }

    if (isActive) {
      _handleActiveEvent(event);

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

  // ============ Hooks ============
  void onActiveSuccess(JobSuccessEvent event) {}
  void onActiveFailure(JobFailureEvent event) {}
  void onActiveCancelled(JobCancelledEvent event) {}
  void onActiveTimeout(JobTimeoutEvent event) {}
  void onProgress(JobProgressEvent event) {}
  void onJobStarted(JobStartedEvent event) {}
  void onJobRetrying(JobRetryingEvent event) {}
  void onActiveEvent(BaseEvent event) {}
  void onPassiveEvent(BaseEvent event) {}

  @override
  Future<void> close() {
    _busSubscription?.cancel();
    _activeJobIds.clear();
    _jobProgress.clear();
    return super.close();
  }
}
