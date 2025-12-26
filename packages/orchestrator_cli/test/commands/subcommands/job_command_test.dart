import 'package:orchestrator_cli/src/commands/subcommands/job_command.dart';
import 'package:test/test.dart';

void main() {
  group('JobCommand', () {
    late JobCommand command;

    setUp(() {
      command = JobCommand();
    });

    test('should have correct name', () {
      expect(command.name, equals('job'));
    });

    test('should have correct description', () {
      expect(
        command.description,
        equals('Create an Orchestrator Job class'),
      );
    });

    test('should have output option', () {
      final options = command.argParser.options;
      expect(options.containsKey('output'), isTrue);
    });

    test('output option should have default value', () {
      final outputOption = command.argParser.options['output'];
      expect(outputOption?.defaultsTo, equals('lib/jobs'));
    });

    test('output option should have abbr o', () {
      final outputOption = command.argParser.options['output'];
      expect(outputOption?.abbr, equals('o'));
    });
  });
}
