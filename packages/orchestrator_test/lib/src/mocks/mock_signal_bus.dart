import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:orchestrator_core/orchestrator_core.dart';

/// A mock implementation of [SignalBus] for testing.
///
/// Use this with [mocktail] to stub method calls and verify interactions.
///
/// ## Example
///
/// ```dart
/// final mockBus = MockSignalBus();
///
/// // Stub the stream
/// when(() => mockBus.stream).thenAnswer((_) => Stream.empty());
///
/// // Verify emit was called
/// verify(() => mockBus.emit(any())).called(1);
/// ```
class MockSignalBus extends Mock implements SignalBus {}

/// A fake [SignalBus] that captures all emitted events for verification.
///
/// This fake provides a working stream implementation and captures all
/// emitted events for test assertions.
///
/// ## Example
///
/// ```dart
/// final bus = FakeSignalBus();
///
/// // Listen to events (optional)
/// bus.stream.listen((event) => print(event));
///
/// // Emit an event
/// bus.emit(JobSuccessEvent('job-1', 'data'));
///
/// // Verify captured events
/// expect(bus.emittedEvents, hasLength(1));
/// expect(bus.eventsOfType<JobSuccessEvent>(), hasLength(1));
/// ```
class FakeSignalBus implements SignalBus {
  final StreamController<BaseEvent> _controller =
      StreamController<BaseEvent>.broadcast();

  /// All events that have been emitted.
  final List<BaseEvent> emittedEvents = [];

  @override
  bool get isDisposed => _controller.isClosed;

  @override
  Stream<BaseEvent> get stream => _controller.stream;

  @override
  StreamSubscription<BaseEvent> listen(
    void Function(BaseEvent event) onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  void emit(BaseEvent event) {
    if (!_controller.isClosed) {
      emittedEvents.add(event);
      _controller.add(event);
    }
  }

  @override
  void dispose() {
    _controller.close();
  }

  /// Clear all captured events.
  void clear() {
    emittedEvents.clear();
  }

  /// Get all captured events of a specific type.
  ///
  /// ```dart
  /// final successEvents = bus.eventsOfType<JobSuccessEvent>();
  /// ```
  List<T> eventsOfType<T extends BaseEvent>() {
    return emittedEvents.whereType<T>().toList();
  }

  /// Get the last emitted event, or `null` if none.
  BaseEvent? get lastEvent => emittedEvents.isEmpty ? null : emittedEvents.last;

  /// Get the last emitted event of a specific type, or `null` if none.
  T? lastEventOfType<T extends BaseEvent>() {
    final events = eventsOfType<T>();
    return events.isEmpty ? null : events.last;
  }

  /// Check if any event of a specific type was emitted.
  bool hasEventOfType<T extends BaseEvent>() {
    return emittedEvents.any((e) => e is T);
  }

  /// Wait for the next event to be emitted.
  ///
  /// Throws [TimeoutException] if no event is received within [timeout].
  Future<BaseEvent> waitForNext({
    Duration timeout = const Duration(seconds: 5),
  }) {
    return stream.first.timeout(timeout);
  }

  /// Wait for an event of a specific type to be emitted.
  ///
  /// Throws [TimeoutException] if no matching event is received within [timeout].
  Future<T> waitForType<T extends BaseEvent>({
    Duration timeout = const Duration(seconds: 5),
  }) {
    return stream.where((e) => e is T).cast<T>().first.timeout(timeout);
  }
}
