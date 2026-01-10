import 'dart:async';
import 'package:meta/meta.dart';
import '../models/job.dart';
import '../models/undo_entry.dart';
import '../infra/dispatcher.dart';
import '../utils/logger.dart';
import '../mixins/reversible_job.dart';

/// Error handling strategies for multi-step undo operations (undoTo).
enum UndoStrategy {
  /// Stop immediately on first failure (default, safest).
  /// Already undone steps are NOT rolled back.
  stopOnError,

  /// Skip failed operation and continue with remaining steps.
  /// Best for resilience when individual steps might fail.
  skipAndContinue,

  /// Attempt to rollback all changes made so far if any step fails.
  /// Best when all-or-nothing semantics are required.
  rollbackAll,
}

/// Callback type for undo/redo lifecycle events that can block/cancel.
///
/// Return `true` to proceed with the operation, `false` to cancel.
/// This allows showing confirmation dialogs for sensitive operations:
///
/// ```dart
/// manager.onBeforeUndo = (entry) async {
///   if (entry.originalJob is SendEmailJob) {
///     return await showConfirmDialog(
///       'Sent emails cannot be recalled. Continue Undo?'
///     );
///   }
///   return true; // Proceed
/// };
/// ```
typedef UndoConfirmCallback = Future<bool> Function(UndoEntry entry);

/// Callback type for post-operation notifications (cannot cancel).
typedef UndoNotifyCallback = void Function(UndoEntry entry);

/// Callback type for error handling during undo/redo.
typedef UndoErrorCallback = void Function(
  UndoEntry entry,
  Object error,
  StackTrace? stack,
);

/// Manages undo/redo history with linear navigation and action coalescing.
///
/// ## Design Principles
///
/// ### Linear History (Preserve All)
/// Unlike traditional stacks, this manager preserves history even after undo:
/// ```
/// History: [A, B, C, D, E]
/// Index: 2 (pointing to C, D and E are "in the future")
///
/// After new action F:
/// History: [A, B, C, D, E, F]
/// Index: 5 (pointing to F, nothing discarded)
/// ```
///
/// This means users never lose redo entries - very user-friendly!
///
/// ### Dispatcher Injection
/// The Dispatcher is injected in the constructor, so `undo()` and `redo()`
/// don't require passing Dispatcher each time:
///
/// ```dart
/// final manager = UndoStackManager(dispatcher);
/// await manager.undo(); // Clean API
/// ```
///
/// ### Coalescing by Job Type
/// Rapid actions of the same Job type within `coalesceDuration` are merged:
/// - User types "H" → Job 1
/// - User types "He" (within 500ms) → Job 2 merges with Job 1
/// - User types "Hel" (within 500ms) → Job 3 merges with merged Job 2
///
/// Result: Single undo reverts all three typing actions to before "H".
///
/// ## Usage Patterns
///
/// ### Per-Orchestrator Scope
/// ```dart
/// class MyOrchestrator extends BaseOrchestrator<MyState> {
///   late final UndoStackManager undoManager;
///
///   @override
///   void onInit() {
///     undoManager = UndoStackManager(dispatcher, maxHistorySize: 50);
///   }
///
///   Future<void> createItem(String name) async {
///     final job = CreateItemJob(name);
///     final result = await dispatch(job).future;
///     undoManager.push(job, result.data);
///   }
///
///   Future<void> undo() async {
///     final entry = await undoManager.undo();
///     if (entry != null) showSnackBar('Undone: ${entry.description}');
///   }
/// }
/// ```
///
/// ### Global Singleton Scope
/// ```dart
/// // In main.dart
/// UndoStackManager.initGlobal(dispatcher, maxHistorySize: 100);
///
/// // Anywhere
/// final entry = await UndoStackManager.instance.undo();
/// ```
class UndoStackManager {
  /// The dispatcher to use for dispatching jobs.
  final Dispatcher dispatcher;

  /// Maximum number of entries to keep in history.
  ///
  /// When exceeded, oldest entries are removed.
  /// Default: 100
  final int maxHistorySize;

  /// Window for coalescing rapid actions of the same Job type.
  ///
  /// Default: 500ms
  ///
  /// Set to Duration.zero to disable coalescing.
  final Duration coalesceDuration;

