import 'package:test/test.dart';
import 'package:orchestrator_core/orchestrator_core.dart';

/// Matches a [JobSuccessEvent] with optional data and correlationId checks.
///
/// ## Example
///
/// ```dart
/// expect(event, isJobSuccess());
/// expect(event, isJobSuccess(data: 'expected'));
/// expect(event, isJobSuccess(correlationId: 'job-1'));
/// expect(event, isJobSuccess(data: 'expected', correlationId: 'job-1'));
/// ```
Matcher isJobSuccess({dynamic data, String? correlationId}) {
  return _JobSuccessMatcher(data: data, correlationId: correlationId);
}

class _JobSuccessMatcher extends Matcher {
  _JobSuccessMatcher({this.data, this.correlationId});

  final dynamic data;
  final String? correlationId;

  @override
  bool matches(Object? item, Map matchState) {
    if (item is! JobSuccessEvent) return false;
    if (correlationId != null && item.correlationId != correlationId) {
      return false;
    }
    if (data != null && item.data != data) return false;
    return true;
  }

  @override
  Description describe(Description description) {
    description.add('is JobSuccessEvent');
    if (correlationId != null) {
      description.add(' with correlationId: $correlationId');
    }
    if (data != null) {
      description.add(' with data: $data');
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
    if (item is! JobSuccessEvent) {
      return mismatchDescription.add('is not a JobSuccessEvent');
    }
    if (correlationId != null && item.correlationId != correlationId) {
      return mismatchDescription.add(
        'has correlationId: ${item.correlationId}',
      );
    }
    if (data != null && item.data != data) {
      return mismatchDescription.add('has data: ${item.data}');
    }
    return mismatchDescription;
  }
}

/// Matches a [JobFailureEvent] with optional error type and correlationId checks.
///
/// ## Example
///
/// ```dart
/// expect(event, isJobFailure());
/// expect(event, isJobFailure(errorType: TimeoutException));
/// expect(event, isJobFailure(correlationId: 'job-1'));
/// expect(event, isJobFailure(wasRetried: true));
/// ```
Matcher isJobFailure({
  String? correlationId,
  Type? errorType,
  bool? wasRetried,
}) {
  return _JobFailureMatcher(
    correlationId: correlationId,
    errorType: errorType,
    wasRetried: wasRetried,
  );
}

class _JobFailureMatcher extends Matcher {
  _JobFailureMatcher({this.correlationId, this.errorType, this.wasRetried});

  final String? correlationId;
  final Type? errorType;
  final bool? wasRetried;

  @override
  bool matches(Object? item, Map matchState) {
    if (item is! JobFailureEvent) return false;
    if (correlationId != null && item.correlationId != correlationId) {
      return false;
    }
    if (errorType != null && item.error.runtimeType != errorType) {
      return false;
    }
    if (wasRetried != null && item.wasRetried != wasRetried) {
      return false;
    }
    return true;
  }

  @override
  Description describe(Description description) {
    description.add('is JobFailureEvent');
    if (correlationId != null) {
      description.add(' with correlationId: $correlationId');
    }
    if (errorType != null) {
      description.add(' with error type: $errorType');
    }
    if (wasRetried != null) {
      description.add(' with wasRetried: $wasRetried');
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
    if (item is! JobFailureEvent) {
      return mismatchDescription.add('is not a JobFailureEvent');
    }
    return mismatchDescription.add(
      'has error: ${item.error.runtimeType}, wasRetried: ${item.wasRetried}',
    );
  }
}

/// Matches a [JobProgressEvent] with optional progress and message checks.
///
/// ## Example
///
/// ```dart
/// expect(event, isJobProgress());
/// expect(event, isJobProgress(minProgress: 0.5));
/// expect(event, isJobProgress(message: 'Step 1'));
/// expect(event, isJobProgress(correlationId: 'job-1'));
/// ```
Matcher isJobProgress({
  String? correlationId,
  double? minProgress,
  double? maxProgress,
  String? message,
}) {
  return _JobProgressMatcher(
    correlationId: correlationId,
    minProgress: minProgress,
    maxProgress: maxProgress,
    message: message,
  );
}

class _JobProgressMatcher extends Matcher {
  _JobProgressMatcher({
    this.correlationId,
    this.minProgress,
    this.maxProgress,
    this.message,
  });

  final String? correlationId;
  final double? minProgress;
  final double? maxProgress;
  final String? message;

  @override
  bool matches(Object? item, Map matchState) {
    if (item is! JobProgressEvent) return false;
    if (correlationId != null && item.correlationId != correlationId) {
      return false;
    }
    if (minProgress != null && item.progress < minProgress!) return false;
    if (maxProgress != null && item.progress > maxProgress!) return false;
    if (message != null && item.message != message) return false;
    return true;
  }

  @override
  Description describe(Description description) {
    description.add('is JobProgressEvent');
    if (minProgress != null) description.add(' with progress >= $minProgress');
    if (maxProgress != null) description.add(' with progress <= $maxProgress');
    if (message != null) description.add(' with message: $message');
    return description;
  }

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    if (item is! JobProgressEvent) {
      return mismatchDescription.add('is not a JobProgressEvent');
    }
    return mismatchDescription.add(
      'has progress: ${item.progress}, message: ${item.message}',
    );
  }
}

/// Matches a [JobCancelledEvent] with optional correlationId check.
///
/// ## Example
///
/// ```dart
/// expect(event, isJobCancelled());
/// expect(event, isJobCancelled(correlationId: 'job-1'));
/// ```
Matcher isJobCancelled({String? correlationId}) {
  return _JobCancelledMatcher(correlationId: correlationId);
}

class _JobCancelledMatcher extends Matcher {
  _JobCancelledMatcher({this.correlationId});

