import 'package:orchestrator_cli/src/commands/subcommands/feature_command.dart';
import 'package:test/test.dart';

void main() {
  group('FeatureCommand', () {
    late FeatureCommand command;

    setUp(() {
      command = FeatureCommand();
    });

    test('should have correct name', () {
      expect(command.name, equals('feature'));
    });

    test('should have correct description', () {
      expect(
        command.description,
        equals('Create a full feature scaffold (job, executor, state management)'),
      );
    });

    test('should have output option', () {
      final options = command.argParser.options;
      expect(options.containsKey('output'), isTrue);
    });

    test('should have state-management option', () {
      final options = command.argParser.options;
      expect(options.containsKey('state-management'), isTrue);
    });

    test('state-management option should allow cubit, provider, riverpod', () {
      final option = command.argParser.options['state-management'];
      expect(option?.allowed, containsAll(['cubit', 'provider', 'riverpod']));
    });

    test('should have no-job flag', () {
      final options = command.argParser.options;
      expect(options.containsKey('no-job'), isTrue);
    });

    test('should have no-executor flag', () {
      final options = command.argParser.options;
      expect(options.containsKey('no-executor'), isTrue);
    });

    test('should have interactive flag', () {
      final options = command.argParser.options;
      expect(options.containsKey('interactive'), isTrue);
    });

    test('interactive flag should have abbr i', () {
      final option = command.argParser.options['interactive'];
      expect(option?.abbr, equals('i'));
    });
  });

  group('StateManagement', () {
    test('should have cubit value', () {
      expect(StateManagement.values, contains(StateManagement.cubit));
    });

    test('should have provider value', () {
      expect(StateManagement.values, contains(StateManagement.provider));
    });

    test('should have riverpod value', () {
      expect(StateManagement.values, contains(StateManagement.riverpod));
    });
  });
}