  /// Internal history storage.
  final List<UndoEntry> _history = [];

  /// Current position in history (points to last executed action).
  /// -1 means no actions have been executed (empty or all undone).
  int _currentIndex = -1;

  /// Callbacks for lifecycle events.
  ///
  /// [onBeforeUndo] and [onBeforeRedo] can block/cancel the operation
  /// by returning `false`. Use for confirmation dialogs.
  ///
  /// [onAfterUndo] and [onAfterRedo] are notifications only (cannot cancel).
  UndoConfirmCallback? onBeforeUndo;
  UndoNotifyCallback? onAfterUndo;
  UndoConfirmCallback? onBeforeRedo;
  UndoNotifyCallback? onAfterRedo;
  UndoErrorCallback? onError;

  /// Logger
  OrchestratorLogger get _logger => OrchestratorConfig.logger;

  /// Global singleton instance (optional pattern).
  static UndoStackManager? _globalInstance;

  /// Access the global singleton instance.
  ///
  /// Throws [StateError] if [initGlobal] hasn't been called.
  static UndoStackManager get instance {
    if (_globalInstance == null) {
      throw StateError(
        'UndoStackManager.instance accessed before initGlobal(). '
        'Call UndoStackManager.initGlobal(dispatcher) first.',
      );
    }
    return _globalInstance!;
  }

  /// Check if global instance is initialized.
  static bool get hasGlobalInstance => _globalInstance != null;

  /// Initialize the global singleton.
  ///
  /// Safe to call multiple times - subsequent calls reset the instance.
  static void initGlobal(
    Dispatcher dispatcher, {
    int maxHistorySize = 100,
    Duration coalesceDuration = const Duration(milliseconds: 500),
  }) {
    _globalInstance = UndoStackManager(
      dispatcher,
      maxHistorySize: maxHistorySize,
      coalesceDuration: coalesceDuration,
    );
  }

  /// Reset global instance (for testing).
  @visibleForTesting
  static void resetGlobal() {
    _globalInstance?.clear();
    _globalInstance = null;
  }

  /// Creates a new UndoStackManager.
  ///
  /// [dispatcher] - Required: The dispatcher for dispatching undo/redo jobs
  /// [maxHistorySize] - Max history entries (default: 100)
  /// [coalesceDuration] - Window for coalescing rapid actions (default: 500ms)
  UndoStackManager(
    this.dispatcher, {
    this.maxHistorySize = 100,
    this.coalesceDuration = const Duration(milliseconds: 500),
  });

  // ============ Properties ============

  /// Number of actions that can be undone.
  int get undoCount => _currentIndex + 1;

  /// Number of actions that can be redone.
  int get redoCount => _history.length - _currentIndex - 1;

  /// Whether undo is available.
  bool get canUndo => _currentIndex >= 0;

  /// Whether redo is available.
  bool get canRedo => _currentIndex < _history.length - 1;

  /// Read-only view of the history.
  List<UndoEntry> get history => List.unmodifiable(_history);

  /// Current index in history (-1 if empty/all undone).
  int get currentIndex => _currentIndex;

  /// Total number of entries in history.
  int get historyLength => _history.length;

  /// Get a light-weight view of history for UI display.
  List<UndoHistoryEntry> getHistoryView() {
    return _history.asMap().entries.map((entry) {
      return UndoHistoryEntry.fromEntry(
        entry.value,
        index: entry.key,
        isUndone: entry.key > _currentIndex,
      );
    }).toList();
  }

  // ============ Core Operations ============

  /// Push a new reversible job result onto the stack.
  ///
  /// This is typically called after a job completes successfully.
  /// The job must implement [ReversibleJob] mixin.
  ///
  /// Parameters:
  /// - [job] - The executed job (must be ReversibleJob)
  /// - [result] - The result returned by the job execution
  /// - [sourceId] - Optional identifier for filtering (e.g., orchestrator name)
  ///
  /// If [job] is not reversible, logs a warning and returns without adding.
  void push(EventJob job, dynamic result, {String? sourceId}) {
    if (job is ReversibleJob) {
      _pushReversible(job, result, sourceId);
    } else {
      _logger.warning(
        'UndoStackManager.push() called with non-reversible job: ${job.runtimeType}',
      );
    }
  }

