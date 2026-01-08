import 'dart:async';
import 'package:meta/meta.dart';
import '../infra/signal_bus.dart';
import '../infra/dispatcher.dart';
import '../models/job.dart';
import '../models/job_handle.dart';
import '../models/event.dart';
import '../utils/logger.dart';

/// The Reactive Brain.
///
/// Manages State [S] and orchestration logic with full production features:
/// - Unified event handling via [onEvent]
/// - Job tracking with auto-cleanup
/// - Progress tracking via [JobHandle.progress]
/// - Cancellation support
///
/// ## Usage
///
/// ```dart
/// class UserOrchestrator extends BaseOrchestrator<UserState> {
///   UserOrchestrator() : super(UserState.initial());
///
///   @override
///   void onEvent(BaseEvent event) {
///     switch (event) {
///       case UsersLoadedEvent e:
///         emit(state.copyWith(users: e.users));
///       case UserCreatedEvent e:
///         emit(state.copyWith(users: [...state.users, e.user]));
///     }
///   }
///
///   // Fire and forget
///   void loadUsers() {
///     dispatch<List<User>>(LoadUsersJob());
///   }
///
///   // Await result
///   Future<User> createUser(String name) async {
///     final handle = dispatch<User>(CreateUserJob(name: name));
///     final result = await handle.future;
///     return result.data;
///   }
/// }
/// ```
abstract class BaseOrchestrator<S> {
  S _state;
  final StreamController<S> _stateController = StreamController<S>.broadcast();
  final SignalBus _bus;
  final Dispatcher _dispatcher;

  /// Active jobs tracking (Jobs this orchestrator dispatched).
  final Set<String> _activeJobIds = {};

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

  /// Emit new state.
  @protected
  void emit(S newState) {
    if (_stateController.isClosed) return;
    _state = newState;
    _stateController.add(newState);
  }

  /// Dispatch a job and start tracking it.
  ///
  /// Returns a [JobHandle] that allows the caller to:
  /// - Await the job's first result via [JobHandle.future]
  /// - Track progress via [JobHandle.progress]
  /// - Check completion status via [JobHandle.isCompleted]
  /// - Access the job ID via [JobHandle.jobId]
  ///
  /// ## Usage Patterns
  ///
  /// ### Fire and Forget
  /// ```dart
  /// void loadUsers() {
  ///   dispatch<List<User>>(LoadUsersJob());
  ///   // State updates via onEvent when job completes
  /// }
  /// ```
  ///
  /// ### Await Result
  /// ```dart
  /// Future<User> createUser(String name) async {
  ///   final handle = dispatch<User>(CreateUserJob(name: name));
  ///   final result = await handle.future;
  ///   return result.data; // User
  /// }
  /// ```
  ///
  /// ### With Progress Tracking
  /// ```dart
  /// Future<void> uploadFiles(List<File> files) async {
  ///   final handle = dispatch<void>(UploadFilesJob(files));
  ///
  ///   handle.progress.listen((p) {
  ///     emit(state.copyWith(uploadProgress: p.value));
  ///   });
  ///
  ///   await handle.future;
  /// }
  /// ```
  ///
  /// ## SWR (Stale-While-Revalidate) Behavior
  ///
  /// When the job has cache with revalidate enabled:
  /// 1. Handle completes immediately with cached data
  /// 2. Worker continues in background
  /// 3. Fresh data emits via domain events → [onEvent] receives it
  @protected
  JobHandle<T> dispatch<T>(BaseJob job) {
    final log = OrchestratorConfig.logger;
    log.debug(
        'Orchestrator dispatching job: ${job.id} (Bus: ${_bus == SignalBus.instance ? "Global" : "Scoped"})');

    // Attach current bus to job context for Executor to use
    job.bus = _bus;

    // Create handle for this job
    final handle = JobHandle<T>(job.id);

    // Track job - cleanup will happen when terminal event is received in _routeEvent
    _activeJobIds.add(job.id);

    _dispatcher.dispatch(job, handle: handle);

    return handle;
  }

  /// Cancel tracking for a running job.
  ///
  /// Note: This only removes the job from tracking on the orchestrator side.
  /// For actual cancellation, the job should have a [CancellationToken].
  @protected
  void cancelJob(String jobId) {
    _activeJobIds.remove(jobId);
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

  /// Check if event is a terminal event (job completion).
  bool _isTerminalEvent(BaseEvent event) {
    return event is JobSuccessEvent ||
        event is JobFailureEvent ||
        event is JobCancelledEvent ||
        event is JobTimeoutEvent;
  }

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
      // 2. Route to unified event handler
      onEvent(event);

      // 3. Cleanup tracking for terminal events (for active jobs)
      if (_activeJobIds.contains(event.correlationId) && _isTerminalEvent(event)) {
        _activeJobIds.remove(event.correlationId);
      }
    } catch (e, stack) {
      // 3. Safety: Isolate errors to prevent app crash
      OrchestratorConfig.logger.error(
        'Error handling event ${event.runtimeType} in $runtimeType. '
        'This prevents the app from crashing due to logical errors in subscribers.',
        e,
        stack,
      );
    }
  }

  // ============ Event Handler ============

  /// Override to handle ALL domain events.
  ///
  /// This is the single entry point for all events from the [SignalBus].
  /// Use pattern matching to handle different event types:
  ///
  /// ```dart
  /// @override
  /// void onEvent(BaseEvent event) {
  ///   switch (event) {
  ///     case UsersLoadedEvent e:
  ///       emit(state.copyWith(users: e.users));
  ///     case UserCreatedEvent e:
  ///       emit(state.copyWith(users: [...state.users, e.user]));
  ///     case UserDeletedEvent e:
  ///       emit(state.copyWith(
  ///         users: state.users.where((u) => u.id != e.userId).toList()
  ///       ));
  ///   }
  /// }
  /// ```
  ///
  /// ## Design Rationale
  ///
  /// Unlike the previous Active/Passive pattern, this unified approach:
  /// - Treats all events equally (no distinction between "own" and "other" jobs)
  /// - Uses Dart 3 pattern matching for clean type handling
  /// - Simplifies mental model: "React to domain state changes"
  ///
  /// If you need to know "is this MY job?":
  /// - Use [JobHandle.future] to track specific job completion
  /// - Check [isJobRunning] with the event's correlationId
  @protected
  void onEvent(BaseEvent event) {}

  /// Cleanup resources.
  @mustCallSuper
  void dispose() {
    _busSubscription?.cancel();
    _busSubscription = null;
    _stateController.close();
    _activeJobIds.clear();
    _eventTypeCounts.clear();
  }
}
