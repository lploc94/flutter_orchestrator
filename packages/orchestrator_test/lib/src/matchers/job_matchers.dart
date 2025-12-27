import 'package:test/test.dart';
import 'package:orchestrator_core/orchestrator_core.dart';

/// Matches a job of a specific type.
///
/// ## Example
///
/// ```dart
/// expect(job, isJobOfType<MyJob>());
/// ```
Matcher isJobOfType<T extends BaseJob>() {
  return isA<T>();
}

/// Matches a job with a specific ID.
///
/// ## Example
///
/// ```dart
/// expect(job, hasJobId('my-job-id'));
/// ```
Matcher hasJobId(String id) {
  return _HasJobIdMatcher(id);
}

class _HasJobIdMatcher extends Matcher {
  _HasJobIdMatcher(this.expectedId);

  final String expectedId;

  @override
  bool matches(Object? item, Map matchState) {
    if (item is! BaseJob) return false;
    return item.id == expectedId;
  }

  @override
  Description describe(Description description) {
    return description.add('has job id: $expectedId');
  }

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    if (item is! BaseJob) {
      return mismatchDescription.add('is not a BaseJob');
    }
    return mismatchDescription.add('has id: ${item.id}');
  }
}

/// Matches a job with a specific timeout.
///
/// ## Example
///
/// ```dart
/// expect(job, hasTimeout(Duration(seconds: 30)));
/// ```
Matcher hasTimeout(Duration timeout) {
  return _HasTimeoutMatcher(timeout);
}

class _HasTimeoutMatcher extends Matcher {
  _HasTimeoutMatcher(this.expectedTimeout);

  final Duration expectedTimeout;

  @override
  bool matches(Object? item, Map matchState) {
    if (item is! BaseJob) return false;
    return item.timeout == expectedTimeout;
  }

  @override
  Description describe(Description description) {
    return description.add('has timeout: $expectedTimeout');
  }

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    if (item is! BaseJob) {
      return mismatchDescription.add('is not a BaseJob');
    }
    return mismatchDescription.add('has timeout: ${item.timeout}');
  }
}

/// Matches a job with a cancellation token.
///
/// ## Example
///
/// ```dart
/// expect(job, hasCancellationToken());
/// ```
Matcher hasCancellationToken() {
  return _HasCancellationTokenMatcher();
}

class _HasCancellationTokenMatcher extends Matcher {
  @override
  bool matches(Object? item, Map matchState) {
    if (item is! BaseJob) return false;
    return item.cancellationToken != null;
  }

  @override
  Description describe(Description description) {
    return description.add('has a cancellation token');
  }

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    if (item is! BaseJob) {
      return mismatchDescription.add('is not a BaseJob');
    }
    return mismatchDescription.add('has no cancellation token');
  }
}

/// Matches a job with a retry policy.
///
/// ## Example
///
/// ```dart
/// expect(job, hasRetryPolicy());
/// expect(job, hasRetryPolicy(maxRetries: 3));
/// ```
Matcher hasRetryPolicy({int? maxRetries}) {
  return _HasRetryPolicyMatcher(maxRetries: maxRetries);
}

class _HasRetryPolicyMatcher extends Matcher {
  _HasRetryPolicyMatcher({this.maxRetries});

  final int? maxRetries;

  @override
  bool matches(Object? item, Map matchState) {
    if (item is! BaseJob) return false;
    final policy = item.retryPolicy;
    if (policy == null) return false;
    if (maxRetries != null && policy.maxRetries != maxRetries) return false;
    return true;
  }

  @override
  Description describe(Description description) {
    description.add('has a retry policy');
    if (maxRetries != null) {
      description.add(' with maxRetries: $maxRetries');
    }
    return description;
  }

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    if (item is! BaseJob) {
      return mismatchDescription.add('is not a BaseJob');
    }
    if (item.retryPolicy == null) {
      return mismatchDescription.add('has no retry policy');
    }
    return mismatchDescription.add(
      'has retry policy with maxRetries: ${item.retryPolicy!.maxRetries}',
    );
  }
}

/// Matches a list containing a job of a specific type.
///
/// ## Example
///
/// ```dart
/// expect(dispatcher.dispatchedJobs, containsJobOfType<MyJob>());
/// ```
Matcher containsJobOfType<T extends BaseJob>() {
  return contains(isA<T>());
}

/// Matches a list containing exactly N jobs of a specific type.
///
/// ## Example
///
/// ```dart
/// expect(dispatcher.dispatchedJobs, hasJobCount<MyJob>(2));
/// ```
Matcher hasJobCount<T extends BaseJob>(int count) {
  return _HasJobCountMatcher<T>(count);
}

class _HasJobCountMatcher<T extends BaseJob> extends Matcher {
  _HasJobCountMatcher(this.expectedCount);

  final int expectedCount;

  @override
  bool matches(Object? item, Map matchState) {
    if (item is! List<BaseJob>) return false;
    return item.whereType<T>().length == expectedCount;
  }

  @override
  Description describe(Description description) {
    return description.add('contains $expectedCount jobs of type $T');
  }

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    if (item is! List<BaseJob>) {
      return mismatchDescription.add('is not a List<BaseJob>');
    }
    final count = item.whereType<T>().length;
    return mismatchDescription.add('contains $count jobs of type $T');
  }
}