  /// Internal push for reversible jobs (type-safe).
  void _pushReversible(
    ReversibleJob reversible,
    dynamic result,
    String? sourceId,
  ) {
    final job = reversible as EventJob;

    // Check for coalescing
    if (coalesceDuration > Duration.zero && _shouldCoalesce(job)) {
      _coalesceWithLast(job, result, reversible, sourceId);
      return;
    }

    // Create inverse job
    final inverseJob = reversible.createInverse(result);

    final entry = UndoEntry(
      originalJob: job,
      inverseJob: inverseJob,
      originalResult: result,
      timestamp: DateTime.now(),
      description: reversible.undoDescription,
      sourceId: sourceId,
    );

    // Append to history (linear model - preserve all)
    _history.add(entry);
    _currentIndex = _history.length - 1;

    // Enforce max size by removing oldest entries
    while (_history.length > maxHistorySize) {
      _history.removeAt(0);
      _currentIndex--;
    }

    _logger.debug(
      '📝 UndoStackManager: Pushed ${job.runtimeType} '
      '(history: ${_history.length}, index: $_currentIndex)',
    );
  }

  /// Undo the last action.
  ///
  /// Dispatches the inverse job and moves the index backward.
  /// Returns the UndoEntry that was undone, or null if nothing to undo
  /// or if [onBeforeUndo] callback returned `false` (cancelled).
  ///
  /// The inverse job will emit its own domain event through the normal
  /// event pipeline. Callers can use the returned [UndoEntry] to display
  /// a confirmation message like "Undone: Create chamber 'Savings'".
  ///
  /// ## Cancellation
  ///
  /// If [onBeforeUndo] is set and returns `false`, the undo is cancelled
  /// and this method returns `null`. Use this to show confirmation dialogs:
  ///
  /// ```dart
  /// manager.onBeforeUndo = (entry) async {
  ///   if (entry.originalJob is SensitiveJob) {
  ///     return await showConfirmDialog('Are you sure?');
  ///   }
  ///   return true;
  /// };
  /// ```
  Future<UndoEntry?> undo() async {
    if (!canUndo) {
      _logger.debug(
          '↩️ UndoStackManager: Nothing to undo (index: $_currentIndex)');
      return null;
    }

    final entry = _history[_currentIndex];
    _logger.debug(
      '↩️ UndoStackManager: Undoing ${entry.originalJob.runtimeType}',
    );

    try {
      // Check if callback wants to cancel
      if (onBeforeUndo != null) {
        final shouldProceed = await onBeforeUndo!(entry);
        if (!shouldProceed) {
          _logger.debug(
              '↩️ UndoStackManager: Undo cancelled by onBeforeUndo callback');
          return null;
        }
      }

      // Dispatch inverse job
      final jobId = dispatcher.dispatch(entry.inverseJob);
      _logger.debug('↩️ Dispatched inverse job: $jobId');

      // Move index backward
      _currentIndex--;

      onAfterUndo?.call(entry);
      return entry;
    } catch (e, stack) {
      _logger.error('❌ UndoStackManager: Failed to undo', e, stack);
      onError?.call(entry, e, stack);
      rethrow;
    }
  }

