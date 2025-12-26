import 'package:orchestrator_cli/src/commands/init_command.dart';
import 'package:test/test.dart';

void main() {
  group('InitCommand', () {
    late InitCommand command;

    setUp(() {
      command = InitCommand();
    });

    test('should have correct name', () {
      expect(command.name, equals('init'));
    });

    test('should have correct description', () {
      expect(
        command.description,
        equals('Initialize Orchestrator project structure'),
      );
    });

    test('should have state-management option', () {
      final options = command.argParser.options;
      expect(options.containsKey('state-management'), isTrue);
    });

    test('state-management option should allow cubit, provider, riverpod', () {
      final option = command.argParser.options['state-management'];
      expect(option?.allowed, containsAll(['cubit', 'provider', 'riverpod']));
    });

    test('state-management option should default to cubit', () {
      final option = command.argParser.options['state-management'];
      expect(option?.defaultsTo, equals('cubit'));
    });

    test('should have force flag', () {
      final options = command.argParser.options;
      expect(options.containsKey('force'), isTrue);
    });

    test('force flag should have abbr f', () {
      final option = command.argParser.options['force'];
      expect(option?.abbr, equals('f'));
    });
  });
}
