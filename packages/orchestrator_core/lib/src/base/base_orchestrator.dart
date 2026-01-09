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
  @protected
  JobHandle<T> dispatch<T>(EventJob job) {
    final log = OrchestratorConfig.logger;
    log.debug(
        'Orchestrator dispatching job: ${job.id} (Bus: ${_bus == SignalBus.instance ? "Global" : "Scoped"})');

    // Attach current bus to job context for Executor to use
    job.bus = _bus;

    // Create handle for this job
    final handle = JobHandle<T>(job.id);

    // Track job
    _activeJobIds.add(job.id);

    // Auto-cleanup when job completes (success or error)
    // We use a small delay to allow domain events to be processed by onEvent()
    // before removing from tracking. This ensures isJobRunning() returns true
    // when the orchestrator receives events from its own jobs.
    handle.future.then((_) {
      Future.delayed(const Duration(milliseconds: 50), () {
        _activeJobIds.remove(job.id);
      });
    }).catchError((e) {
      Future.delayed(const Duration(milliseconds: 50), () {
        _activeJobIds.remove(job.id);
      });
    });

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
      if (currentCount == limit + 1) {
        OrchestratorConfig.logger.error(
          'Circuit Breaker: Event $type exceeded limit ($currentCount/s > $limit). '
          'Blocking this specific event type to prevent infinite loop.',
          Exception('Infinite Loop Detected for $type'),
          StackTrace.current,
        );
      }
      return;
    }

    try {
      // Route to unified event handler
      onEvent(event);
    } catch (e, stack) {
      OrchestratorConfig.logger.error(
        'Error handling event ${event.runtimeType} in $runtimeType.',
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
  ///   }
  /// }
  /// ```
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
