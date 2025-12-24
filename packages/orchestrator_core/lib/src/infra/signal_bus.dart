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
  factory SignalBus() => _instance;

  /// Create a new scoped bus instance (Isolated).
  factory SignalBus.scoped() => SignalBus._internal();

  SignalBus._internal();

  final _controller = StreamController<BaseEvent>.broadcast();

  /// Stream of ALL events running through the system.
  Stream<BaseEvent> get stream => _controller.stream;

  /// Fire an event into the bus.
  /// In a strict architecture, this method should be protected.
  void emit(BaseEvent event) {
    if (!_controller.isClosed) {
      _controller.add(event);
      // Optional: Add simple logging here
      // print('[SignalBus] Emitted: $event');
    }
  }

  /// Close the bus (rarely used in App lifecycle, maybe for testing).
  void dispose() {
    _controller.close();
  }
}
