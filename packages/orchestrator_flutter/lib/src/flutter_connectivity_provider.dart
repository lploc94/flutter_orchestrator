import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:orchestrator_core/orchestrator_core.dart';

/// Default Connectivity Provider for Flutter apps.
/// Uses [connectivity_plus] to detect network state.
class FlutterConnectivityProvider implements ConnectivityProvider {
  final Connectivity _connectivity = Connectivity();
  
  /// FIX WARNING #9: Cache broadcast stream for multiple listeners
  StreamController<bool>? _broadcastController;
  StreamSubscription? _connectivitySubscription;

  @override
  Future<bool> get isConnected async {
    final results = await _connectivity.checkConnectivity();
    return _hasConnection(results);
  }

  @override
  Stream<bool> get onConnectivityChanged {
    // Lazily create broadcast stream that can have multiple listeners
    if (_broadcastController == null) {
      _broadcastController = StreamController<bool>.broadcast(
        onListen: _startListening,
        onCancel: _checkAndStopListening,
      );
    }
    return _broadcastController!.stream;
  }
  
  void _startListening() {
    _connectivitySubscription ??= _connectivity.onConnectivityChanged.listen(
      (result) {
        if (_broadcastController != null && !_broadcastController!.isClosed) {
          _broadcastController!.add(_hasConnection(result));
        }
      },
      onError: (error) {
        if (_broadcastController != null && !_broadcastController!.isClosed) {
          _broadcastController!.addError(error);
        }
      },
    );
  }
  
  void _checkAndStopListening() {
    // Only stop if no listeners remain
    if (_broadcastController != null && !_broadcastController!.hasListener) {
      _connectivitySubscription?.cancel();
      _connectivitySubscription = null;
    }
  }

  /// FIX WARNING #10: Add dispose method for cleanup
  /// Should be called when the provider is no longer needed (e.g., in tests)
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _broadcastController?.close();
    _broadcastController = null;
  }

  /// Returns true if there is at least one active connection type.
  /// Handles both single ConnectivityResult and List<ConnectivityResult> (v5+).
  bool _hasConnection(dynamic result) {
    if (result is List<ConnectivityResult>) {
      // connectivity_plus v5+ returns List
      if (result.isEmpty) return false;
      return result.any((r) => r != ConnectivityResult.none);
    } else if (result is ConnectivityResult) {
      // Older versions return single result
      return result != ConnectivityResult.none;
    }
    return false;
  }
}
