import 'package:orchestrator_cli/src/utils/logger.dart';
import 'package:test/test.dart';

void main() {
  group('CliLogger', () {
    late CliLogger logger;

    setUp(() {
      logger = CliLogger();
    });

    test('should create logger instance', () {
      expect(logger, isA<CliLogger>());
    });

    test('should have info method', () {
      expect(() => logger.info('test message'), returnsNormally);
    });

    test('should have success method', () {
      expect(() => logger.success('test message'), returnsNormally);
    });

    test('should have warn method', () {
      expect(() => logger.warn('test message'), returnsNormally);
    });

    test('should have error method', () {
      expect(() => logger.error('test message'), returnsNormally);
    });

    test('should have detail method', () {
      expect(() => logger.detail('test message'), returnsNormally);
    });

    test('should have alert method', () {
      expect(() => logger.alert('test message'), returnsNormally);
    });
  });
}
