import '../models/job.dart';
import '../models/data_strategy.dart';
import 'cancellation_token.dart';
import 'retry_policy.dart';

/// Builder pattern for creating jobs with fluent API.
///
/// This simplifies job creation when you need to configure multiple options.
///
/// Example:
/// ```dart
/// final job = JobBuilder(FetchUserJob(userId))
///     .withTimeout(Duration(seconds: 30))
///     .withRetry(maxRetries: 3)
///     .withCache(key: 'user_$userId', ttl: Duration(minutes: 5))
///     .build();
/// ```
class JobBuilder<T extends BaseJob> {
  final T _job;
  Duration? _timeout;
  CancellationToken? _cancellationToken;
  RetryPolicy? _retryPolicy;
  DataStrategy? _strategy;
  Map<String, dynamic>? _metadata;

  JobBuilder(this._job);

  /// Set a timeout for the job.
  JobBuilder<T> withTimeout(Duration timeout) {
    _timeout = timeout;
    return this;
  }

  /// Set a cancellation token for the job.
  JobBuilder<T> withCancellation(CancellationToken token) {
    _cancellationToken = token;
    return this;
  }

  /// Create and attach a new cancellation token.
  /// Returns the token so you can cancel later.
  (JobBuilder<T>, CancellationToken) withNewCancellation() {
    final token = CancellationToken();
    _cancellationToken = token;
    return (this, token);
  }

  /// Configure retry policy.
  JobBuilder<T> withRetry({
    int maxRetries = 3,
    Duration baseDelay = const Duration(seconds: 1),
    bool exponentialBackoff = true,
    Duration maxDelay = const Duration(seconds: 30),
    bool Function(Object error)? shouldRetry,
  }) {
    _retryPolicy = RetryPolicy(
      maxRetries: maxRetries,
      baseDelay: baseDelay,
      exponentialBackoff: exponentialBackoff,
      maxDelay: maxDelay,
      shouldRetry: shouldRetry,
    );
    return this;
  }

  /// Configure cache policy (SWR by default).
  JobBuilder<T> withCache({
    required String key,
    Duration? ttl,
    bool revalidate = true,
    bool forceRefresh = false,
  }) {
    _strategy = DataStrategy(
      placeholder: _strategy?.placeholder,
      cachePolicy: CachePolicy(
        key: key,
        ttl: ttl,
        revalidate: revalidate,
        forceRefresh: forceRefresh,
      ),
    );
    return this;
  }

  /// Set a placeholder for optimistic UI.
  JobBuilder<T> withPlaceholder(dynamic placeholder) {
    _strategy = DataStrategy(
      placeholder: placeholder,
      cachePolicy: _strategy?.cachePolicy,
    );
    return this;
  }

  /// Add metadata to the job.
  JobBuilder<T> withMetadata(Map<String, dynamic> metadata) {
    _metadata = {...?_metadata, ...metadata};
    return this;
  }

  /// Build the configured job.
  ///
  /// Note: Since Dart classes are immutable by design, this creates a new
  /// wrapper that holds the configuration. The original job's properties
  /// are preserved.
  ConfiguredJob<T> build() {
    return ConfiguredJob<T>(
      original: _job,
      timeout: _timeout,
      cancellationToken: _cancellationToken,
      retryPolicy: _retryPolicy,
      strategy: _strategy,
      metadata: _metadata,
    );
  }
}

/// A job wrapper that holds additional configuration.
///
/// This is returned by [JobBuilder.build()] and can be dispatched
/// like any other job.
class ConfiguredJob<T extends BaseJob> extends BaseJob {
  /// The original job being wrapped.
  final T original;

  ConfiguredJob({
    required this.original,
    super.timeout,
    super.cancellationToken,
    super.retryPolicy,
    super.strategy,
    super.metadata,
  }) : super(id: original.id);

  @override
  String toString() => 'ConfiguredJob<${T.runtimeType}>(id: $id)';
}
