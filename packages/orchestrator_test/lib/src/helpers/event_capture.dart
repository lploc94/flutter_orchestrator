import 'dart:async';

import 'package:orchestrator_core/orchestrator_core.dart';

/// Captures events from a [SignalBus] for testing verification.
///
/// Useful when you need to verify that specific events are emitted
/// in response to actions, or to wait for async events to complete.
///
/// ## Example
///
/// ```dart
/// final capture = EventCapture();
///
/// // Perform actions that emit events
/// dispatcher.dispatch(MyJob());
///
/// // Wait for a specific event type
/// final successEvent = await capture.waitFor<JobSuccessEvent>();
/// expect(successEvent.data, equals('expected'));
///
/// // Verify all captured events
/// expect(capture.events, hasLength(2));
/// expect(capture.ofType<JobSuccessEvent>(), hasLength(1));
///
/// // Clean up
/// await capture.dispose();
/// ```
class EventCapture {
  /// Creates an [EventCapture] that listens to the global [SignalBus].
  ///
  /// If [bus] is provided, it will listen to that bus instead.
  EventCapture([SignalBus? bus]) : _bus = bus ?? SignalBus() {
    _subscription = _bus.stream.listen(events.add);
  }

  final SignalBus _bus;
  late final StreamSubscription<BaseEvent> _subscription;

  /// All captured events in order of emission.
  final List<BaseEvent> events = [];

  /// Wait for an event of type [T] to be captured.
  ///
  /// If an event of type [T] has already been captured, returns it immediately.
  /// Otherwise, waits for a new event of type [T] to be emitted.
  ///
  /// Throws [TimeoutException] if no matching event is received within [timeout].
  ///
  /// ## Example
  ///
  /// ```dart
  /// final successEvent = await capture.waitFor<JobSuccessEvent>();
  /// final progressEvent = await capture.waitFor<JobProgressEvent>(
  ///   timeout: Duration(seconds: 10),
  /// );
  /// ```
  Future<T> waitFor<T extends BaseEvent>({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    // Check if already captured
    final existing = events.whereType<T>().firstOrNull;
    if (existing != null) return existing;

    final completer = Completer<T>();

    final subscription = _bus.stream.listen((event) {
      if (event is T && !completer.isCompleted) {
        completer.complete(event);
      }
    });

    try {
      return await completer.future.timeout(timeout);
    } finally {
      await subscription.cancel();
    }
  }

  /// Wait for an event matching a predicate.
  ///
  /// ```dart
  /// final event = await capture.waitForMatching<JobSuccessEvent>(
  ///   (e) => e.correlationId == 'my-job-id',
  /// );
  /// ```
  Future<T> waitForMatching<T extends BaseEvent>(
    bool Function(T event) predicate, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    // Check if already captured
    final existing = events.whereType<T>().where(predicate).firstOrNull;
    if (existing != null) return existing;

    final completer = Completer<T>();

    final subscription = _bus.stream.listen((event) {
      if (event is T && predicate(event) && !completer.isCompleted) {
        completer.complete(event);
      }
    });

    try {
      return await completer.future.timeout(timeout);
    } finally {
      await subscription.cancel();
    }
  }

  /// Get all captured events of type [T].
  List<T> ofType<T extends BaseEvent>() {
    return events.whereType<T>().toList();
  }

  /// Get the last captured event, or `null` if none.
  BaseEvent? get last => events.isEmpty ? null : events.last;

  /// Get the last captured event of type [T], or `null` if none.
  T? lastOfType<T extends BaseEvent>() {
    final typed = ofType<T>();
    return typed.isEmpty ? null : typed.last;
  }

  /// Get the first captured event, or `null` if none.
  BaseEvent? get first => events.isEmpty ? null : events.first;

  /// Get the first captured event of type [T], or `null` if none.
  T? firstOfType<T extends BaseEvent>() {
    return events.whereType<T>().firstOrNull;
  }

  /// Check if any event of type [T] was captured.
  bool hasType<T extends BaseEvent>() {
    return events.any((e) => e is T);
  }

  /// Get the number of captured events.
  int get length => events.length;

  /// Check if no events were captured.
  bool get isEmpty => events.isEmpty;

  /// Check if any events were captured.
  bool get isNotEmpty => events.isNotEmpty;

  /// Clear all captured events.
  void clear() => events.clear();

  /// Dispose the capture and stop listening to events.
  Future<void> dispose() async {
    await _subscription.cancel();
  }
}
