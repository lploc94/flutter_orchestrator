/// Cancellation support for long-running jobs.
///
/// Usage:
/// ```dart
/// final token = CancellationToken();
/// orchestrator.dispatch(MyJob(cancellationToken: token));
/// // Later...
/// token.cancel();
/// ```
class CancellationToken {
  bool _isCancelled = false;
  final List<void Function()> _listeners = [];

  /// Whether cancellation has been requested.
  bool get isCancelled => _isCancelled;

  /// Number of registered listeners (useful for debugging/testing).
  int get listenerCount => _listeners.length;

  /// Request cancellation.
  ///
  /// All registered callbacks will be invoked immediately,
  /// then cleared to prevent memory leaks.
  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;
    // Create copy to avoid issues if listener modifies the list
    final listenersCopy = List<void Function()>.from(_listeners);
    _listeners.clear();
    for (final listener in listenersCopy) {
      try {
        listener();
      } catch (_) {
        // Ignore errors in listeners to prevent one from blocking others
      }
    }
  }

  /// Register a callback when cancellation is requested.
  ///
  /// If already cancelled, the callback is invoked immediately.
  /// Returns a function that can be called to unregister this listener.
  void Function() onCancel(void Function() callback) {
    if (_isCancelled) {
      callback();
      return () {}; // No-op unregister since already cancelled
    } else {
      _listeners.add(callback);
      return () => removeListener(callback);
    }
  }

  /// Remove a previously registered callback.
  ///
  /// Safe to call even if the callback was never registered.
  void removeListener(void Function() callback) {
    _listeners.remove(callback);
  }

  /// Clear all listeners without triggering cancellation.
  ///
  /// Useful for cleanup when the associated job completes normally.
  void clearListeners() {
    _listeners.clear();
  }

  /// Throws [CancelledException] if cancelled.
  void throwIfCancelled() {
    if (_isCancelled) {
      throw CancelledException();
    }
  }
}

/// Exception thrown when an operation is cancelled.
class CancelledException implements Exception {
  /// Optional reason for cancellation.
  final String? reason;

  CancelledException([this.reason]);

  @override
  String toString() {
    if (reason != null) {
      return 'CancelledException: $reason';
    }
    return 'CancelledException: Operation was cancelled.';
  }
}
