import 'package:test/test.dart';
import 'package:orchestrator_core/orchestrator_core.dart';

// ============ Mock Jobs and Events ============

/// Mock event for testing
class MockEvent extends BaseEvent {
  final String message;
  MockEvent(super.jobId, this.message);

  @override
  String toString() => 'MockEvent($message)';
}

/// Simple reversible job for testing - using raw EventJob type
class MockCreateJob extends EventJob with ReversibleJob {
  final String name;

  MockCreateJob({String? id, required this.name})
      : super(id: id ?? 'create_${DateTime.now().microsecondsSinceEpoch}');

  @override
  MockEvent createEventTyped(dynamic result) =>
      MockEvent(id, 'Created: $result');

  @override
  EventJob createInverse(dynamic result) {
    return MockDeleteJob(
      deletedName: result as String,
      id: 'delete_$id',
    );
  }

  @override
  String? get undoDescription => 'Create "$name"';
}

/// Inverse of MockCreateJob
class MockDeleteJob extends EventJob with ReversibleJob {
  final String deletedName;

  MockDeleteJob({String? id, required this.deletedName})
      : super(id: id ?? 'delete_${DateTime.now().microsecondsSinceEpoch}');

  @override
  MockEvent createEventTyped(dynamic result) =>
      MockEvent(id, 'Deleted: $deletedName');

  @override
  EventJob createInverse(dynamic result) {
    return MockCreateJob(
      name: deletedName,
      id: 'create_$id',
    );
  }

  @override
  String? get undoDescription => 'Delete "$deletedName"';
}

/// Non-reversible job for testing
class MockNonReversibleJob extends EventJob {
  MockNonReversibleJob()
      : super(id: 'non_reversible_${DateTime.now().microsecondsSinceEpoch}');

  @override
  MockEvent createEventTyped(dynamic result) => MockEvent(id, 'Non-reversible');
}

/// Coalescing test job (same type for rapid actions)
class MockCoalesceJob extends EventJob with ReversibleJob {
  final String text;

  MockCoalesceJob({String? id, required this.text})
      : super(id: id ?? 'coalesce_${DateTime.now().microsecondsSinceEpoch}');

  @override
  MockEvent createEventTyped(dynamic result) => MockEvent(id, 'Text: $result');

  @override
  EventJob createInverse(dynamic result) {
    final currentText = result as String;
    final previousText = currentText.isEmpty
        ? ''
        : currentText.substring(0, currentText.length - 1);
    return MockCoalesceJob(
      text: previousText,
      id: 'coalesce_revert_$id',
    );
  }

  @override
  String? get undoDescription => 'Type "$text"';
}

// ============ Mock Executor ============

/// Simple executor that does nothing (for testing undo/redo dispatch)
class MockExecutor extends BaseExecutor<EventJob> {
  final List<EventJob> executedJobs = [];

  @override
  Future<dynamic> process(EventJob job) async {
    executedJobs.add(job);
    return null; // Mock result
  }

  void reset() => executedJobs.clear();
}

// ============ Tests ============

