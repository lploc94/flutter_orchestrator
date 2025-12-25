import 'dart:async';

/// Interface for checking network connectivity.
/// Implement this to provide platform-specific connectivity checks (e.g., connectivity_plus).
abstract class ConnectivityProvider {
  /// Check if the device currently has network access.
  Future<bool> get isConnected;

  /// Stream of connectivity changes.
  ///
  /// This stream should:
  /// - Be a broadcast stream (multiple listeners allowed)
  /// - Not complete during normal app lifecycle
  /// - Emit current state when subscribed (optional but recommended)
  Stream<bool> get onConnectivityChanged;
}

/// Default implementation assuming always online (for testing/default).
///
/// Note: The [onConnectivityChanged] stream in this implementation never
/// emits after the initial value. For production, use a real implementation
/// like one based on `connectivity_plus` package.
class AlwaysOnlineProvider implements ConnectivityProvider {
  // Use a broadcast controller that never closes
  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  bool _isDisposed = false;

  AlwaysOnlineProvider() {
    // Emit initial value
    _controller.add(true);
  }

  @override
  Future<bool> get isConnected async => true;

  @override
  Stream<bool> get onConnectivityChanged {
    if (_isDisposed) {
      // Return a stream that just emits true once if disposed
      return Stream.value(true);
    }
    return _controller.stream;
  }

  /// Dispose resources (for testing).
  void dispose() {
    _isDisposed = true;
    _controller.close();
  }
}
