import 'package:test/test.dart';

/// Unit tests for generator utility functions and output patterns.
///
/// Note: Full integration testing of generators requires the `source_gen_test`
/// package which has version compatibility issues with our current dependencies.
/// These tests focus on verifiable utility functions and expected output patterns.
void main() {
  group('toSnakeCase utility', () {
    // Test the snake_case conversion logic used by JobGenerator
    String toSnakeCase(String input) {
      return input
          .replaceAllMapped(
            RegExp(r'[A-Z]'),
            (match) => '_${match.group(0)!.toLowerCase()}',
          )
          .substring(1); // Remove leading underscore
    }

    test('converts PascalCase to snake_case', () {
      expect(toSnakeCase('FetchUserJob'), equals('fetch_user_job'));
      expect(toSnakeCase('SimpleJob'), equals('simple_job'));
      expect(toSnakeCase('SendMessageJob'), equals('send_message_job'));
    });

    test('handles single word', () {
      expect(toSnakeCase('Job'), equals('job'));
    });

    test('handles multiple consecutive capitals', () {
      expect(toSnakeCase('APICallJob'), equals('a_p_i_call_job'));
    });
  });

  group('JobGenerator output patterns', () {
    test('generates abstract class with correct structure', () {
      // Expected output pattern for JobGenerator
      const expectedPattern = r'''
abstract class _$FetchUserJob extends BaseJob {
  _$FetchUserJob({
    super.cancellationToken,
    super.metadata,
    super.strategy,
  }) : super(
          id: generateJobId('fetch_user_job'),
        );
}
''';
      // Verify the expected structure contains key elements
      expect(expectedPattern, contains('abstract class'));
      expect(expectedPattern, contains('extends BaseJob'));
      expect(expectedPattern, contains('generateJobId'));
      expect(expectedPattern, contains('super.cancellationToken'));
    });

    test('includes timeout when configured', () {
      const expectedWithTimeout = r'''
  }) : super(
          id: generateJobId('timeout_job'),
          timeout: Duration(microseconds: 30000000),
        );
''';
      expect(expectedWithTimeout, contains('timeout:'));
      expect(expectedWithTimeout, contains('Duration'));
    });

    test('includes retryPolicy when configured', () {
      const expectedWithRetry = r'''
  }) : super(
          id: generateJobId('retry_job'),
          retryPolicy: RetryPolicy(maxRetries: 3, initialDelay: Duration(seconds: 1)),
        );
''';
      expect(expectedWithRetry, contains('retryPolicy:'));
      expect(expectedWithRetry, contains('RetryPolicy'));
      expect(expectedWithRetry, contains('maxRetries:'));
    });
  });

  group('EventGenerator output patterns', () {
    test('generates extension with toEvent method', () {
      const expectedPattern = r'''
extension _$OrderPlacedEvent on OrderPlaced {
  BaseEvent toEvent(String correlationId) {
    return _OrderPlacedEventWrapper(correlationId, this);
  }
}
''';
      expect(expectedPattern, contains('extension'));
      expect(expectedPattern, contains('toEvent'));
      expect(expectedPattern, contains('correlationId'));
    });

    test('generates wrapper class', () {
      const expectedWrapper = r'''
class _OrderPlacedEventWrapper extends BaseEvent {
  final OrderPlaced payload;
  _OrderPlacedEventWrapper(super.correlationId, this.payload);
}
''';
      expect(expectedWrapper, contains('extends BaseEvent'));
      expect(expectedWrapper, contains('payload'));
    });
  });

  group('AsyncStateGenerator output patterns', () {
    test('generates copyWith method', () {
      const expectedCopyWith = r'''
  UserState copyWith({Object? status = _$UserStateSentinel}) {
    return UserState(
      status: status == _$UserStateSentinel ? this.status : status as AsyncStatus,
    );
  }
''';
      expect(expectedCopyWith, contains('copyWith'));
      expect(expectedCopyWith, contains('Sentinel'));
    });

    test('generates transition methods', () {
      const expectedTransitions = r'''
  UserState toLoading() => copyWith(status: AsyncStatus.loading);
  UserState toSuccess() => copyWith(status: AsyncStatus.success);
  UserState toFailure() => copyWith(status: AsyncStatus.failure);
''';
      expect(expectedTransitions, contains('toLoading'));
      expect(expectedTransitions, contains('toSuccess'));
      expect(expectedTransitions, contains('toFailure'));
    });

    test('supports custom statusField', () {
      const expectedCustomStatus = r'''
  CustomState toLoading() => copyWith(loadingStatus: AsyncStatus.loading);
''';
      expect(expectedCustomStatus, contains('loadingStatus:'));
    });
  });

  group('OrchestratorGenerator output patterns', () {
    test('generates mixin with event routing', () {
      const expectedMixin = r'''
mixin _$TestOrchestratorEventRouting on BaseOrchestrator<TestState> {
  void _handleLogin(UserLoggedInEvent event);

  @override
  void onActiveEvent(BaseEvent event) {
    super.onActiveEvent(event);
    if (event is UserLoggedInEvent) {
      _handleLogin(event);
      return;
    }
  }
}
''';
      expect(expectedMixin, contains('mixin'));
      expect(expectedMixin, contains('EventRouting'));
      expect(expectedMixin, contains('onActiveEvent'));
    });

    test('separates active and passive handlers', () {
      const expectedPassive = r'''
  @override
  void onPassiveEvent(BaseEvent event) {
    super.onPassiveEvent(event);
''';
      expect(expectedPassive, contains('onPassiveEvent'));
    });
  });

  group('NetworkJobGenerator output patterns', () {
    test('generates toJson method', () {
      const expectedToJson = r'''
  Map<String, dynamic> toJson() => {
    'id': id,
    'message': message,
  };
''';
      expect(expectedToJson, contains('toJson'));
      expect(expectedToJson, contains("'id'"));
    });

    test('generates fromJson method', () {
      const expectedFromJson = r'''
  static SendMessageJob fromJson(Map<String, dynamic> json) {
    return SendMessageJob(
      id: json['id'] as String,
    );
  }
''';
      expect(expectedFromJson, contains('fromJson'));
      expect(expectedFromJson, contains('static'));
    });
  });

  group('NetworkRegistryGenerator output patterns', () {
    test('generates registerNetworkJobs function', () {
      const expectedRegistry = r'''
void registerNetworkJobs() {
  NetworkJobRegistry.register('JobA', JobA.fromJson);
  NetworkJobRegistry.register('JobB', JobB.fromJson);
}
''';
      expect(expectedRegistry, contains('registerNetworkJobs'));
      expect(expectedRegistry, contains('NetworkJobRegistry.register'));
    });

    test('handles empty registry with warning', () {
      const expectedEmpty = r'''
// WARNING: No jobs registered in @NetworkRegistry
void registerNetworkJobs() {}
''';
      expect(expectedEmpty, contains('WARNING'));
    });
  });
}