void main() {
  // Use the singleton Dispatcher with registered mock executors
  final dispatcher = Dispatcher();
  final mockExecutor = MockExecutor();

  setUpAll(() {
    // Register mock executor for all our test job types
    dispatcher.registerByType(MockCreateJob, mockExecutor);
    dispatcher.registerByType(MockDeleteJob, mockExecutor);
    dispatcher.registerByType(MockCoalesceJob, mockExecutor);
    dispatcher.registerByType(MockNonReversibleJob, mockExecutor);
  });

  tearDownAll(() {
    dispatcher.clear();
  });

  group('ReversibleJob Mixin', () {
    test('createInverse creates proper inverse job', () {
      final job = MockCreateJob(name: 'TestChamber');
      final inverse = job.createInverse('TestChamber');

      expect(inverse, isA<MockDeleteJob>());
      expect((inverse as MockDeleteJob).deletedName, equals('TestChamber'));
    });

    test('undoDescription provides UI text', () {
      final job = MockCreateJob(name: 'Savings');
      expect(job.undoDescription, equals('Create "Savings"'));
    });

    test('undoDescription can be overridden', () {
      final deleteJob = MockDeleteJob(deletedName: 'Test');
      expect(deleteJob.undoDescription, equals('Delete "Test"'));
    });
  });

  group('UndoEntry', () {
    test('creates with all required fields', () {
      final original = MockCreateJob(name: 'Test');
      final inverse = MockDeleteJob(deletedName: 'Test');
      final now = DateTime.now();

      final entry = UndoEntry(
        originalJob: original,
        inverseJob: inverse,
        originalResult: 'Test',
        timestamp: now,
        description: 'Create Test',
        sourceId: 'TestOrchestrator',
      );

      expect(entry.originalJob, equals(original));
      expect(entry.inverseJob, equals(inverse));
      expect(entry.originalResult, equals('Test'));
      expect(entry.timestamp, equals(now));
      expect(entry.description, equals('Create Test'));
      expect(entry.sourceId, equals('TestOrchestrator'));
    });

    test('copyWith creates modified copy', () {
      final original = MockCreateJob(name: 'Test');
      final inverse = MockDeleteJob(deletedName: 'Test');
      final entry = UndoEntry(
        originalJob: original,
        inverseJob: inverse,
        originalResult: 'Test',
        timestamp: DateTime.now(),
        description: 'Original',
      );

      final newInverse = MockDeleteJob(deletedName: 'Updated');
      final copied = entry.copyWith(
        inverseJob: newInverse,
        description: 'Updated',
      );

      expect(copied.originalJob, equals(original));
      expect(copied.inverseJob, equals(newInverse));
      expect(copied.description, equals('Updated'));
      expect(copied.originalResult, equals(entry.originalResult));
    });

    test('equality based on job IDs and timestamp', () {
      final job = MockCreateJob(id: 'same_id', name: 'Test');
      final inverse = MockDeleteJob(deletedName: 'Test');
      final now = DateTime.now();

      final entry1 = UndoEntry(
        originalJob: job,
        inverseJob: inverse,
        originalResult: 'Test',
        timestamp: now,
      );

      final entry2 = UndoEntry(
        originalJob: job,
        inverseJob: inverse,
        originalResult: 'Test',
        timestamp: now,
      );

      expect(entry1, equals(entry2));
    });
  });

  group('UndoStackManager - Basic Operations', () {
    late UndoStackManager manager;

    setUp(() {
      // Disable coalescing for basic tests
      manager = UndoStackManager(
        dispatcher,
        maxHistorySize: 10,
        coalesceDuration: Duration.zero,
      );
      mockExecutor.reset();
    });

    test('initially empty with no undo/redo available', () {
      expect(manager.undoCount, equals(0));
      expect(manager.redoCount, equals(0));
      expect(manager.canUndo, isFalse);
      expect(manager.canRedo, isFalse);
      expect(manager.history, isEmpty);
    });

    test('push adds reversible job to history', () {
      final job = MockCreateJob(name: 'Chamber1');
      manager.push(job, 'Chamber1');

      expect(manager.undoCount, equals(1));
      expect(manager.redoCount, equals(0));
      expect(manager.canUndo, isTrue);
      expect(manager.canRedo, isFalse);
      expect(manager.history, hasLength(1));
    });

    test('push ignores non-reversible jobs', () {
      final job = MockNonReversibleJob();
      manager.push(job, 'result');

      expect(manager.undoCount, equals(0));
      expect(manager.history, isEmpty);
    });

    test('push updates description from undoDescription', () {
      final job = MockCreateJob(name: 'TestName');
      manager.push(job, 'TestName');

      expect(manager.history[0].description, equals('Create "TestName"'));
    });

    test('push respects maxHistorySize', () {
      // Using different manager with smaller size for clarity
      // Note: coalesceDuration=0 to prevent coalescing same-type jobs
      final smallManager = UndoStackManager(
        dispatcher,
        maxHistorySize: 5,
        coalesceDuration: Duration.zero,
      );
      for (int i = 0; i < 8; i++) {
        final job = MockCreateJob(name: 'Item$i');
        smallManager.push(job, 'Item$i');
      }

      // Should have max 5 items
      expect(smallManager.history, hasLength(5));
      // Current index should be at the end
      expect(smallManager.currentIndex, equals(4));
    });

    test('clear removes all history', () {
      manager.push(MockCreateJob(name: 'A'), 'A');
      manager.push(MockCreateJob(name: 'B'), 'B');
      expect(manager.history, hasLength(2));

      manager.clear();

      expect(manager.history, isEmpty);
      expect(manager.currentIndex, equals(-1));
    });
  });

  group('UndoStackManager - Undo/Redo', () {
    late UndoStackManager manager;

    setUp(() {
      // Disable coalescing for these tests
      manager = UndoStackManager(dispatcher, coalesceDuration: Duration.zero);
      mockExecutor.reset();
    });

    test('undo returns null when nothing to undo', () async {
      final result = await manager.undo();
      expect(result, isNull);
    });

    test('undo dispatches inverse job and returns entry', () async {
      final job = MockCreateJob(name: 'Test');
      manager.push(job, 'Test');
      mockExecutor.reset();

      final entry = await manager.undo();

      expect(entry, isNotNull);
      expect(entry!.description, equals('Create "Test"'));
      expect(mockExecutor.executedJobs, hasLength(1));
      expect(mockExecutor.executedJobs[0], isA<MockDeleteJob>());
    });

    test('undo moves index backward', () async {
      manager.push(MockCreateJob(name: 'A'), 'A');
      manager.push(MockCreateJob(name: 'B'), 'B');
      expect(manager.currentIndex, equals(1));

      await manager.undo();
      expect(manager.currentIndex, equals(0));

      await manager.undo();
      expect(manager.currentIndex, equals(-1));
    });

    test('canUndo updated after undo', () async {
      manager.push(MockCreateJob(name: 'Test'), 'Test');
      expect(manager.canUndo, isTrue);

      await manager.undo();
      expect(manager.canUndo, isFalse);
    });

    test('redo returns null when nothing to redo', () async {
      final result = await manager.redo();
      expect(result, isNull);
    });

    test('redo dispatches original job and returns entry', () async {
      final job = MockCreateJob(name: 'Test');
      manager.push(job, 'Test');
      await manager.undo();
      mockExecutor.reset();

      final entry = await manager.redo();

      expect(entry, isNotNull);
      expect(entry!.description, equals('Create "Test"'));
      expect(mockExecutor.executedJobs, hasLength(1));
      expect(mockExecutor.executedJobs[0], isA<MockCreateJob>());
    });

    test('redo moves index forward', () async {
      manager.push(MockCreateJob(name: 'A'), 'A');
      manager.push(MockCreateJob(name: 'B'), 'B');
      await manager.undo();
      await manager.undo();
      expect(manager.currentIndex, equals(-1));

      await manager.redo();
      expect(manager.currentIndex, equals(0));

      await manager.redo();
      expect(manager.currentIndex, equals(1));
    });

    test('canRedo updated after redo', () async {
      manager.push(MockCreateJob(name: 'Test'), 'Test');
      await manager.undo();
      expect(manager.canRedo, isTrue);

      await manager.redo();
      expect(manager.canRedo, isFalse);
    });
  });

  group('UndoStackManager - Linear History (Preserve All)', () {
    late UndoStackManager manager;

    setUp(() {
      // Disable coalescing for these tests
      manager = UndoStackManager(dispatcher, coalesceDuration: Duration.zero);
      mockExecutor.reset();
    });

    test('new action appends to history after undo', () async {
      manager.push(MockCreateJob(name: 'A'), 'A');
      manager.push(MockCreateJob(name: 'B'), 'B');
      manager.push(MockCreateJob(name: 'C'), 'C');

      // Undo twice
      await manager.undo();
      await manager.undo();

      // New action
      manager.push(MockCreateJob(name: 'D'), 'D');

      // History should preserve A, B, C, and add D
      expect(manager.history, hasLength(4));
      expect(manager.currentIndex, equals(3));
      expect(manager.redoCount, equals(0));
    });

    test('redo count reflects preserved history', () async {
      manager.push(MockCreateJob(name: 'A'), 'A');
      manager.push(MockCreateJob(name: 'B'), 'B');
      manager.push(MockCreateJob(name: 'C'), 'C');

      await manager.undo();
      expect(manager.redoCount, equals(1));

      await manager.undo();
      expect(manager.redoCount, equals(2));

      manager.push(MockCreateJob(name: 'D'), 'D');
      expect(manager.redoCount, equals(0));
    });
  });

  group('UndoStackManager - Coalescing', () {
    late UndoStackManager manager;

    setUp(() {
      manager = UndoStackManager(
        dispatcher,
        coalesceDuration: const Duration(milliseconds: 500),
      );
      mockExecutor.reset();
    });

    test('rapid same-type jobs coalesce into single entry', () {
      manager.push(MockCoalesceJob(text: 'H'), 'H');
      expect(manager.history, hasLength(1));

      // Within window - should coalesce
      manager.push(MockCoalesceJob(text: 'He'), 'He');
      expect(manager.history, hasLength(1));

      manager.push(MockCoalesceJob(text: 'Hel'), 'Hel');
      expect(manager.history, hasLength(1));
    });

    test('coalescing preserves original job but updates inverse', () {
      manager.push(MockCoalesceJob(text: 'H'), 'H');

      manager.push(MockCoalesceJob(text: 'He'), 'He');
      manager.push(MockCoalesceJob(text: 'Hel'), 'Hel');

      // Inverse should be updated to latest
      final inverseJob = manager.history[0].inverseJob as MockCoalesceJob;
      expect(inverseJob.text, equals('He')); // Inverse of 'Hel' -> 'He'
    });

    test('different job types do not coalesce', () {
      manager.push(MockCreateJob(name: 'A'), 'A');
      manager.push(MockCoalesceJob(text: 'B'), 'B');

      expect(manager.history, hasLength(2));
    });

    test('coalescing disabled with zero duration', () {
      final noCoalesceManager = UndoStackManager(
        dispatcher,
        coalesceDuration: Duration.zero,
      );

      noCoalesceManager.push(MockCoalesceJob(text: 'H'), 'H');
      noCoalesceManager.push(MockCoalesceJob(text: 'He'), 'He');

      expect(noCoalesceManager.history, hasLength(2));
    });

    test('old entry drops out of coalesce window', () async {
      manager.push(MockCoalesceJob(text: 'H'), 'H');

      // Wait for window to expire
      await Future.delayed(const Duration(milliseconds: 600));

      manager.push(MockCoalesceJob(text: 'He'), 'He');

      expect(manager.history, hasLength(2));
    });
  });

  group('UndoStackManager - undoTo', () {
    late UndoStackManager manager;

    setUp(() {
      // Disable coalescing for these tests - we need separate entries
      manager = UndoStackManager(dispatcher, coalesceDuration: Duration.zero);
      mockExecutor.reset();
    });

    test('undoTo returns 0 undone when already past target', () async {
      manager.push(MockCreateJob(name: 'A'), 'A');
      manager.push(MockCreateJob(name: 'B'), 'B');

      final result = await manager.undoTo(3);

      expect(result.undoneCount, equals(0));
      expect(result.attemptedCount, equals(0));
      expect(result.isFullySuccessful, isTrue);
    });

    test('undoTo reaches target index', () async {
      manager.push(MockCreateJob(name: 'A'), 'A');
      manager.push(MockCreateJob(name: 'B'), 'B');
      manager.push(MockCreateJob(name: 'C'), 'C');
      manager.push(MockCreateJob(name: 'D'), 'D');
      expect(manager.currentIndex, equals(3));

      final result = await manager.undoTo(1);

      expect(result.undoneCount, equals(2));
      expect(result.finalIndex, equals(1));
      expect(manager.currentIndex, equals(1));
    });

    test('undoTo(-1) undoes all actions', () async {
      manager.push(MockCreateJob(name: 'A'), 'A');
      manager.push(MockCreateJob(name: 'B'), 'B');

      final result = await manager.undoTo(-1);

      expect(result.undoneCount, equals(2));
      expect(result.finalIndex, equals(-1));
      expect(manager.currentIndex, equals(-1));
    });
  });

  group('UndoStackManager - undoToTimestamp', () {
    late UndoStackManager manager;

    setUp(() {
      // Disable coalescing for these tests - we need separate entries
      manager = UndoStackManager(dispatcher, coalesceDuration: Duration.zero);
      mockExecutor.reset();
    });

    test('undoToTimestamp finds correct entry', () async {
      manager.push(MockCreateJob(name: 'A'), 'A');

      await Future.delayed(const Duration(milliseconds: 100));
      final time2 = DateTime.now();
      manager.push(MockCreateJob(name: 'B'), 'B');

      await Future.delayed(const Duration(milliseconds: 100));
      manager.push(MockCreateJob(name: 'C'), 'C');

      final result = await manager.undoToTimestamp(
        time2.add(const Duration(milliseconds: 50)),
      );

      expect(result.undoneCount, equals(1)); // Undo C only
      expect(manager.currentIndex, equals(1)); // At B
    });

    test('undoToTimestamp before all entries undoes all', () async {
      manager.push(MockCreateJob(name: 'A'), 'A');
      await Future.delayed(const Duration(milliseconds: 50));
      manager.push(MockCreateJob(name: 'B'), 'B');

      final earlyTime = DateTime.now().subtract(const Duration(seconds: 10));
      final result = await manager.undoToTimestamp(earlyTime);

      expect(result.undoneCount, equals(2));
      expect(manager.currentIndex, equals(-1));
    });
  });

  group('UndoStackManager - Global Singleton', () {
    tearDown(() {
      UndoStackManager.resetGlobal();
    });

    test('initGlobal creates singleton instance', () {
      expect(UndoStackManager.hasGlobalInstance, isFalse);

      UndoStackManager.initGlobal(dispatcher, maxHistorySize: 50);

      expect(UndoStackManager.hasGlobalInstance, isTrue);
      expect(UndoStackManager.instance.maxHistorySize, equals(50));
    });

    test('accessing instance before init throws StateError', () {
      expect(
        () => UndoStackManager.instance,
        throwsA(isA<StateError>()),
      );
    });

    test('global instance shared across calls', () {
      UndoStackManager.initGlobal(dispatcher);

      final instance1 = UndoStackManager.instance;
      final instance2 = UndoStackManager.instance;

      expect(identical(instance1, instance2), isTrue);
    });

    test('resetGlobal clears singleton', () {
      UndoStackManager.initGlobal(dispatcher);
      UndoStackManager.instance.push(MockCreateJob(name: 'Test'), 'Test');
      expect(UndoStackManager.instance.history, hasLength(1));

      UndoStackManager.resetGlobal();

      expect(UndoStackManager.hasGlobalInstance, isFalse);
    });
  });

  group('UndoStackManager - Callbacks', () {
    late UndoStackManager manager;

    setUp(() {
      // Disable coalescing for these tests
      manager = UndoStackManager(dispatcher, coalesceDuration: Duration.zero);
      mockExecutor.reset();
    });

    test('onBeforeUndo called before undo', () async {
      UndoEntry? callbackEntry;
      manager.onBeforeUndo = (entry) async {
        callbackEntry = entry;
        return true; // Allow undo to proceed
      };

      manager.push(MockCreateJob(name: 'Test'), 'Test');
      await manager.undo();

      expect(callbackEntry, isNotNull);
      expect(callbackEntry!.description, equals('Create "Test"'));
    });

    test('onBeforeUndo returning false cancels undo', () async {
      manager.onBeforeUndo = (entry) async {
        return false; // Cancel undo
      };

      manager.push(MockCreateJob(name: 'Test'), 'Test');
      final result = await manager.undo();

      expect(result, isNull); // Undo was cancelled
      expect(manager.currentIndex, equals(0)); // Index unchanged
      expect(manager.canUndo, isTrue); // Still can undo
    });

    test('onAfterUndo called after undo', () async {
      UndoEntry? callbackEntry;
      manager.onAfterUndo = (entry) {
        callbackEntry = entry;
      };

      manager.push(MockCreateJob(name: 'Test'), 'Test');
      await manager.undo();

      expect(callbackEntry, isNotNull);
    });

    test('onBeforeRedo called before redo', () async {
      UndoEntry? callbackEntry;
      manager.onBeforeRedo = (entry) async {
        callbackEntry = entry;
        return true; // Allow redo to proceed
      };

      manager.push(MockCreateJob(name: 'Test'), 'Test');
      await manager.undo();
      await manager.redo();

      expect(callbackEntry, isNotNull);
    });

    test('onBeforeRedo returning false cancels redo', () async {
      manager.onBeforeRedo = (entry) async {
        return false; // Cancel redo
      };

      manager.push(MockCreateJob(name: 'Test'), 'Test');
      await manager.undo();
      expect(manager.canRedo, isTrue);

      final result = await manager.redo();

      expect(result, isNull); // Redo was cancelled
      expect(manager.currentIndex, equals(-1)); // Index unchanged
      expect(manager.canRedo, isTrue); // Still can redo
    });

    test('onBeforeUndo can show confirmation dialog simulation', () async {
      var dialogShown = false;
      manager.onBeforeUndo = (entry) async {
        dialogShown = true;
        // Simulate user clicking "Yes" in confirmation dialog
        await Future.delayed(Duration(milliseconds: 10));
        return true;
      };

      manager.push(MockCreateJob(name: 'Sensitive'), 'Sensitive');
      final result = await manager.undo();

      expect(dialogShown, isTrue);
      expect(result, isNotNull);
      expect(result!.description, equals('Create "Sensitive"'));
    });
  });

  group('UndoStackManager - Edge Cases', () {
    late UndoStackManager manager;

    setUp(() {
      // Disable coalescing, small maxHistorySize for edge case tests
      manager = UndoStackManager(
        dispatcher,
        maxHistorySize: 3,
        coalesceDuration: Duration.zero,
      );
      mockExecutor.reset();
    });

    test('circular undo/redo operations', () async {
      manager.push(MockCreateJob(name: 'A'), 'A');

      await manager.undo();
      expect(manager.currentIndex, equals(-1));

      await manager.redo();
      expect(manager.currentIndex, equals(0));

      await manager.undo();
      expect(manager.currentIndex, equals(-1));
    });

    test('getHistoryView marks entries correctly', () async {
      manager.push(MockCreateJob(name: 'A'), 'A');
      manager.push(MockCreateJob(name: 'B'), 'B');
      manager.push(MockCreateJob(name: 'C'), 'C');

      await manager.undo();
      await manager.undo(); // Now at index 0 (A)

      final view = manager.getHistoryView();

      expect(view[0].isUndone, isFalse); // A at index 0, currentIndex=0, not undone
      expect(view[1].isUndone, isTrue); // B at index 1, 1 > 0, undone
      expect(view[2].isUndone, isTrue); // C at index 2, 2 > 0, undone
    });

    test('dispose clears resources', () {
      manager.push(MockCreateJob(name: 'A'), 'A');
      manager.onBeforeUndo = (entry) async => true;

      manager.dispose();

      expect(manager.history, isEmpty);
      expect(manager.onBeforeUndo, isNull);
    });
  });
}
