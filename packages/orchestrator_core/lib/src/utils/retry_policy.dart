import 'dart:async';

/// Retry configuration for failed jobs.
class RetryPolicy {
  /// Maximum number of retry attempts.
  final int maxRetries;

  /// Base delay between retries (will be multiplied for exponential backoff).
  final Duration baseDelay;

  /// Whether to use exponential backoff.
  final bool exponentialBackoff;

  /// Maximum delay cap for exponential backoff.
  final Duration maxDelay;

  /// Optional: Only retry for specific error types.
  final bool Function(Object error)? shouldRetry;

  const RetryPolicy({
    this.maxRetries = 3,
    this.baseDelay = const Duration(seconds: 1),
    this.exponentialBackoff = true,
    this.maxDelay = const Duration(seconds: 30),
    this.shouldRetry,
  });

  /// Calculate delay for the nth attempt (0-indexed).
  Duration getDelay(int attempt) {
    if (!exponentialBackoff) return baseDelay;

    final delay = baseDelay * (1 << attempt); // 2^attempt
    return delay > maxDelay ? maxDelay : delay;
  }

  /// Check if we should retry for this error.
  bool canRetry(Object error, int currentAttempt) {
    if (currentAttempt >= maxRetries) return false;
    if (shouldRetry != null) return shouldRetry!(error);
    return true; // Default: retry all errors
  }
}

/// Execute a function with retry logic.
Future<T> executeWithRetry<T>(
  Future<T> Function() action,
  RetryPolicy policy, {
  void Function(Object error, int attempt)? onRetry,
}) async {
  int attempt = 0;

  while (true) {
    try {
      return await action();
    } catch (e) {
      if (!policy.canRetry(e, attempt)) {
        rethrow;
      }

      onRetry?.call(e, attempt);

      await Future.delayed(policy.getDelay(attempt));
      attempt++;
    }
  }
}
