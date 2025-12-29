import 'dart:async';
import '../models/event.dart';

/// The Central Nervous System.
/// A simple, high-performance Event Bus using Dart Streams.
///
/// Security Note for Devs:
/// - This class should stay Internal in a real app.
/// - Only Executors should be allowed to `emit`.
class SignalBus {
  // Singleton Pattern
  static final SignalBus _instance = SignalBus._internal();

  /// Get the global singleton instance.
  static SignalBus get instance => _instance;

  /// Default constructor returns the global instance (Backward Compatibility).
  /// Note: Consider using [SignalBus.instance] for clarity.
  factory SignalBus() => _instance;

  /// Create a new scoped bus instance (Isolated).
  factory SignalBus.scoped() => SignalBus._internal();

  SignalBus._internal();

  final _controller = StreamController<BaseEvent>.broadcast();

  /// Check if the bus has been disposed.
  bool get isDisposed => _controller.isClosed;

  /// Stream of ALL events running through the system.
  /// Throws [StateError] if the bus has been disposed.
  Stream<BaseEvent> get stream {
    if (_controller.isClosed) {
      throw StateError(
        'SignalBus has been disposed. Cannot access stream after disposal.',
      );
    }
    return _controller.stream;
  }

  /// Convenience method to listen to events.
  ///
  /// Equivalent to `stream.listen(onData)`.
  ///
  /// Example:
  /// ```dart
  /// final subscription = bus.listen((event) {
  ///   print('Received: $event');
  /// });
  /// ```
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

  /// Fire an event into the bus.
  /// In a strict architecture, this method should be protected.
  /// Silently ignores if bus is disposed (prevents crashes during cleanup).
  void emit(BaseEvent event) {
    if (!_controller.isClosed) {
      _controller.add(event);
      // Optional: Add simple logging here
      // print('[SignalBus] Emitted: $event');
    }
  }

  /// Close the bus (rarely used in App lifecycle, maybe for testing).
  ///
  /// WARNING: For the global [instance], calling dispose will make it
  /// permanently unusable. Only dispose scoped buses or in test teardown.
  void dispose() {
    if (!_controller.isClosed) {
      _controller.close();
    }
  }
}
