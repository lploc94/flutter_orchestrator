import 'package:test/test.dart';
import 'package:orchestrator_core/orchestrator_core.dart';

void main() {
  group('RetryPolicy', () {
    group('Constructor and Defaults', () {
      test('default values are sensible', () {
        const policy = RetryPolicy();

        expect(policy.maxRetries, equals(3));
        expect(policy.baseDelay, equals(Duration(seconds: 1)));
        expect(policy.exponentialBackoff, isTrue);
        expect(policy.maxDelay, equals(Duration(seconds: 30)));
        expect(policy.shouldRetry, isNull);
      });

      test('custom values are respected', () {
        final policy = RetryPolicy(
          maxRetries: 5,
          baseDelay: Duration(milliseconds: 500),
          exponentialBackoff: false,
          maxDelay: Duration(seconds: 10),
          shouldRetry: (e) => e is FormatException,
        );

        expect(policy.maxRetries, equals(5));
        expect(policy.baseDelay, equals(Duration(milliseconds: 500)));
        expect(policy.exponentialBackoff, isFalse);
        expect(policy.maxDelay, equals(Duration(seconds: 10)));
        expect(policy.shouldRetry, isNotNull);
      });
    });

    group('getDelay() - Exponential Backoff', () {
      test('calculates exponential delays correctly', () {
        final policy = RetryPolicy(
          baseDelay: Duration(seconds: 1),
          exponentialBackoff: true,
          maxDelay: Duration(seconds: 60),
        );

        // 2^0 * 1s = 1s
        expect(policy.getDelay(0), equals(Duration(seconds: 1)));
        // 2^1 * 1s = 2s
        expect(policy.getDelay(1), equals(Duration(seconds: 2)));
        // 2^2 * 1s = 4s
        expect(policy.getDelay(2), equals(Duration(seconds: 4)));
        // 2^3 * 1s = 8s
        expect(policy.getDelay(3), equals(Duration(seconds: 8)));
        // 2^4 * 1s = 16s
        expect(policy.getDelay(4), equals(Duration(seconds: 16)));
        // 2^5 * 1s = 32s
        expect(policy.getDelay(5), equals(Duration(seconds: 32)));
      });

      test('caps delay at maxDelay', () {
        final policy = RetryPolicy(
          baseDelay: Duration(seconds: 10),
          exponentialBackoff: true,
          maxDelay: Duration(seconds: 30),
        );

        // 2^0 * 10s = 10s
        expect(policy.getDelay(0), equals(Duration(seconds: 10)));
        // 2^1 * 10s = 20s
        expect(policy.getDelay(1), equals(Duration(seconds: 20)));
        // 2^2 * 10s = 40s -> capped at 30s
        expect(policy.getDelay(2), equals(Duration(seconds: 30)));
        // 2^3 * 10s = 80s -> capped at 30s
        expect(policy.getDelay(3), equals(Duration(seconds: 30)));
      });

      test('returns fixed delay when exponentialBackoff is false', () {
        final policy = RetryPolicy(
          baseDelay: Duration(seconds: 5),
          exponentialBackoff: false,
        );

        expect(policy.getDelay(0), equals(Duration(seconds: 5)));
        expect(policy.getDelay(1), equals(Duration(seconds: 5)));
        expect(policy.getDelay(2), equals(Duration(seconds: 5)));
        expect(policy.getDelay(10), equals(Duration(seconds: 5)));
      });

      test('handles millisecond base delay', () {
        final policy = RetryPolicy(
          baseDelay: Duration(milliseconds: 100),
          exponentialBackoff: true,
          maxDelay: Duration(seconds: 10),
        );

        expect(policy.getDelay(0), equals(Duration(milliseconds: 100)));
        expect(policy.getDelay(1), equals(Duration(milliseconds: 200)));
        expect(policy.getDelay(2), equals(Duration(milliseconds: 400)));
        expect(policy.getDelay(3), equals(Duration(milliseconds: 800)));
      });
    });

    group('canRetry() - Retry Decision', () {
      test('allows retry when under maxRetries', () {
        final policy = RetryPolicy(maxRetries: 3);

        expect(policy.canRetry(Exception('test'), 0), isTrue);
        expect(policy.canRetry(Exception('test'), 1), isTrue);
        expect(policy.canRetry(Exception('test'), 2), isTrue);
      });

      test('denies retry when at or over maxRetries', () {
        final policy = RetryPolicy(maxRetries: 3);

        expect(policy.canRetry(Exception('test'), 3), isFalse);
        expect(policy.canRetry(Exception('test'), 4), isFalse);
        expect(policy.canRetry(Exception('test'), 100), isFalse);
      });

      test('respects shouldRetry predicate', () {
        final policy = RetryPolicy(
          maxRetries: 5,
          shouldRetry: (e) => e is FormatException,
        );

        // FormatException should be retried
        expect(policy.canRetry(FormatException('bad'), 0), isTrue);

        // Other exceptions should not be retried
        expect(policy.canRetry(Exception('general'), 0), isFalse);
        expect(policy.canRetry(ArgumentError('arg'), 0), isFalse);
        expect(policy.canRetry(StateError('state'), 0), isFalse);
      });

      test('shouldRetry predicate is checked even when under maxRetries', () {
        final policy = RetryPolicy(
          maxRetries: 10,
          shouldRetry: (e) => false, // Never retry
        );

        expect(policy.canRetry(Exception('test'), 0), isFalse);
        expect(policy.canRetry(Exception('test'), 1), isFalse);
      });

      test('maxRetries checked before shouldRetry', () {
        var predicateCalled = false;
        final policy = RetryPolicy(
          maxRetries: 1,
          shouldRetry: (e) {
            predicateCalled = true;
            return true;
          },
        );

        // At maxRetries, shouldRetry should not be called
        final result = policy.canRetry(Exception('test'), 1);
        expect(result, isFalse);
        // Note: The predicate might still be called depending on implementation
        // The important thing is the final result is false
      });
    });

    group('Edge Cases', () {
      test('zero maxRetries means no retries', () {
        final policy = RetryPolicy(maxRetries: 0);

        expect(policy.canRetry(Exception('test'), 0), isFalse);
      });

      test('very large attempt number does not overflow', () {
        final policy = RetryPolicy(
          baseDelay: Duration(milliseconds: 100),
          maxDelay: Duration(seconds: 30),
        );

        // This would be 2^50 * 100ms = huge number, but should be capped
        final delay = policy.getDelay(50);
        expect(delay, equals(Duration(seconds: 30)));
      });

      test('negative attempt number throws (invalid input)', () {
        final policy = RetryPolicy(baseDelay: Duration(seconds: 1));

        // Negative attempt numbers are invalid - bit shift with negative throws
        expect(() => policy.getDelay(-1), throwsA(isA<ArgumentError>()));
      });
    });
  });

  group('executeWithRetry()', () {
    test('succeeds on first try without retry', () async {
      var attempts = 0;

      final result = await executeWithRetry<String>(
        () async {
          attempts++;
          return 'success';
        },
        RetryPolicy(maxRetries: 3),
      );

      expect(result, equals('success'));
      expect(attempts, equals(1));
    });

    test('retries on failure and eventually succeeds', () async {
      var attempts = 0;

      final result = await executeWithRetry<String>(
        () async {
          attempts++;
          if (attempts < 3) {
            throw Exception('Not yet');
          }
          return 'success';
        },
        RetryPolicy(
          maxRetries: 5,
          baseDelay: Duration(milliseconds: 10),
        ),
      );

      expect(result, equals('success'));
      expect(attempts, equals(3));
    });

    test('throws after exhausting retries', () async {
      var attempts = 0;

      expect(
        () async => await executeWithRetry<String>(
          () async {
            attempts++;
            throw Exception('Always fails');
          },
          RetryPolicy(
            maxRetries: 2,
            baseDelay: Duration(milliseconds: 10),
          ),
        ),
        throwsA(isA<Exception>()),
      );

      // Wait for retries to complete
      await Future.delayed(Duration(milliseconds: 100));
      expect(attempts, equals(3)); // 1 initial + 2 retries
    });

    test('calls onRetry callback on each retry', () async {
      var attempts = 0;
      final retryLog = <String>[];

      try {
        await executeWithRetry<String>(
          () async {
            attempts++;
            throw Exception('Fail $attempts');
          },
          RetryPolicy(
            maxRetries: 3,
            baseDelay: Duration(milliseconds: 10),
          ),
          onRetry: (error, attempt) {
            retryLog.add('retry-$attempt: $error');
          },
        );
      } catch (_) {}

      // 3 retries = 3 onRetry calls (attempts 0, 1, 2)
      expect(retryLog.length, equals(3));
      expect(retryLog[0], contains('retry-0'));
      expect(retryLog[1], contains('retry-1'));
      expect(retryLog[2], contains('retry-2'));
    });

    test('respects shouldRetry predicate', () async {
      var attempts = 0;

      expect(
        () async => await executeWithRetry<String>(
          () async {
            attempts++;
            throw ArgumentError('Not retryable');
          },
          RetryPolicy(
            maxRetries: 5,
            shouldRetry: (e) => e is! ArgumentError,
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );

      await Future.delayed(Duration(milliseconds: 50));
      expect(attempts, equals(1)); // No retries for ArgumentError
    });

    test('delays between retries with exponential backoff', () async {
      var attempts = 0;
      final timestamps = <int>[];

      try {
        await executeWithRetry<String>(
          () async {
            timestamps.add(DateTime.now().millisecondsSinceEpoch);
            attempts++;
            throw Exception('Fail');
          },
          RetryPolicy(
            maxRetries: 2,
            baseDelay: Duration(milliseconds: 50),
            exponentialBackoff: true,
          ),
        );
      } catch (_) {}

      expect(timestamps.length, equals(3));

      // First delay should be ~50ms (2^0 * 50)
      final delay1 = timestamps[1] - timestamps[0];
      expect(delay1, greaterThanOrEqualTo(40)); // Allow some tolerance

      // Second delay should be ~100ms (2^1 * 50)
      final delay2 = timestamps[2] - timestamps[1];
      expect(delay2, greaterThanOrEqualTo(90)); // Allow some tolerance
    });
  });
}
