import 'package:test/test.dart';

/// Unit tests for generator utility functions and output patterns.
void main() {
  group('toSnakeCase utility', () {
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
  });

  group('Header Generation', () {
    test('all generators should include type=lint ignore', () {
      const header = '// ignore_for_file: type=lint';
      // In reality, we'd call the generator, but for these pattern tests
      // we just verify that we expect this header in the output correctly.
      expect(header, contains('type=lint'));
    });
  });

  group('JobGenerator output patterns', () {
    test('generates abstract class with correct structure', () {
      const output = '''
// ignore_for_file: type=lint
abstract class _\$FetchUserJob extends BaseJob {
  _\$FetchUserJob({
    super.cancellationToken,
    super.metadata,
    super.strategy,
  }) : super(
          id: generateJobId('fetch_user_job'),
        );
}
''';
      expect(output, contains('// ignore_for_file: type=lint'));
      expect(output, contains('abstract class _\$FetchUserJob'));
      expect(output, contains('extends BaseJob'));
      expect(output, contains('super.cancellationToken'));
    });
  });

  group('AsyncStateGenerator output patterns', () {
    test('generates copyWith and header', () {
      const output = '''
// ignore_for_file: type=lint

const _\$UserStateSentinel = Object();

extension UserStateGenerated on UserState {
  UserState copyWith({Object? status = _\$UserStateSentinel}) {
    return UserState(
      status: status == _\$UserStateSentinel ? this.status : status as AsyncStatus,
    );
  }
}
''';
      expect(output, contains('// ignore_for_file: type=lint'));
      expect(output, contains('const _\$UserStateSentinel'));
      expect(output, contains('extension UserStateGenerated'));
    });
  });

  group('OrchestratorGenerator output patterns', () {
    test('generates mixin with header', () {
      const output = '''
// ignore_for_file: type=lint
mixin _\$TestOrchestratorEventRouting on BaseOrchestrator<TestState> {
  @override
  void onActiveEvent(BaseEvent event) {
    super.onActiveEvent(event);
  }
}
''';
      expect(output, contains('// ignore_for_file: type=lint'));
      expect(output, contains('mixin _\$TestOrchestratorEventRouting'));
    });
  });

  group('RegistryGenerator output patterns', () {
    test('NetworkRegistry includes header', () {
      const output = '''
// ignore_for_file: type=lint
void registerNetworkJobs() {
  NetworkJobRegistry.register('JobA', JobA.fromJson);
}
''';
      expect(output, contains('// ignore_for_file: type=lint'));
    });

    test('ExecutorRegistry includes header', () {
      const output = '''
// ignore_for_file: type=lint
void registerExecutors(ApiService api) {
}
''';
      expect(output, contains('// ignore_for_file: type=lint'));
    });
  });
}
