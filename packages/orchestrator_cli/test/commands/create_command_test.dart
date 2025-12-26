import 'package:args/command_runner.dart';
import 'package:orchestrator_cli/src/commands/create_command.dart';
import 'package:test/test.dart';

void main() {
  group('CreateCommand', () {
    late CreateCommand command;
    late CommandRunner<int> runner;

    setUp(() {
      command = CreateCommand();
      runner = CommandRunner<int>('orchestrator', 'Test runner');
      runner.addCommand(command);
    });

    test('should have correct name', () {
      expect(command.name, equals('create'));
    });

    test('should have correct description', () {
      expect(
        command.description,
        equals('Create Orchestrator components (job, executor, cubit, feature, etc.)'),
      );
    });

    test('should have all subcommands', () {
      final subcommandNames = command.subcommands.keys.toList();
      
      expect(subcommandNames, containsAll([
        'job',
        'executor',
        'state',
        'cubit',
        'notifier',
        'riverpod',
        'feature',
      ]));
    });

    test('job subcommand should have correct name', () {
      final jobCommand = command.subcommands['job'];
      expect(jobCommand?.name, equals('job'));
    });

    test('executor subcommand should have correct name', () {
      final executorCommand = command.subcommands['executor'];
      expect(executorCommand?.name, equals('executor'));
    });

    test('state subcommand should have correct name', () {
      final stateCommand = command.subcommands['state'];
      expect(stateCommand?.name, equals('state'));
    });

    test('cubit subcommand should have correct name', () {
      final cubitCommand = command.subcommands['cubit'];
      expect(cubitCommand?.name, equals('cubit'));
    });

    test('notifier subcommand should have correct name', () {
      final notifierCommand = command.subcommands['notifier'];
      expect(notifierCommand?.name, equals('notifier'));
    });

    test('riverpod subcommand should have correct name', () {
      final riverpodCommand = command.subcommands['riverpod'];
      expect(riverpodCommand?.name, equals('riverpod'));
    });
  });
}