  /// Redo the last undone action.
  ///
  /// Dispatches the original job again and moves the index forward.
  /// Returns the UndoEntry that was redone, or null if nothing to redo
  /// or if [onBeforeRedo] callback returned `false` (cancelled).
  ///
  /// The re-dispatched job will execute again, creating a new inverse job.
  /// This ensures the database remains consistent by running the business
  /// logic again rather than replaying a snapshot.
  ///
  /// ## Cancellation
  ///
  /// If [onBeforeRedo] is set and returns `false`, the redo is cancelled
  /// and this method returns `null`.
  Future<UndoEntry?> redo() async {
    if (!canRedo) {
      _logger.debug('🔄 UndoStackManager: Nothing to redo (at end of history)');
      return null;
    }

    final entry = _history[_currentIndex + 1];
    _logger.debug(
      '🔄 UndoStackManager: Redoing ${entry.originalJob.runtimeType}',
    );

    try {
      // Check if callback wants to cancel
      if (onBeforeRedo != null) {
        final shouldProceed = await onBeforeRedo!(entry);
        if (!shouldProceed) {
          _logger.debug(
              '🔄 UndoStackManager: Redo cancelled by onBeforeRedo callback');
          return null;
        }
      }

      // Move index forward first
      _currentIndex++;

      // Dispatch original job again
      final jobId = dispatcher.dispatch(entry.originalJob);
      _logger.debug('🔄 Dispatched original job again: $jobId');

      onAfterRedo?.call(entry);
      return entry;
    } catch (e, stack) {
      // Move index back on error
      _currentIndex--;
      _logger.error('❌ UndoStackManager: Failed to redo', e, stack);
      onError?.call(entry, e, stack);
      rethrow;
    }
  }

  /// Time-travel: undo to a specific index in history.
  ///
  /// Undoes all actions from current index down to (and including) [targetIndex].
  /// Example: If at index 5, calling undoTo(2) will undo entries at indices 5, 4, 3.
  ///
  /// Parameters:
  /// - [targetIndex] - The index to reach (0-based)
  /// - [strategy] - Error handling strategy (default: stopOnError)
  ///
  /// Returns [UndoToResult] with information about how many steps were undone,
  /// any errors encountered, and the final index reached.
  ///
  /// If [targetIndex] >= [currentIndex], returns success with 0 undone.
  /// If [targetIndex] < 0 and strategy allows, continues to -1 (all undone).
  Future<UndoToResult> undoTo(
    int targetIndex, {
    UndoStrategy strategy = UndoStrategy.stopOnError,
  }) async {
    _logger.debug(
      '⏮️ UndoStackManager: undoTo($targetIndex) from current($_currentIndex)',
    );

    if (targetIndex >= _currentIndex) {
      return UndoToResult(
        undoneCount: 0,
        attemptedCount: 0,
        targetIndex: targetIndex,
        finalIndex: _currentIndex,
        undoneEntries: [],
      );
    }

    if (targetIndex < -1) {
      return UndoToResult(
        undoneCount: 0,
        attemptedCount: 0,
        targetIndex: targetIndex,
        finalIndex: _currentIndex,
        undoneEntries: [],
        error: ArgumentError('targetIndex must be >= -1'),
      );
    }

    final undoneEntries = <UndoEntry>[];
    int attemptedCount = 0;
    Object? error;
    StackTrace? stackTrace;
    UndoEntry? failedEntry;

    try {
      // Undo from current down to target
      while (_currentIndex > targetIndex) {
        attemptedCount++;
        final entry = _history[_currentIndex];

        try {
          await undo();
          undoneEntries.add(entry);
        } catch (e, stack) {
          error = e;
          stackTrace = stack;
          failedEntry = entry;

          if (strategy == UndoStrategy.stopOnError) {
            _logger.warning(
              '⏮️ undoTo: Stopped at index $_currentIndex due to error',
            );
            break;
          } else if (strategy == UndoStrategy.skipAndContinue) {
            _logger.warning(
              '⏮️ undoTo: Skipping failed undo, continuing...',
            );
            _currentIndex--; // Skip the failed entry
            continue;
          } else if (strategy == UndoStrategy.rollbackAll) {
            // Rollback all successful undos
            _logger.warning(
              '⏮️ undoTo: Rolling back ${undoneEntries.length} successful undos',
            );
            for (final entry in undoneEntries.reversed) {
              try {
                await redo();
              } catch (rollbackError, rollbackStack) {
                _logger.error(
                  '⏮️ undoTo: Rollback failed for ${entry.originalJob.runtimeType}',
                  rollbackError,
                  rollbackStack,
                );
              }
            }
            break;
          }
        }
      }
    } catch (e, stack) {
      _logger.error('⏮️ undoTo: Unexpected error', e, stack);
      error ??= e;
      stackTrace ??= stack;
    }

    final result = UndoToResult(
      undoneCount: undoneEntries.length,
      attemptedCount: attemptedCount,
      targetIndex: targetIndex,
      finalIndex: _currentIndex,
      undoneEntries: undoneEntries,
      error: error,
      stackTrace: stackTrace,
      failedEntry: failedEntry,
    );

    _logger.debug(
      '⏮️ undoTo result: ${undoneEntries.length}/$attemptedCount successful, '
      'final index: $_currentIndex, success: ${result.isFullySuccessful}',
    );

    return result;
  }

