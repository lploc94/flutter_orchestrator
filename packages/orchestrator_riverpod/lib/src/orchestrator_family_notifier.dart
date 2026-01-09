import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orchestrator_core/orchestrator_core.dart';

/// A Riverpod FamilyNotifier that wraps [BaseOrchestrator] functionality.
///
/// Use this when you need per-entity state (e.g., different state per chamberId).
///
/// ## Usage with NotifierProvider.family
///
/// ```dart
/// class ForageNotifier extends OrchestratorFamilyNotifier<ForageState, String> {
///   late final String _forageId;
///
///   @override
///   ForageState buildState(String forageId) {
///     _forageId = forageId;
///     Future.microtask(() => loadForage());
///     return const ForageState.loading();
///   }
///
///   void loadForage() {
///     dispatch<Forage>(GetForageJob(id: _forageId));
///   }
///
///   @override
///   void onEvent(BaseEvent event) {
///     switch (event) {
///       case ForageLoadedEvent e when e.forage.id == _forageId:
///         state = ForageState.fromForage(e.forage);
///     }
///   }
/// }
///
/// final forageProvider =
///     NotifierProvider.family<ForageNotifier, ForageState, String>(
///   ForageNotifier.new,
/// );
/// ```
abstract class OrchestratorFamilyNotifier<S, Arg> extends FamilyNotifier<S, Arg> {
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
  S build(Arg arg) {
    if (!_isInitialized) {
      _subscribeToBus();
      ref.onDispose(dispose);
      _isInitialized = true;
    }
    return buildState(arg);
  }

  /// Override this method to provide the initial state for a given argument.
  S buildState(Arg arg);

  // ============ Job Tracking ============

  bool get hasActiveJobs => _activeJobIds.isNotEmpty;

  bool isJobRunning(String correlationId) =>
      _activeJobIds.contains(correlationId);

  /// Dispatch a job and start tracking it.
  ///
  /// Returns a [JobHandle] for awaiting results or tracking progress.
  JobHandle<T> dispatch<T>(BaseJob job) {
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
  ///
  /// For Family notifiers, always filter events relevant to THIS instance:
  ///
  /// ```dart
  /// @override
  /// void onEvent(BaseEvent event) {
  ///   switch (event) {
  ///     case ForageLoadedEvent e when e.forage.id == _forageId:
  ///       state = ForageState.fromForage(e.forage);
  ///   }
  /// }
  /// ```
  void onEvent(BaseEvent event) {}

  // ============ Lifecycle ============

  void dispose() {
    _isDisposed = true;
    _busSubscription?.cancel();
    _busSubscription = null;
    _activeJobIds.clear();
  }
}
