import 'package:test/test.dart';
import 'package:orchestrator_core/orchestrator_core.dart';

void main() {
  group('SagaFlow', () {
    group('Basic Operations', () {
      test('run() executes action and returns result', () async {
        final saga = SagaFlow(name: 'BasicTest');

        final result = await saga.run(
          action: () async => 'step1-result',
          compensate: (_) async {},
        );

        expect(result, equals('step1-result'));
        expect(saga.stepCount, equals(1));
        expect(saga.hasSteps, isTrue);
      });

      test('multiple run() calls execute in order', () async {
        final saga = SagaFlow(name: 'MultiStep');
        final executionOrder = <int>[];

        await saga.run(
          action: () async {
            executionOrder.add(1);
            return 'first';
          },
          compensate: (_) async {},
        );

        await saga.run(
          action: () async {
            executionOrder.add(2);
            return 'second';
          },
          compensate: (_) async {},
        );

        await saga.run(
          action: () async {
            executionOrder.add(3);
            return 'third';
          },
          compensate: (_) async {},
        );

        expect(executionOrder, equals([1, 2, 3]));
        expect(saga.stepCount, equals(3));
      });

      test('commit() clears compensations', () async {
        final saga = SagaFlow(name: 'CommitTest');

        await saga.run(
          action: () async => 'data',
          compensate: (_) async {},
        );

        expect(saga.stepCount, equals(1));

        saga.commit();

        expect(saga.stepCount, equals(0));
        expect(saga.hasSteps, isFalse);
      });

      test('commit() on empty saga is no-op', () {
        final saga = SagaFlow(name: 'EmptyCommit');

        // Should not throw
        saga.commit();

        expect(saga.stepCount, equals(0));
      });
    });

    group('Rollback', () {
      test('rollback() executes compensations in LIFO order', () async {
        final saga = SagaFlow(name: 'LIFOTest');
        final compensationOrder = <int>[];

        await saga.run(
          action: () async => 1,
          compensate: (result) async {
            compensationOrder.add(result);
          },
        );

        await saga.run(
          action: () async => 2,
          compensate: (result) async {
            compensationOrder.add(result);
          },
        );

        await saga.run(
          action: () async => 3,
          compensate: (result) async {
            compensationOrder.add(result);
          },
        );

        await saga.rollback();

        // LIFO: 3, 2, 1
        expect(compensationOrder, equals([3, 2, 1]));
        expect(saga.stepCount, equals(0));
      });

      test('rollback() on empty saga is no-op', () async {
        final saga = SagaFlow(name: 'EmptyRollback');

        // Should not throw
        await saga.rollback();

        expect(saga.stepCount, equals(0));
      });

      test('rollback() receives captured result from action', () async {
        final saga = SagaFlow(name: 'CaptureTest');
        String? capturedResult;

        await saga.run(
          action: () async => 'important-id-12345',
          compensate: (result) async {
            capturedResult = result;
          },
        );

        await saga.rollback();

        expect(capturedResult, equals('important-id-12345'));
      });

      test('rollback() clears compensations after execution', () async {
        final saga = SagaFlow(name: 'ClearAfterRollback');

        await saga.run(
          action: () async => 'data',
          compensate: (_) async {},
        );

        await saga.rollback();

        // Should be empty after rollback
        expect(saga.stepCount, equals(0));

        // Second rollback should be no-op
        await saga.rollback();
      });
    });

    group('Error Handling', () {
      test('failed action does not register compensation', () async {
        final saga = SagaFlow(name: 'FailedAction');
        var compensationCalled = false;

        try {
          await saga.run(
            action: () async {
              throw Exception('Action failed');
            },
            compensate: (_) async {
              compensationCalled = true;
            },
          );
        } catch (_) {
          // Expected
        }

        // No compensation should be registered
        expect(saga.stepCount, equals(0));

        // Rollback should not call compensation
        await saga.rollback();
        expect(compensationCalled, isFalse);
      });

      test('failed action rethrows error', () async {
        final saga = SagaFlow(name: 'RethrowTest');

        expect(
          () async => await saga.run(
            action: () async {
              throw FormatException('Bad format');
            },
            compensate: (_) async {},
          ),
          throwsA(isA<FormatException>()),
        );
      });

      test('compensation failure does not stop other compensations (best-effort)', () async {
        final saga = SagaFlow(name: 'BestEffort');
        final executedCompensations = <int>[];

        await saga.run(
          action: () async => 1,
          compensate: (result) async {
            executedCompensations.add(result);
          },
        );

        await saga.run(
          action: () async => 2,
          compensate: (result) async {
            throw Exception('Compensation 2 failed');
          },
        );

        await saga.run(
          action: () async => 3,
          compensate: (result) async {
            executedCompensations.add(result);
          },
        );

        // Rollback should continue despite compensation 2 failing
        await saga.rollback();

        // Compensation 3 and 1 should have executed (2 failed but 1 still runs)
        expect(executedCompensations, contains(3));
        expect(executedCompensations, contains(1));
        expect(saga.stepCount, equals(0)); // Still cleared
      });
    });

    group('Real-World Workflow Simulation', () {
      test('transfer workflow with successful completion', () async {
        final saga = SagaFlow(name: 'TransferAsset');

        // Simulate: source account, target account balances
        var sourceBalance = 1000;
        var targetBalance = 500;

        try {
          // Step 1: Deduct from source
          await saga.run(
            action: () async {
              sourceBalance -= 200;
              return 200; // Amount deducted
            },
            compensate: (amount) async {
              sourceBalance += amount; // Refund
            },
          );

          // Step 2: Add to target
          await saga.run(
            action: () async {
              targetBalance += 200;
              return 200;
            },
            compensate: (amount) async {
              targetBalance -= amount; // Reverse
            },
          );

          saga.commit();
        } catch (e) {
          await saga.rollback();
          rethrow;
        }

        expect(sourceBalance, equals(800));
        expect(targetBalance, equals(700));
      });

      test('transfer workflow with failure triggers rollback', () async {
        final saga = SagaFlow(name: 'TransferAssetFail');

        var sourceBalance = 1000;
        var targetBalance = 500;

        try {
          // Step 1: Deduct from source (success)
          await saga.run(
            action: () async {
              sourceBalance -= 200;
              return 200;
            },
            compensate: (amount) async {
              sourceBalance += amount;
            },
          );

          // Step 2: Add to target (fails)
          await saga.run<int>(
            action: () async {
              throw Exception('Target account frozen');
            },
            compensate: (int amount) async {
              targetBalance -= amount;
            },
          );

          saga.commit();
        } catch (e) {
          await saga.rollback();
        }

        // Source should be refunded back to original
        expect(sourceBalance, equals(1000));
        // Target unchanged (step 2 failed, compensation not registered)
        expect(targetBalance, equals(500));
      });

      test('three-step workflow partial failure rollback', () async {
        final saga = SagaFlow(name: 'ThreeStepWorkflow');
        final log = <String>[];

        try {
          await saga.run(
            action: () async {
              log.add('step1-execute');
              return 'record-1';
            },
            compensate: (id) async {
              log.add('step1-compensate:$id');
            },
          );

          await saga.run(
            action: () async {
              log.add('step2-execute');
              return 'record-2';
            },
            compensate: (id) async {
              log.add('step2-compensate:$id');
            },
          );

          await saga.run(
            action: () async {
              log.add('step3-execute');
              throw Exception('Step 3 network error');
            },
            compensate: (id) async {
              log.add('step3-compensate:$id');
            },
          );

          saga.commit();
        } catch (e) {
          await saga.rollback();
        }

        // Execution: 1, 2, 3 (failed)
        // Compensation: 2, 1 (LIFO, step 3 not registered)
        expect(log, equals([
          'step1-execute',
          'step2-execute',
          'step3-execute',
          'step2-compensate:record-2',
          'step1-compensate:record-1',
        ]));
      });
    });

    group('Edge Cases', () {
      test('saga without name works correctly', () async {
        final saga = SagaFlow(); // No name

        await saga.run(
          action: () async => 'data',
          compensate: (_) async {},
        );

        expect(saga.stepCount, equals(1));
        saga.commit();
        expect(saga.stepCount, equals(0));
      });

      test('typed results are preserved', () async {
        final saga = SagaFlow(name: 'TypedTest');

        // Different types
        final intResult = await saga.run<int>(
          action: () async => 42,
          compensate: (_) async {},
        );

        final stringResult = await saga.run<String>(
          action: () async => 'hello',
          compensate: (_) async {},
        );

        final listResult = await saga.run<List<int>>(
          action: () async => [1, 2, 3],
          compensate: (_) async {},
        );

        expect(intResult, isA<int>());
        expect(intResult, equals(42));
        expect(stringResult, isA<String>());
        expect(stringResult, equals('hello'));
        expect(listResult, isA<List<int>>());
        expect(listResult, equals([1, 2, 3]));

        saga.commit();
      });

      test('async compensations execute properly', () async {
        final saga = SagaFlow(name: 'AsyncCompensation');
        final timestamps = <int>[];

        await saga.run(
          action: () async => 1,
          compensate: (_) async {
            timestamps.add(DateTime.now().millisecondsSinceEpoch);
            await Future.delayed(Duration(milliseconds: 50));
          },
        );

        await saga.run(
          action: () async => 2,
          compensate: (_) async {
            timestamps.add(DateTime.now().millisecondsSinceEpoch);
            await Future.delayed(Duration(milliseconds: 50));
          },
        );

        await saga.rollback();

        // Both compensations should have executed
        expect(timestamps.length, equals(2));
        // Second one should start after first (sequential execution)
        expect(timestamps[1], greaterThanOrEqualTo(timestamps[0]));
      });
    });
  });
}
