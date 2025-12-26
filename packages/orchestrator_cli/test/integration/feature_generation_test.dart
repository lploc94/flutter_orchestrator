import 'dart:io';

import 'package:orchestrator_cli/src/utils/brick_loader.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  group('Feature Generation Integration Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('orchestrator_feature_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('should generate complete feature with cubit', () async {
      final featureDir = path.join(tempDir.path, 'user');
      
      // Generate job
      await BrickLoader.generate(
        type: BrickType.job,
        vars: {'name': 'User'},
        outputDir: path.join(featureDir, 'jobs'),
      );

      // Generate executor
      await BrickLoader.generate(
        type: BrickType.executor,
        vars: {'name': 'User'},
        outputDir: path.join(featureDir, 'executors'),
      );

      // Generate cubit
      await BrickLoader.generate(
        type: BrickType.cubit,
        vars: {'name': 'User'},
        outputDir: path.join(featureDir, 'cubit'),
      );

      // Verify all files exist
      expect(
        await File(path.join(featureDir, 'jobs', 'user_job.dart')).exists(),
        isTrue,
      );
      expect(
        await File(path.join(featureDir, 'executors', 'user_executor.dart')).exists(),
        isTrue,
      );
      expect(
        await File(path.join(featureDir, 'cubit', 'user_cubit.dart')).exists(),
        isTrue,
      );
      expect(
        await File(path.join(featureDir, 'cubit', 'user_state.dart')).exists(),
        isTrue,
      );
    });

    test('should generate complete feature with riverpod', () async {
      final featureDir = path.join(tempDir.path, 'product');
      
      // Generate job
      await BrickLoader.generate(
        type: BrickType.job,
        vars: {'name': 'Product'},
        outputDir: path.join(featureDir, 'jobs'),
      );

      // Generate executor
      await BrickLoader.generate(
        type: BrickType.executor,
        vars: {'name': 'Product'},
        outputDir: path.join(featureDir, 'executors'),
      );

      // Generate riverpod notifier
      await BrickLoader.generate(
        type: BrickType.riverpod,
        vars: {'name': 'Product'},
        outputDir: path.join(featureDir, 'notifier'),
      );

      // Verify files exist
      expect(
        await File(path.join(featureDir, 'jobs', 'product_job.dart')).exists(),
        isTrue,
      );
      expect(
        await File(path.join(featureDir, 'executors', 'product_executor.dart')).exists(),
        isTrue,
      );
      expect(
        await File(path.join(featureDir, 'notifier', 'product_notifier.dart')).exists(),
        isTrue,
      );
      expect(
        await File(path.join(featureDir, 'notifier', 'product_state.dart')).exists(),
        isTrue,
      );

      // Verify riverpod-specific content
      final notifierContent = await File(
        path.join(featureDir, 'notifier', 'product_notifier.dart'),
      ).readAsString();
      expect(notifierContent, contains('buildState()'));
      expect(notifierContent, contains('productProvider'));
      expect(notifierContent, contains('NotifierProvider'));
    });

    test('should generate feature without job', () async {
      final featureDir = path.join(tempDir.path, 'auth');
      
      // Only generate executor and cubit (skip job)
      await BrickLoader.generate(
        type: BrickType.executor,
        vars: {'name': 'Auth'},
        outputDir: path.join(featureDir, 'executors'),
      );

      await BrickLoader.generate(
        type: BrickType.cubit,
        vars: {'name': 'Auth'},
        outputDir: path.join(featureDir, 'cubit'),
      );

      // Verify only executor and cubit exist
      expect(
        await Directory(path.join(featureDir, 'jobs')).exists(),
        isFalse,
      );
      expect(
        await File(path.join(featureDir, 'executors', 'auth_executor.dart')).exists(),
        isTrue,
      );
      expect(
        await File(path.join(featureDir, 'cubit', 'auth_cubit.dart')).exists(),
        isTrue,
      );
    });

    test('should generate feature with provider', () async {
      final featureDir = path.join(tempDir.path, 'cart');
      
      await BrickLoader.generate(
        type: BrickType.notifier,
        vars: {'name': 'Cart'},
        outputDir: path.join(featureDir, 'notifier'),
      );

      // Verify provider-specific content
      final notifierContent = await File(
        path.join(featureDir, 'notifier', 'cart_notifier.dart'),
      ).readAsString();
      expect(notifierContent, contains('OrchestratorNotifier<CartState>'));
      expect(notifierContent, contains('orchestrator_provider'));
      expect(notifierContent, contains('ChangeNotifierProvider'));
    });
  });
}
