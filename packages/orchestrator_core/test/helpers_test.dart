import 'package:test/test.dart';
import 'package:orchestrator_core/orchestrator_core.dart';

void main() {
  group('JobBuilder', () {
    test('creates configured job with timeout', () {
      final job = TestJob('test-1');
      final configured = JobBuilder(job)
          .withTimeout(const Duration(seconds: 30))
          .build();

      expect(configured.id, equals('test-1'));
      expect(configured.timeout, equals(const Duration(seconds: 30)));
      expect(configured.original, equals(job));
    });

    test('creates configured job with retry policy', () {
      final job = TestJob('test-2');
      final configured = JobBuilder(job)
          .withRetry(maxRetries: 5, baseDelay: const Duration(seconds: 2))
          .build();

      expect(configured.retryPolicy, isNotNull);
      expect(configured.retryPolicy!.maxRetries, equals(5));
    });

    test('creates configured job with cache policy', () {
      final job = TestJob('test-3');
      final configured = JobBuilder(job)
          .withCache(key: 'user_123', ttl: const Duration(minutes: 5))
          .build();

      expect(configured.strategy, isNotNull);
      expect(configured.strategy!.cachePolicy, isNotNull);
      expect(configured.strategy!.cachePolicy!.key, equals('user_123'));
    });

    test('supports fluent chaining', () {
      final job = TestJob('test-4');
      final configured = JobBuilder(job)
          .withTimeout(const Duration(seconds: 30))
          .withRetry(maxRetries: 3)
          .withCache(key: 'data_key')
          .withPlaceholder('Loading...')
          .withMetadata({'source': 'test'})
          .build();

      expect(configured.timeout, isNotNull);
      expect(configured.retryPolicy, isNotNull);
      expect(configured.strategy?.cachePolicy, isNotNull);
      expect(configured.strategy?.placeholder, equals('Loading...'));
      expect(configured.metadata?['source'], equals('test'));
    });
  });

  group('JobResult', () {
    test('success result provides data', () {
      const result = JobResult<int>.success(42);

      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.dataOrNull, equals(42));
      expect(result.errorOrNull, isNull);
    });

    test('failure result provides error', () {
      final result = JobResult<int>.failure(Exception('test error'));

      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
      expect(result.dataOrNull, isNull);
      expect(result.errorOrNull, isA<Exception>());
    });

    test('when pattern matching works', () {
      const result = JobResult<int>.success(42);

      final value = result.when(
        success: (data) => 'Got: $data',
        failure: (error, _) => 'Error: $error',
      );

      expect(value, equals('Got: 42'));
    });

    test('cancelled result works', () {
      const result = JobResult<int>.cancelled('User cancelled');

      final value = result.when(
        success: (_) => 'success',
        failure: (e, _) => 'failure: $e',
        cancelled: (reason) => 'cancelled: $reason',
      );

      expect(value, equals('cancelled: User cancelled'));
    });
  });

  group('AsyncState', () {
    test('initial state', () {
      const state = AsyncState<String>();

      expect(state.status, equals(AsyncStatus.initial));
      expect(state.isLoading, isFalse);
      expect(state.hasData, isFalse);
    });

    test('toLoading preserves existing data', () {
      const state = AsyncState<String>(
        status: AsyncStatus.success,
        data: 'existing',
      );

      final loading = state.toLoading();

      expect(loading.status, equals(AsyncStatus.loading));
      expect(loading.data, equals('existing'));
    });

    test('toSuccess sets data', () {
      const state = AsyncState<String>();
      final success = state.toSuccess('new data');

      expect(success.status, equals(AsyncStatus.success));
      expect(success.data, equals('new data'));
    });

    test('toFailure preserves existing data', () {
      const state = AsyncState<String>(
        status: AsyncStatus.success,
        data: 'existing',
      );

      final failure = state.toFailure(Exception('error'));

      expect(failure.status, equals(AsyncStatus.failure));
      expect(failure.data, equals('existing'));
      expect(failure.error, isA<Exception>());
    });

    test('when pattern matching', () {
      const state = AsyncState<int>(
        status: AsyncStatus.success,
        data: 42,
      );

      final result = state.when(
        initial: () => 'initial',
        loading: () => 'loading',
        success: (data) => 'success: $data',
        failure: (e) => 'failure: $e',
      );

      expect(result, equals('success: 42'));
    });
  });

  group('Event Extensions', () {
    test('dataOrNull returns correct type', () {
      final event = JobSuccessEvent<int>('job-1', 42);

      expect(event.dataOrNull<int>(), equals(42));
      expect(event.dataOrNull<String>(), isNull);
    });

    test('dataOr provides default', () {
      final event = JobSuccessEvent<int>('job-1', 42);

      expect(event.dataOr<int>(0), equals(42));
      expect(event.dataOr<String>('default'), equals('default'));
    });

    test('failure errorMessage cleans up Exception prefix', () {
      final event = JobFailureEvent('job-1', Exception('Something went wrong'));

      expect(event.errorMessage, equals('Something went wrong'));
    });
  });
}

class TestJob extends BaseJob {
  final String name;
  TestJob(this.name) : super(id: name);
}

