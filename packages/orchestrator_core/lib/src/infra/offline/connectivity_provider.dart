import 'dart:async';

/// Interface for checking network connectivity.
/// Implement this to provide platform-specific connectivity checks (e.g., connectivity_plus).
abstract class ConnectivityProvider {
  /// Check if the device currently has network access.
  Future<bool> get isConnected;

  /// Stream of connectivity changes.
  Stream<bool> get onConnectivityChanged;
}

/// Default implementation assuming always online (for testing/default).
class AlwaysOnlineProvider implements ConnectivityProvider {
  @override
  Future<bool> get isConnected async => true;

  @override
  Stream<bool> get onConnectivityChanged => Stream.value(true);
}
