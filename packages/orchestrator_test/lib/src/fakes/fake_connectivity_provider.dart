import 'dart:async';

import 'package:orchestrator_core/orchestrator_core.dart';

/// A fake [ConnectivityProvider] for testing offline scenarios.
///
/// This fake allows you to programmatically control the connectivity state
/// and simulate online/offline transitions.
///
/// ## Example
///
/// ```dart
/// final connectivity = FakeConnectivityProvider(isConnected: false);
///
/// // Configure your dispatcher/orchestrator with this provider
/// OrchestratorConfig.setConnectivityProvider(connectivity);
///
/// // Test offline behavior
/// dispatcher.dispatch(NetworkJob());
/// expect(queueManager.hasPendingJobs, isTrue);
///
/// // Simulate coming back online
/// connectivity.goOnline();
/// await Future.delayed(Duration(milliseconds: 100));
///
/// // Verify job was processed
/// expect(queueManager.hasPendingJobs, isFalse);
/// ```
class FakeConnectivityProvider implements ConnectivityProvider {
  /// Creates a [FakeConnectivityProvider].
  ///
  /// [isConnected] sets the initial connectivity state (default: `true`).
  FakeConnectivityProvider({bool isConnected = true})
      : _isConnected = isConnected {
    connectivityHistory.add(isConnected);
  }

  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  bool _isConnected;

  /// History of connectivity changes for verification.
  final List<bool> connectivityHistory = [];

  @override
  Future<bool> get isConnected async => _isConnected;

  /// Synchronous check for connectivity (for convenience in tests).
  bool get isConnectedSync => _isConnected;

  @override
  Stream<bool> get onConnectivityChanged => _controller.stream;

  /// Set the connectivity state and emit a change event.
  ///
  /// Only emits if the state actually changes.
  void setConnected(bool value) {
    if (_isConnected != value) {
      _isConnected = value;
      connectivityHistory.add(value);
      _controller.add(value);
    }
  }

  /// Toggle the connectivity state.
  void toggle() => setConnected(!_isConnected);

  /// Go offline.
  void goOffline() => setConnected(false);

  /// Go online.
  void goOnline() => setConnected(true);

  /// Simulate a temporary disconnection.
  ///
  /// Goes offline, waits for [duration], then comes back online.
  Future<void> simulateDisconnection(Duration duration) async {
    goOffline();
    await Future<void>.delayed(duration);
    goOnline();
  }

  /// Reset to initial state.
  void reset({bool isConnected = true}) {
    _isConnected = isConnected;
    connectivityHistory.clear();
    connectivityHistory.add(isConnected);
  }

  /// Dispose the controller.
  void dispose() {
    _controller.close();
  }
}
