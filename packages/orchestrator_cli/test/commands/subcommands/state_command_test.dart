import 'package:orchestrator_cli/src/commands/subcommands/state_command.dart';
import 'package:test/test.dart';

void main() {
  group('StateCommand', () {
    late StateCommand command;

    setUp(() {
      command = StateCommand();
    });

    test('should have correct name', () {
      expect(command.name, equals('state'));
    });

    test('should have correct description', () {
      expect(
        command.description,
        equals('Create an immutable State class with copyWith'),
      );
    });

    test('should have output option', () {
      final options = command.argParser.options;
      expect(options.containsKey('output'), isTrue);
    });

    test('output option should have default value', () {
      final outputOption = command.argParser.options['output'];
      expect(outputOption?.defaultsTo, equals('lib/states'));
    });

    test('output option should have abbr o', () {
      final outputOption = command.argParser.options['output'];
      expect(outputOption?.abbr, equals('o'));
    });
  });
}
