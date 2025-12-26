import 'package:orchestrator_cli/src/commands/doctor_command.dart';
import 'package:test/test.dart';

void main() {
  group('DoctorCommand', () {
    late DoctorCommand command;

    setUp(() {
      command = DoctorCommand();
    });

    test('should have correct name', () {
      expect(command.name, equals('doctor'));
    });

    test('should have correct description', () {
      expect(
        command.description,
        contains('Check project setup'),
      );
    });

    test('should have fix flag', () {
      final option = command.argParser.options['fix'];
      expect(option, isNotNull);
      expect(option!.abbr, equals('f'));
      expect(option.negatable, isFalse);
    });

    test('should have verbose flag', () {
      final option = command.argParser.options['verbose'];
      expect(option, isNotNull);
      expect(option!.abbr, equals('v'));
      expect(option.negatable, isFalse);
    });
  });

  group('DiagnosticResult', () {
    test('should create passed result', () {
      const result = DiagnosticResult(
        name: 'Test check',
        passed: true,
        message: 'All good',
      );

      expect(result.name, equals('Test check'));
      expect(result.passed, isTrue);
      expect(result.message, equals('All good'));
      expect(result.fix, isNull);
    });

    test('should create failed result with fix', () {
      const result = DiagnosticResult(
        name: 'Test check',
        passed: false,
        message: 'Something is wrong',
        fix: 'Run this command to fix',
      );

      expect(result.name, equals('Test check'));
      expect(result.passed, isFalse);
      expect(result.message, equals('Something is wrong'));
      expect(result.fix, equals('Run this command to fix'));
    });
  });
}