  /// Time-travel: undo to a specific timestamp.
  ///
  /// Finds the first entry at or after the given timestamp and undoes to that point.
  /// Useful for UI with timestamp-based history (e.g., timeline slider).
  ///
  /// Returns [UndoToResult] with the operation results.
  /// If no entry is found at/after the timestamp, returns with error.
  Future<UndoToResult> undoToTimestamp(
    DateTime target, {
    UndoStrategy strategy = UndoStrategy.stopOnError,
  }) async {
    _logger.debug('⏱️ UndoStackManager: undoToTimestamp($target)');

    // Find the last entry at or before the target time
    int targetIndex = -1;
    for (int i = _currentIndex; i >= 0; i--) {
      if (_history[i].timestamp.isBefore(target) ||
          _history[i].timestamp.isAtSameMomentAs(target)) {
        targetIndex = i;
        break;
      }
    }

    if (targetIndex == _currentIndex) {
      return UndoToResult(
        undoneCount: 0,
        attemptedCount: 0,
        targetIndex: targetIndex,
        finalIndex: _currentIndex,
        undoneEntries: [],
      );
    }

    if (targetIndex < 0 && _currentIndex >= 0) {
      // All entries are after target time, undo everything
      targetIndex = -1;
    }

    if (targetIndex < -1) {
      return UndoToResult(
        undoneCount: 0,
        attemptedCount: 0,
        targetIndex: targetIndex,
        finalIndex: _currentIndex,
        undoneEntries: [],
        error: StateError('No entry found at or before timestamp $target'),
      );
    }

    return undoTo(targetIndex, strategy: strategy);
  }

  /// Clear all history.
  void clear() {
    _history.clear();
    _currentIndex = -1;
    _logger.debug('🗑️ UndoStackManager: Cleared all history');
  }

  // ============ Private Helpers ============

  /// Check if the job should be coalesced with the last entry.
  bool _shouldCoalesce(EventJob job) {
    if (_history.isEmpty || _currentIndex < 0) return false;
    final last = _history[_currentIndex];

    // Same job type?
    if (last.originalJob.runtimeType != job.runtimeType) return false;

    // Within coalesce window?
    final timeDiff = DateTime.now().difference(last.timestamp);
    return timeDiff <= coalesceDuration;
  }

  /// Coalesce a new job with the last entry.
  ///
  /// Keeps the original job but updates the inverse job.
  /// This is useful for rapid typing/slider changes:
  /// - User types "H" → Entry 1
  /// - User types "He" (within window) → Merges into Entry 1
  /// - User types "Hel" (within window) → Merges into Entry 1
  /// - Undo → Reverts all three keystrokes at once
  void _coalesceWithLast(
    EventJob job,
    dynamic result,
    ReversibleJob reversible,
    String? sourceId,
  ) {
    final oldEntry = _history[_currentIndex];
    final newInverseJob = reversible.createInverse(result);

    final coalesced = oldEntry.copyWith(
      inverseJob: newInverseJob,
      originalResult: result,
      timestamp: DateTime.now(),
      description: reversible.undoDescription ?? oldEntry.description,
    );

    _history[_currentIndex] = coalesced;

    _logger.debug(
      '🔗 UndoStackManager: Coalesced ${job.runtimeType} '
      '(updated inverse, kept original)',
    );
  }

  /// Dispose resources.
  ///
  /// Call this when the orchestrator/manager is being disposed.
  /// Clears all history and resets state.
  void dispose() {
    clear();
    onBeforeUndo = null;
    onAfterUndo = null;
    onBeforeRedo = null;
    onAfterRedo = null;
    onError = null;
    _logger.debug('🛑 UndoStackManager: Disposed');
  }
}
