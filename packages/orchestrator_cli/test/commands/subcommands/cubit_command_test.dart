import 'package:orchestrator_cli/src/commands/subcommands/cubit_command.dart';
import 'package:test/test.dart';

void main() {
  group('CubitCommand', () {
    late CubitCommand command;

    setUp(() {
      command = CubitCommand();
    });

    test('should have correct name', () {
      expect(command.name, equals('cubit'));
    });

    test('should have correct description', () {
      expect(
        command.description,
        equals('Create an OrchestratorCubit with State (Bloc integration)'),
      );
    });

    test('should have output option', () {
      final options = command.argParser.options;
      expect(options.containsKey('output'), isTrue);
    });

    test('output option should have default value', () {
      final outputOption = command.argParser.options['output'];
      expect(outputOption?.defaultsTo, equals('lib/cubits'));
    });

    test('output option should have abbr o', () {
      final outputOption = command.argParser.options['output'];
      expect(outputOption?.abbr, equals('o'));
    });
  });
}
