import 'package:orchestrator_cli/src/commands/template_command.dart';
import 'package:test/test.dart';

void main() {
  group('TemplateCommand', () {
    late TemplateCommand command;

    setUp(() {
      command = TemplateCommand();
    });

    test('should have correct name', () {
      expect(command.name, equals('template'));
    });

    test('should have correct description', () {
      expect(
        command.description,
        contains('Manage custom templates'),
      );
    });

    test('should have init subcommand', () {
      final subcommands = command.subcommands;
      expect(subcommands.containsKey('init'), isTrue);
    });

    test('should have list subcommand', () {
      final subcommands = command.subcommands;
      expect(subcommands.containsKey('list'), isTrue);
    });
  });

  group('TemplateInitCommand', () {
    late TemplateInitCommand command;

    setUp(() {
      command = TemplateInitCommand();
    });

    test('should have correct name', () {
      expect(command.name, equals('init'));
    });

    test('should have correct description', () {
      expect(
        command.description,
        contains('Initialize custom templates'),
      );
    });

    test('should have force flag', () {
      final option = command.argParser.options['force'];
      expect(option, isNotNull);
      expect(option!.abbr, equals('f'));
      expect(option.negatable, isFalse);
    });

    test('should have template option', () {
      final option = command.argParser.options['template'];
      expect(option, isNotNull);
      expect(option!.abbr, equals('t'));
      expect(option.defaultsTo, equals('all'));
    });

    test('template option should allow specific templates', () {
      final option = command.argParser.options['template'];
      expect(option!.allowed, containsAll([
        'job',
        'executor',
        'state',
        'cubit',
        'notifier',
        'riverpod',
        'all',
      ]));
    });
  });

  group('TemplateListCommand', () {
    late TemplateListCommand command;

    setUp(() {
      command = TemplateListCommand();
    });

    test('should have correct name', () {
      expect(command.name, equals('list'));
    });

    test('should have correct description', () {
      expect(
        command.description,
        contains('List custom templates'),
      );
    });
  });
}
