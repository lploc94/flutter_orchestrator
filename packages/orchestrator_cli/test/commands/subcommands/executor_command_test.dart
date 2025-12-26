import 'package:orchestrator_cli/src/commands/subcommands/executor_command.dart';
import 'package:test/test.dart';

void main() {
  group('ExecutorCommand', () {
    late ExecutorCommand command;

    setUp(() {
      command = ExecutorCommand();
    });

    test('should have correct name', () {
      expect(command.name, equals('executor'));
    });

    test('should have correct description', () {
      expect(
        command.description,
        equals('Create an Orchestrator Executor class'),
      );
    });

    test('should have output option', () {
      final options = command.argParser.options;
      expect(options.containsKey('output'), isTrue);
    });

    test('output option should have default value', () {
      final outputOption = command.argParser.options['output'];
      expect(outputOption?.defaultsTo, equals('lib/executors'));
    });

    test('output option should have abbr o', () {
      final outputOption = command.argParser.options['output'];
      expect(outputOption?.abbr, equals('o'));
    });
  });
}
