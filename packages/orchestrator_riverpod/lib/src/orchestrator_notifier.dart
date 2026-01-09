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
/// class UserNotifier extends OrchestratorNotifier<UserState> {
///   @override
///   UserState buildState() => const UserState();
///
///   // Fire-and-forget pattern
///   void loadUsers() {
///     state = state.copyWith(isLoading: true);
///     dispatch<List<User>>(LoadUsersJob());
///   }
///
///   // Await result pattern
///   Future<User?> createUser(String name) async {
///     final handle = dispatch<User>(CreateUserJob(name: name));
///     try {
///       final result = await handle.future;
///       return result.data;
///     } catch (e) {
///       return null;
///     }
///   }
///
///   @override
///   void onEvent(BaseEvent event) {
///     switch (event) {
///       case UsersLoadedEvent e:
///         state = state.copyWith(users: e.users, isLoading: false);
///       case UserCreatedEvent e:
///         state = state.copyWith(users: [...state.users, e.user]);
///     }
///   }
/// }
///
/// final userProvider = NotifierProvider<UserNotifier, UserState>(
///   UserNotifier.new,
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

  @override
  S build() {
    if (!_isInitialized) {
      _subscribeToBus();
      _isInitialized = true;
    }
    return buildState();
  }

  /// Override this method to provide the initial state.
  S buildState();

  // ============ Job Tracking ============

  /// Check if any job is currently running
  bool get hasActiveJobs => _activeJobIds.isNotEmpty;

  /// Check if a specific job is being tracked by this notifier.
  bool isJobRunning(String correlationId) =>
      _activeJobIds.contains(correlationId);

  /// Dispatch a job and start tracking it.
  ///
  /// Returns a [JobHandle] that allows the caller to:
  /// - Await the job's result via [JobHandle.future]
  /// - Track progress via [JobHandle.progress]
  /// - Check completion status via [JobHandle.isCompleted]
  ///
  /// ## Usage Patterns
  ///
  /// ### Fire and Forget
  /// ```dart
  /// void loadUsers() {
  ///   dispatch<List<User>>(LoadUsersJob());
  /// }
  /// ```
  ///
  /// ### Await Result
  /// ```dart
  /// Future<User> createUser(String name) async {
  ///   final handle = dispatch<User>(CreateUserJob(name: name));
  ///   final result = await handle.future;
  ///   return result.data;
  /// }
  /// ```
  ///
  /// ### With Progress Tracking
  /// ```dart
  /// Future<void> uploadFiles(List<File> files) async {
  ///   final handle = dispatch<void>(UploadFilesJob(files));
  ///   handle.progress.listen((p) {
  ///     state = state.copyWith(uploadProgress: p.value);
  ///   });
  ///   await handle.future;
  /// }
  /// ```
  JobHandle<T> dispatch<T>(EventJob job) {
    _ensureSubscribed();

    // Attach bus to job context for Executor to use
    job.bus = bus;

    // Create handle for this job
    final handle = JobHandle<T>(job.id);

    // Track job
    _activeJobIds.add(job.id);

    // Auto-cleanup when job completes
    handle.future.whenComplete(() {
      Future.delayed(const Duration(milliseconds: 50), () {
        _activeJobIds.remove(job.id);
      });
    });

    dispatcher.dispatch(job, handle: handle);
    return handle;
  }

  void _ensureSubscribed() {
    if (_busSubscription == null && !_isDisposed) {
      _subscribeToBus();
    }
  }

  /// Cancel tracking for a job (does not cancel the job itself).
  void cancelJob(String jobId) {
    _activeJobIds.remove(jobId);
  }

  void _subscribeToBus() {
    _busSubscription?.cancel();
    _busSubscription = bus.stream.listen(_routeEvent);
  }

  void _routeEvent(BaseEvent event) {
    if (_isDisposed) return;
    onEvent(event);
  }

  // ============ Event Handler ============

  /// Unified handler for ALL domain events.
  ///
  /// This is the single entry point for all events from the [SignalBus].
  /// Use Dart 3 pattern matching to handle different event types:
  ///
  /// ```dart
  /// @override
  /// void onEvent(BaseEvent event) {
  ///   switch (event) {
  ///     case UsersLoadedEvent e:
  ///       state = state.copyWith(users: e.users, isLoading: false);
  ///     case UserCreatedEvent e:
  ///       state = state.copyWith(users: [...state.users, e.user]);
  ///   }
  /// }
  /// ```
  void onEvent(BaseEvent event) {}

  // ============ Lifecycle ============

  /// Dispose resources - called automatically by Riverpod.
  void dispose() {
    _isDisposed = true;
    _busSubscription?.cancel();
    _busSubscription = null;
    _activeJobIds.clear();
  }
}
