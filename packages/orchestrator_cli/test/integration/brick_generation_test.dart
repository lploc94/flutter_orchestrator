import 'dart:io';

import 'package:orchestrator_cli/src/utils/brick_loader.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  group('BrickLoader Integration Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('orchestrator_cli_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('should generate job file', () async {
      final outputDir = tempDir.path;
      
      final files = await BrickLoader.generate(
        type: BrickType.job,
        vars: {'name': 'FetchUser'},
        outputDir: outputDir,
      );

      expect(files.length, equals(1));
      
      final generatedFile = File(path.join(outputDir, 'fetch_user_job.dart'));
      expect(await generatedFile.exists(), isTrue);
      
      final content = await generatedFile.readAsString();
      expect(content, contains('class FetchUserJob'));
      expect(content, contains('extends BaseJob'));
      expect(content, contains("generateJobId('fetch_user')"));
    });

    test('should generate executor file', () async {
      final outputDir = tempDir.path;
      
      final files = await BrickLoader.generate(
        type: BrickType.executor,
        vars: {'name': 'FetchUser'},
        outputDir: outputDir,
      );

      expect(files.length, equals(1));
      
      final generatedFile = File(path.join(outputDir, 'fetch_user_executor.dart'));
      expect(await generatedFile.exists(), isTrue);
      
      final content = await generatedFile.readAsString();
      expect(content, contains('class FetchUserExecutor'));
      expect(content, contains('extends BaseExecutor<FetchUserJob>'));
      expect(content, contains('Future<dynamic> process(FetchUserJob job)'));
    });

    test('should generate state file', () async {
      final outputDir = tempDir.path;
      
      final files = await BrickLoader.generate(
        type: BrickType.state,
        vars: {'name': 'User'},
        outputDir: outputDir,
      );

      expect(files.length, equals(1));
      
      final generatedFile = File(path.join(outputDir, 'user_state.dart'));
      expect(await generatedFile.exists(), isTrue);
      
      final content = await generatedFile.readAsString();
      expect(content, contains('class UserState'));
      expect(content, contains('final bool isLoading'));
      expect(content, contains('final String? error'));
      expect(content, contains('UserState copyWith('));
    });

    test('should generate cubit files', () async {
      final outputDir = tempDir.path;
      
      final files = await BrickLoader.generate(
        type: BrickType.cubit,
        vars: {'name': 'User'},
        outputDir: outputDir,
      );

      expect(files.length, equals(2));
      
      final cubitFile = File(path.join(outputDir, 'user_cubit.dart'));
      expect(await cubitFile.exists(), isTrue);
      
      final cubitContent = await cubitFile.readAsString();
      expect(cubitContent, contains('class UserCubit'));
      expect(cubitContent, contains('extends OrchestratorCubit<UserState>'));
      expect(cubitContent, contains('onActiveSuccess'));
      expect(cubitContent, contains('onActiveFailure'));
      
      final stateFile = File(path.join(outputDir, 'user_state.dart'));
      expect(await stateFile.exists(), isTrue);
    });

    test('should generate notifier files', () async {
      final outputDir = tempDir.path;
      
      final files = await BrickLoader.generate(
        type: BrickType.notifier,
        vars: {'name': 'User'},
        outputDir: outputDir,
      );

      expect(files.length, equals(2));
      
      final notifierFile = File(path.join(outputDir, 'user_notifier.dart'));
      expect(await notifierFile.exists(), isTrue);
      
      final notifierContent = await notifierFile.readAsString();
      expect(notifierContent, contains('class UserNotifier'));
      expect(notifierContent, contains('extends OrchestratorNotifier<UserState>'));
      expect(notifierContent, contains('orchestrator_provider'));
      
      final stateFile = File(path.join(outputDir, 'user_state.dart'));
      expect(await stateFile.exists(), isTrue);
    });

    test('should generate riverpod files', () async {
      final outputDir = tempDir.path;
      
      final files = await BrickLoader.generate(
        type: BrickType.riverpod,
        vars: {'name': 'User'},
        outputDir: outputDir,
      );

      expect(files.length, equals(2));
      
      final notifierFile = File(path.join(outputDir, 'user_notifier.dart'));
      expect(await notifierFile.exists(), isTrue);
      
      final notifierContent = await notifierFile.readAsString();
      expect(notifierContent, contains('class UserNotifier'));
      expect(notifierContent, contains('extends OrchestratorNotifier<UserState>'));
      expect(notifierContent, contains('buildState()'));
      expect(notifierContent, contains('orchestrator_riverpod'));
      expect(notifierContent, contains('final userProvider = NotifierProvider'));
      
      final stateFile = File(path.join(outputDir, 'user_state.dart'));
      expect(await stateFile.exists(), isTrue);
    });

    test('should handle PascalCase names', () async {
      final outputDir = tempDir.path;
      
      final files = await BrickLoader.generate(
        type: BrickType.job,
        vars: {'name': 'LoadProductDetails'},
        outputDir: outputDir,
      );

      expect(files.length, equals(1));
      
      final generatedFile = File(path.join(outputDir, 'load_product_details_job.dart'));
      expect(await generatedFile.exists(), isTrue);
      
      final content = await generatedFile.readAsString();
      expect(content, contains('class LoadProductDetailsJob'));
    });

    test('should handle single word names', () async {
      final outputDir = tempDir.path;
      
      final files = await BrickLoader.generate(
        type: BrickType.state,
        vars: {'name': 'Counter'},
        outputDir: outputDir,
      );

      expect(files.length, equals(1));
      
      final generatedFile = File(path.join(outputDir, 'counter_state.dart'));
      expect(await generatedFile.exists(), isTrue);
      
      final content = await generatedFile.readAsString();
      expect(content, contains('class CounterState'));
    });
  });
}
