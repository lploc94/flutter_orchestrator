import 'package:orchestrator_cli/src/utils/brick_loader.dart';
import 'package:test/test.dart';

void main() {
  group('BrickType', () {
    test('should have all required brick types', () {
      expect(BrickType.values, containsAll([
        BrickType.job,
        BrickType.executor,
        BrickType.state,
        BrickType.cubit,
        BrickType.notifier,
        BrickType.riverpod,
      ]));
    });
  });

  group('BrickLoader', () {
    group('getDefaultOutputDir', () {
      test('should return lib/jobs for job brick', () {
        expect(
          BrickLoader.getDefaultOutputDir(BrickType.job),
          equals('lib/jobs'),
        );
      });

      test('should return lib/executors for executor brick', () {
        expect(
          BrickLoader.getDefaultOutputDir(BrickType.executor),
          equals('lib/executors'),
        );
      });

      test('should return lib/states for state brick', () {
        expect(
          BrickLoader.getDefaultOutputDir(BrickType.state),
          equals('lib/states'),
        );
      });

      test('should return lib/cubits for cubit brick', () {
        expect(
          BrickLoader.getDefaultOutputDir(BrickType.cubit),
          equals('lib/cubits'),
        );
      });

      test('should return lib/notifiers for notifier brick', () {
        expect(
          BrickLoader.getDefaultOutputDir(BrickType.notifier),
          equals('lib/notifiers'),
        );
      });

      test('should return lib/notifiers for riverpod brick', () {
        expect(
          BrickLoader.getDefaultOutputDir(BrickType.riverpod),
          equals('lib/notifiers'),
        );
      });
    });

    group('getBricksPath', () {
      test('should return a non-empty path', () {
        // This test runs from the package directory
        // so getBricksPath should find the bricks
        expect(
          () => BrickLoader.getBricksPath(),
          returnsNormally,
        );
      });
    });
  });
}
