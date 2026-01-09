import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orchestrator_core/orchestrator_core.dart';

/// A Riverpod AsyncNotifier that wraps [BaseOrchestrator] functionality.
///
/// Use this when your initial state requires async loading.
/// State type is `AsyncValue<S>` (loading/error/data).
///
/// ## Usage with AsyncNotifierProvider
///
/// ```dart
/// class UserNotifier extends OrchestratorAsyncNotifier<UserState> {
///   @override
///   Future<UserState> buildState() async {
///     final handle = dispatch<User>(LoadUserJob());
///     final result = await handle.future;
///     return UserState(user: result.data);
///   }
///
///   Future<void> updateUser(String name) async {
///     state = const AsyncValue.loading();
///     try {
///       final handle = dispatch<User>(UpdateUserJob(name: name));
///       final result = await handle.future;
///       state = AsyncValue.data(UserState(user: result.data));
///     } catch (e, stack) {
///       state = AsyncValue.error(e, stack);
///     }
///   }
/// }
///
/// final userProvider = AsyncNotifierProvider<UserNotifier, UserState>(
///   UserNotifier.new,
/// );
/// ```
abstract class OrchestratorAsyncNotifier<S> extends AsyncNotifier<S> {
  SignalBus _bus = SignalBus.instance;
  Dispatcher _dispatcher = Dispatcher();

  final Set<String> _activeJobIds = {};

  StreamSubscription? _busSubscription;
  bool _isDisposed = false;
  bool _isInitialized = false;

  SignalBus get bus => _bus;
  Dispatcher get dispatcher => _dispatcher;

  void configureForTesting({SignalBus? bus, Dispatcher? dispatcher}) {
    if (bus != null) _bus = bus;
    if (dispatcher != null) _dispatcher = dispatcher;
  }

  @override
  Future<S> build() async {
    if (!_isInitialized) {
      _subscribeToBus();
      ref.onDispose(dispose);
      _isInitialized = true;
    }
    return buildState();
  }

  /// Override this method to provide the initial state asynchronously.
  Future<S> buildState();

  // ============ Job Tracking ============

  bool get hasActiveJobs => _activeJobIds.isNotEmpty;

  bool isJobRunning(String correlationId) =>
      _activeJobIds.contains(correlationId);

  /// Dispatch a job and start tracking it.
  ///
  /// Returns a [JobHandle] for awaiting results or tracking progress.
  JobHandle<T> dispatch<T>(EventJob job) {
    _ensureSubscribed();

    job.bus = bus;
    final handle = JobHandle<T>(job.id);
    _activeJobIds.add(job.id);

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
  void onEvent(BaseEvent event) {}

  // ============ Lifecycle ============

  void dispose() {
    _isDisposed = true;
    _busSubscription?.cancel();
    _busSubscription = null;
    _activeJobIds.clear();
  }
}
