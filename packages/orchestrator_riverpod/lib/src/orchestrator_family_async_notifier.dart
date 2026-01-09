import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orchestrator_core/orchestrator_core.dart';

/// A Riverpod FamilyAsyncNotifier that wraps [BaseOrchestrator] functionality.
///
/// Use this when you need both per-entity state AND async initialization.
///
/// ## Usage with AsyncNotifierProvider.family
///
/// ```dart
/// class ChamberDetailsNotifier
///     extends OrchestratorFamilyAsyncNotifier<ChamberDetails, String> {
///   late final String _chamberId;
///
///   @override
///   Future<ChamberDetails> buildState(String chamberId) async {
///     _chamberId = chamberId;
///     final handle = dispatch<Chamber>(GetChamberJob(id: chamberId));
///     final result = await handle.future;
///     return ChamberDetails.fromChamber(result.data);
///   }
///
///   @override
///   void onEvent(BaseEvent event) {
///     switch (event) {
///       case ChamberUpdatedEvent e when e.chamber.id == _chamberId:
///         state = AsyncValue.data(ChamberDetails.fromChamber(e.chamber));
///     }
///   }
/// }
///
/// final chamberDetailsProvider =
///     AsyncNotifierProvider.family<ChamberDetailsNotifier, ChamberDetails, String>(
///   ChamberDetailsNotifier.new,
/// );
/// ```
abstract class OrchestratorFamilyAsyncNotifier<S, Arg>
    extends FamilyAsyncNotifier<S, Arg> {
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
  Future<S> build(Arg arg) async {
    if (!_isInitialized) {
      _subscribeToBus();
      ref.onDispose(dispose);
      _isInitialized = true;
    }
    return buildState(arg);
  }

  /// Override this method to provide the initial state for a given argument.
  Future<S> buildState(Arg arg);

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
  ///
  /// For Family notifiers, filter events relevant to THIS instance:
  ///
  /// ```dart
  /// @override
  /// void onEvent(BaseEvent event) {
  ///   switch (event) {
  ///     case ChamberUpdatedEvent e when e.chamber.id == _chamberId:
  ///       state = AsyncValue.data(ChamberDetails.fromChamber(e.chamber));
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
