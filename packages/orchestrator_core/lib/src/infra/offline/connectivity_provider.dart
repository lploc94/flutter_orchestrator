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

  /// Creates an [AlwaysOnlineProvider] that always reports online status.
  ///
  /// Immediately emits `true` to the connectivity stream upon creation.
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

/// Mock implementation for testing offline scenarios.
///
/// Example:
/// ```dart
/// final connectivity = MockConnectivityProvider(initialConnected: false);
/// OrchestratorConfig.setConnectivityProvider(connectivity);
///
/// // Simulate going offline
/// connectivity.setConnected(false);
///
/// // Dispatch a NetworkAction job - it will be queued
/// orchestrator.dispatch(SendMessageJob('Hello'));
///
/// // Simulate coming back online - queued jobs will sync
/// connectivity.setConnected(true);
/// ```
class MockConnectivityProvider implements ConnectivityProvider {
  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  bool _isConnected;
  bool _isDisposed = false;

  /// Creates a [MockConnectivityProvider] with optional initial state.
  ///
  /// [initialConnected] defaults to `true`.
  MockConnectivityProvider({bool initialConnected = true})
      : _isConnected = initialConnected;

  @override
  Future<bool> get isConnected async => _isConnected;

  @override
  Stream<bool> get onConnectivityChanged {
    if (_isDisposed) {
      return Stream.value(_isConnected);
    }
    return _controller.stream;
  }

  /// Set connectivity state and emit change event.
  ///
  /// This simulates the device going online/offline.
  void setConnected(bool value) {
    if (_isDisposed) return;
    _isConnected = value;
    _controller.add(value);
  }

  /// Clean up resources.
  void dispose() {
    _isDisposed = true;
    _controller.close();
  }
}
