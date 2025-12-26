import 'package:orchestrator_cli/src/commands/list_command.dart';
import 'package:test/test.dart';

void main() {
  group('ListCommand', () {
    late ListCommand command;

    setUp(() {
      command = ListCommand();
    });

    test('should have correct name', () {
      expect(command.name, equals('list'));
    });

    test('should have correct description', () {
      expect(
        command.description,
        contains('List available templates'),
      );
    });

    test('should have ls alias', () {
      expect(command.aliases, contains('ls'));
    });

    test('should have verbose flag', () {
      final option = command.argParser.options['verbose'];
      expect(option, isNotNull);
      expect(option!.abbr, equals('v'));
      expect(option.negatable, isFalse);
    });

    test('should have custom flag', () {
      final option = command.argParser.options['custom'];
      expect(option, isNotNull);
      expect(option!.abbr, equals('c'));
      expect(option.negatable, isFalse);
    });
  });
}
