import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orchestrator_core/orchestrator_core.dart';

/// A Riverpod Notifier that wraps [BaseOrchestrator] functionality.
///
/// This provides seamless integration between the Orchestrator pattern
/// and Flutter's Riverpod ecosystem.
///
/// Usage with NotifierProvider:
/// ```dart
/// class CounterNotifier extends OrchestratorNotifier<CounterState> {
///   @override
///   CounterState build() => const CounterState();
///
///   void calculate(int value) {
///     state = state.copyWith(isLoading: true);
///     dispatch(CalculateJob(value));
///   }
///
///   @override
///   void onActiveSuccess(JobSuccessEvent event) {
///     state = state.copyWith(count: event.data as int, isLoading: false);
///   }
/// }
///
/// final counterProvider = NotifierProvider<CounterNotifier, CounterState>(
///   CounterNotifier.new,
/// );
/// ```
///
/// For testing, you can override the bus and dispatcher:
/// ```dart
/// // In your notifier, expose a way to inject dependencies
/// class TestableNotifier extends OrchestratorNotifier<MyState> {
///   @override
///   MyState buildState() => MyState.initial();
///
///   @override
///   SignalBus get bus => _customBus ?? super.bus;
///   SignalBus? _customBus;
///   void setTestBus(SignalBus bus) => _customBus = bus;
/// }
/// ```
abstract class OrchestratorNotifier<S> extends Notifier<S> {
  SignalBus _bus = SignalBus.instance;
  Dispatcher _dispatcher = Dispatcher();

  /// Active job IDs being tracked
  final Set<String> _activeJobIds = {};

  /// Progress tracking for active jobs
  final Map<String, double> _jobProgress = {};

  StreamSubscription? _busSubscription;
  bool _isDisposed = false;
  bool _isInitialized = false;

  /// The SignalBus used for event communication.
  ///
  /// Defaults to [SignalBus.instance]. Override in subclass for testing.
  SignalBus get bus => _bus;

  /// The Dispatcher used for job routing.
  ///
  /// Defaults to [Dispatcher] singleton. Override in subclass for testing.
  Dispatcher get dispatcher => _dispatcher;

  /// Configure custom bus and dispatcher for testing.
  ///
  /// Call this in your test setup before the notifier is built.
  void configureForTesting({SignalBus? bus, Dispatcher? dispatcher}) {
    if (bus != null) _bus = bus;
    if (dispatcher != null) _dispatcher = dispatcher;
  }

  /// Override this method to provide initial state.
  ///
  /// Note: The bus subscription is automatically set up when [build] is called.
  @override
  S build() {
    // Auto-subscribe to bus on first build
    if (!_isInitialized) {
      _subscribeToBus();
      _isInitialized = true;
    }
    return buildState();
  }

  /// Override this method to provide the initial state.
  ///
  /// This is called by [build] after the bus subscription is set up.
  S buildState();

  /// Initialize the notifier manually (optional).
  ///
  /// This is called automatically by [build], so you typically don't need
  /// to call this directly.
  @Deprecated(
      'Bus subscription is now automatic in build(). This method is no longer needed.')
  void initialize() {
    _subscribeToBus();
  }

  /// Check if any job is currently running
  bool get hasActiveJobs => _activeJobIds.isNotEmpty;

  /// Get progress for a specific job (0.0 to 1.0)
  double? getJobProgress(String jobId) => _jobProgress[jobId];

  /// Dispatch a job and start tracking it
  String dispatch(BaseJob job) {
    _ensureSubscribed();
    final id = dispatcher.dispatch(job);
    _activeJobIds.add(id);
    _jobProgress[id] = 0.0;
    return id;
  }

  void _ensureSubscribed() {
    if (_busSubscription == null && !_isDisposed) {
      _subscribeToBus();
    }
  }

  /// Cancel tracking for a job
  void cancelJob(String jobId) {
    _activeJobIds.remove(jobId);
    _jobProgress.remove(jobId);
  }

  void _subscribeToBus() {
    _busSubscription?.cancel();
    _busSubscription = bus.stream.listen(_routeEvent);
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

  /// Dispose resources - call when provider is disposed.
  ///
  /// Note: Riverpod handles provider lifecycle automatically,
  /// but you can call this manually if needed for cleanup.
  void dispose() {
    _isDisposed = true;
    _busSubscription?.cancel();
    _busSubscription = null;
    _activeJobIds.clear();
    _jobProgress.clear();
  }
}
