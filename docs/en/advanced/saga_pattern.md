# Saga Pattern

> **Available since v0.5.2**

The Saga Pattern is a mechanism for managing robust, multi-step distributed transactions. In the Orchestrator architecture, it is used to coordinate multiple jobs where if one job fails, previous successful jobs must be compensated (rolled back) to ensure data consistency.

## Problem

When you have a workflow involving multiple independent steps:

1. Step A: Deduct money from Wallet (Success)
2. Step B: Add entry to Transaction History (Success)
3. Step C: Send notification to Server (Fail)

If Step C fails, the system is left in an inconsistent state (money deducted, but user not notified or operation marked as failed). You need to "undo" Step A and Step B.

## Solution

Use `SagaFlow` to register each step with a corresponding **compensation** action. If any step fails, `rollback()` is called to execute compensations in reverse order (LIFO).

## Usage

```dart
import 'package:orchestrator_core/orchestrator_core.dart';

Future<void> transferFunds() async {
  final saga = SagaFlow(name: 'TransferFunds');

  try {
    // Step 1: Withdraw from Source
    await saga.run(
      action: () async {
        await dispatch(WithdrawJob(sourceId, 100));
      },
      compensate: (_) async {
        // Rollback: Refund to Source
        await dispatch(DepositJob(sourceId, 100));
      },
    );

    // Step 2: Deposit to Target
    await saga.run(
      action: () async {
        await dispatch(DepositJob(targetId, 100));
      },
      compensate: (_) async {
        // Rollback: Withdraw from Target
        await dispatch(WithdrawJob(targetId, 100));
      },
    );

    // Success: Commit (clears compensations)
    saga.commit();
  } catch (e) {
    // Failure: Rollback
    print('Transfer failed: $e');
    await saga.rollback();
  }
}
```

## API Reference

### `SagaFlow`

- **`run({action, compensate})`**: Executes the `action`. If successful, registers the `compensate` function to the stack.
- **`rollback()`**: Executes all registered compensation functions in reverse order (LIFO). Use this in your `catch` block.
- **`commit()`**: Clears the compensation stack. Use this when the entire workflow completes successfully and rollback is no longer needed.
