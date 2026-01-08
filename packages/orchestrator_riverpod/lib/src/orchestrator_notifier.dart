import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orchestrator_core/orchestrator_core.dart';

/// A Riverpod Notifier that wraps [BaseOrchestrator] functionality.
///
/// This provides seamless integration between the Orchestrator pattern
/// and Flutter's Riverpod ecosystem.
///
/// ## Usage with NotifierProvider
///
/// ```dart
/// class CounterNotifier extends OrchestratorNotifier<CounterState> {
///   @override
///   CounterState buildState() => const CounterState();
///
///   void calculate(int value) {
///     state = state.copyWith(isLoading: true);
///     dispatch(CalculateJob(value));
///   }
///
///   @override
///   void onEvent(BaseEvent event) {
///     switch (event) {
///       case CalculationResultEvent e when isJobRunning(e.correlationId):
///         state = state.copyWith(count: e.result, isLoading: false);
///       case JobFailureEvent e when isJobRunning(e.correlationId):
///         state = state.copyWith(error: e.error.toString(), isLoading: false);
///     }
///   }
/// }
///
/// final counterProvider = NotifierProvider<CounterNotifier, CounterState>(
///   CounterNotifier.new,
/// );
/// ```
///
/// ## Testing
///
/// You can override the bus and dispatcher for testing:
/// ```dart
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

  /// Active job IDs being tracked by this notifier
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

  // ============ Job Tracking ============

  /// Check if any job is currently running
  bool get hasActiveJobs => _activeJobIds.isNotEmpty;

  /// Check if a specific job is being tracked by this notifier.
  ///
  /// Use this in [onEvent] to distinguish between events from your own
  /// jobs vs events from other orchestrators:
  ///
  /// ```dart
  /// @override
  /// void onEvent(BaseEvent event) {
  ///   switch (event) {
  ///     case JobSuccessEvent e when isJobRunning(e.correlationId):
  ///       // This is OUR job's success
  ///       state = state.copyWith(data: e.data, isLoading: false);
  ///     case UserUpdatedEvent e:
  ///       // Domain event (could be from anywhere)
  ///       state = state.copyWith(user: e.user);
  ///   }
  /// }
  /// ```
  bool isJobRunning(String correlationId) =>
      _activeJobIds.contains(correlationId);

  /// Get progress for a specific job (0.0 to 1.0)
  double? getJobProgress(String jobId) => _jobProgress[jobId];

  /// Dispatch a job and start tracking it.
  ///
  /// Returns the job ID for reference.
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

  /// Cancel tracking for a job (does not cancel the job itself).
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

    final isActive = isJobRunning(event.correlationId);

    // Track progress for active jobs
    if (event is JobProgressEvent && isActive) {
      _jobProgress[event.correlationId] = event.progress;
      onProgress(event);
    }

    // Optional lifecycle hooks for active jobs
    if (isActive) {
      if (event is JobStartedEvent) onJobStarted(event);
      if (event is JobRetryingEvent) onJobRetrying(event);
    }

    // Unified event handler - ALL events go here
    onEvent(event);

    // Cleanup for terminal events
    if (isActive && _isTerminalEvent(event)) {
      _activeJobIds.remove(event.correlationId);
      _jobProgress.remove(event.correlationId);
    }
  }

  bool _isTerminalEvent(BaseEvent event) {
    return event is JobSuccessEvent ||
        event is JobFailureEvent ||
        event is JobCancelledEvent ||
        event is JobTimeoutEvent;
  }

  // ============ Event Handlers ============

  /// Unified handler for ALL domain events.
  ///
  /// This is the single entry point for all events from the [SignalBus].
  /// Use Dart 3 pattern matching to handle different event types:
  ///
  /// ```dart
  /// @override
  /// void onEvent(BaseEvent event) {
  ///   switch (event) {
  ///     // Handle success from OUR jobs
  ///     case JobSuccessEvent e when isJobRunning(e.correlationId):
  ///       state = state.copyWith(data: e.data, isLoading: false);
  ///
  ///     // Handle failure from OUR jobs
  ///     case JobFailureEvent e when isJobRunning(e.correlationId):
  ///       state = state.copyWith(error: e.error.toString(), isLoading: false);
  ///
  ///     // Handle domain events (from any source)
  ///     case UserCreatedEvent e:
  ///       state = state.copyWith(users: [...state.users, e.user]);
  ///   }
  /// }
  /// ```
  ///
  /// ## Design Rationale
  ///
  /// This unified approach (matching orchestrator_core v0.6.0):
  /// - Treats all events equally (no implicit active/passive distinction)
  /// - Uses Dart 3 pattern matching for clean type handling
  /// - Use [isJobRunning] to check if an event is from your own job
  void onEvent(BaseEvent event) {}

  // ============ Optional Lifecycle Hooks ============

  /// Called when one of OUR jobs reports progress.
  ///
  /// This is a convenience hook - you can also handle [JobProgressEvent]
  /// in [onEvent] if preferred.
  void onProgress(JobProgressEvent event) {}

  /// Called when one of OUR jobs starts.
  ///
  /// This is a convenience hook - you can also handle [JobStartedEvent]
  /// in [onEvent] if preferred.
  void onJobStarted(JobStartedEvent event) {}

  /// Called when one of OUR jobs is retrying.
  ///
  /// This is a convenience hook - you can also handle [JobRetryingEvent]
  /// in [onEvent] if preferred.
  void onJobRetrying(JobRetryingEvent event) {}

  // ============ Lifecycle ============

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
