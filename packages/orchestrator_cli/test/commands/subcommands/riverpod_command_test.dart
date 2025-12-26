import 'package:orchestrator_cli/src/commands/subcommands/riverpod_command.dart';
import 'package:test/test.dart';

void main() {
  group('RiverpodCommand', () {
    late RiverpodCommand command;

    setUp(() {
      command = RiverpodCommand();
    });

    test('should have correct name', () {
      expect(command.name, equals('riverpod'));
    });

    test('should have correct description', () {
      expect(
        command.description,
        equals('Create an OrchestratorNotifier with State (Riverpod integration)'),
      );
    });

    test('should have output option', () {
      final options = command.argParser.options;
      expect(options.containsKey('output'), isTrue);
    });

    test('output option should have default value', () {
      final outputOption = command.argParser.options['output'];
      expect(outputOption?.defaultsTo, equals('lib/notifiers'));
    });

    test('output option should have abbr o', () {
      final outputOption = command.argParser.options['output'];
      expect(outputOption?.abbr, equals('o'));
    });
  });
}
