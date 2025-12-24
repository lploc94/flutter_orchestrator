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

  bool get isCancelled => _isCancelled;

  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;
    for (final listener in _listeners) {
      listener();
    }
    _listeners.clear();
  }

  /// Register a callback when cancellation is requested.
  void onCancel(void Function() callback) {
    if (_isCancelled) {
      callback();
    } else {
      _listeners.add(callback);
    }
  }

  /// Throws [CancelledException] if cancelled.
  void throwIfCancelled() {
    if (_isCancelled) {
      throw CancelledException();
    }
  }
}

class CancelledException implements Exception {
  @override
  String toString() => 'CancelledException: Operation was cancelled.';
}
