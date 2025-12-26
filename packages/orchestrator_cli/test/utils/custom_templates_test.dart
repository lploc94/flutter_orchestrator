import 'dart:io';

import 'package:orchestrator_cli/src/utils/brick_loader.dart';
import 'package:test/test.dart';

void main() {
  group('BrickLoader custom templates', () {
    final customTemplatesPath = '.orchestrator/templates';

    setUp(() async {
      // Clean up any existing custom templates
      final customDir = Directory(customTemplatesPath);
      if (customDir.existsSync()) {
        await customDir.delete(recursive: true);
      }
    });

    tearDown(() async {
      // Clean up after tests
      final customDir = Directory(customTemplatesPath);
      if (customDir.existsSync()) {
        await customDir.delete(recursive: true);
      }
    });

    test('getCustomTemplatesPath should return null when no custom templates exist', () {
      final path = BrickLoader.getCustomTemplatesPath();
      expect(path, isNull);
    });

    test('getCustomTemplatesPath should return path when custom templates exist', () async {
      // Create custom templates directory
      final customDir = Directory(customTemplatesPath);
      await customDir.create(recursive: true);

      final path = BrickLoader.getCustomTemplatesPath();
      expect(path, isNotNull);
      expect(path, endsWith('.orchestrator/templates'));
    });

    test('hasCustomTemplate should return false when no custom template exists', () {
      final hasCustom = BrickLoader.hasCustomTemplate(BrickType.job);
      expect(hasCustom, isFalse);
    });

    test('hasCustomTemplate should return true when custom template exists', () async {
      // Create custom template with brick.yaml
      final templateDir = Directory('$customTemplatesPath/job');
      await templateDir.create(recursive: true);
      await File('$customTemplatesPath/job/brick.yaml').writeAsString('name: custom_job');

      final hasCustom = BrickLoader.hasCustomTemplate(BrickType.job);
      expect(hasCustom, isTrue);
    });

    test('hasCustomTemplate should return false when directory exists but no brick.yaml', () async {
      // Create custom template directory without brick.yaml
      final templateDir = Directory('$customTemplatesPath/job');
      await templateDir.create(recursive: true);

      final hasCustom = BrickLoader.hasCustomTemplate(BrickType.job);
      expect(hasCustom, isFalse);
    });
  });

  group('BrickLoader getDefaultOutputDir', () {
    test('should return correct path for job', () {
      expect(BrickLoader.getDefaultOutputDir(BrickType.job), equals('lib/jobs'));
    });

    test('should return correct path for executor', () {
      expect(BrickLoader.getDefaultOutputDir(BrickType.executor), equals('lib/executors'));
    });

    test('should return correct path for state', () {
      expect(BrickLoader.getDefaultOutputDir(BrickType.state), equals('lib/states'));
    });

    test('should return correct path for cubit', () {
      expect(BrickLoader.getDefaultOutputDir(BrickType.cubit), equals('lib/cubits'));
    });

    test('should return correct path for notifier', () {
      expect(BrickLoader.getDefaultOutputDir(BrickType.notifier), equals('lib/notifiers'));
    });

    test('should return correct path for riverpod', () {
      expect(BrickLoader.getDefaultOutputDir(BrickType.riverpod), equals('lib/notifiers'));
    });
  });
}