  final String? correlationId;

  @override
  bool matches(Object? item, Map matchState) {
    if (item is! JobCancelledEvent) return false;
    if (correlationId != null && item.correlationId != correlationId) {
      return false;
    }
    return true;
  }

  @override
  Description describe(Description description) {
    description.add('is JobCancelledEvent');
    if (correlationId != null) {
      description.add(' with correlationId: $correlationId');
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
    if (item is! JobCancelledEvent) {
      return mismatchDescription.add('is not a JobCancelledEvent');
    }
    return mismatchDescription.add('has correlationId: ${item.correlationId}');
  }
}

/// Matches a [JobTimeoutEvent] with optional correlationId and timeout checks.
///
/// ## Example
///
/// ```dart
/// expect(event, isJobTimeout());
/// expect(event, isJobTimeout(timeout: Duration(seconds: 30)));
/// ```
Matcher isJobTimeout({String? correlationId, Duration? timeout}) {
  return _JobTimeoutMatcher(correlationId: correlationId, timeout: timeout);
}

class _JobTimeoutMatcher extends Matcher {
  _JobTimeoutMatcher({this.correlationId, this.timeout});

  final String? correlationId;
  final Duration? timeout;

  @override
  bool matches(Object? item, Map matchState) {
    if (item is! JobTimeoutEvent) return false;
    if (correlationId != null && item.correlationId != correlationId) {
      return false;
    }
    if (timeout != null && item.timeout != timeout) return false;
    return true;
  }

  @override
  Description describe(Description description) {
    description.add('is JobTimeoutEvent');
    if (correlationId != null) {
      description.add(' with correlationId: $correlationId');
    }
    if (timeout != null) {
      description.add(' with timeout: $timeout');
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
    if (item is! JobTimeoutEvent) {
      return mismatchDescription.add('is not a JobTimeoutEvent');
    }
    return mismatchDescription.add('has timeout: ${item.timeout}');
  }
}

/// Matches a list of events emitted in a specific order.
///
/// Each event in the list must match the corresponding matcher in order.
/// The list can have more events than matchers (extra events are ignored).
///
/// ## Example
///
/// ```dart
/// expect(
///   events,
///   emitsEventsInOrder([
///     isJobProgress(minProgress: 0.25),
///     isJobProgress(minProgress: 0.50),
///     isJobSuccess(data: 'result'),
///   ]),
/// );
/// ```
Matcher emitsEventsInOrder(List<Matcher> matchers) {
  return _EmitsEventsInOrderMatcher(matchers);
}

class _EmitsEventsInOrderMatcher extends Matcher {
  _EmitsEventsInOrderMatcher(this.matchers);

  final List<Matcher> matchers;

  @override
  bool matches(Object? item, Map matchState) {
    if (item is! List<BaseEvent>) return false;
    if (item.length < matchers.length) return false;

    for (var i = 0; i < matchers.length; i++) {
      if (!matchers[i].matches(item[i], matchState)) return false;
    }
    return true;
  }

  @override
  Description describe(Description description) {
    return description.add(
      'emits ${matchers.length} events matching matchers in order',
    );
  }

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    if (item is! List<BaseEvent>) {
      return mismatchDescription.add('is not a List<BaseEvent>');
    }
    if (item.length < matchers.length) {
      return mismatchDescription.add(
        'has ${item.length} events, expected at least ${matchers.length}',
      );
    }

    for (var i = 0; i < matchers.length; i++) {
      if (!matchers[i].matches(item[i], matchState)) {
        return mismatchDescription.add(
          'event at index $i does not match: ${item[i].runtimeType}',
        );
      }
    }
    return mismatchDescription;
  }
}

/// Matches a list of events containing events that match all matchers.
///
/// Unlike [emitsEventsInOrder], this matcher does not require events
/// to be in a specific order, but all matchers must find a matching event.
///
/// ## Example
///
/// ```dart
/// expect(
///   events,
///   emitsEventsContaining([
///     isJobSuccess(),
///     isJobProgress(),
///   ]),
/// );
/// ```
Matcher emitsEventsContaining(List<Matcher> matchers) {
  return _EmitsEventsContainingMatcher(matchers);
}

class _EmitsEventsContainingMatcher extends Matcher {
  _EmitsEventsContainingMatcher(this.matchers);

  final List<Matcher> matchers;

  @override
  bool matches(Object? item, Map matchState) {
    if (item is! List<BaseEvent>) return false;

    for (final matcher in matchers) {
      final found = item.any((e) => matcher.matches(e, matchState));
      if (!found) return false;
    }
    return true;
  }

  @override
  Description describe(Description description) {
    return description.add(
      'emits events containing ${matchers.length} matching events',
    );
  }

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    if (item is! List<BaseEvent>) {
      return mismatchDescription.add('is not a List<BaseEvent>');
    }

    for (var i = 0; i < matchers.length; i++) {
      final found = item.any((e) => matchers[i].matches(e, matchState));
      if (!found) {
        matchers[i].describe(
          mismatchDescription.add('missing event matching: '),
        );
        return mismatchDescription;
      }
    }
    return mismatchDescription;
  }
}
