import 'package:meta/meta.dart';
import 'job.dart';

/// Represents a single undoable operation in the history stack.
///
/// Contains both the original job (for redo) and its inverse (for undo),
/// along with metadata for tracking and display.
///
/// ## Data Structure
///
/// ```
/// UndoEntry {
///   originalJob: CreateChamberJob(name: "Savings")
///   inverseJob: DeleteChamberJob(id: "chamber_123")
///   originalResult: Chamber(id: "chamber_123", name: "Savings")
///   timestamp: 2024-01-15T10:30:00
///   description: "Create chamber 'Savings'"
///   sourceId: "NestOrchestrator"
/// }
/// ```
///
/// ## Usage in UndoStackManager
///
/// - **Undo**: Dispatch `inverseJob`
/// - **Redo**: Dispatch `originalJob` (creates new result → new inverse)
///
/// ## Immutability
///
/// UndoEntry is immutable. Use [copyWith] to create modified copies
/// (e.g., when coalescing rapid actions).
@immutable
class UndoEntry {
  /// The job that was originally executed.
  ///
  /// Used for:
  /// - Redo operation (re-dispatch this job)
  /// - Display information (job type, parameters)
  /// - Coalescing check (compare runtimeType)
  final EventJob originalJob;

  /// The inverse job that undoes the original operation.
  ///
  /// Created by calling `(originalJob as ReversibleJob).createInverse(result)`
  /// when the original job completes.
  ///
  /// Used for:
  /// - Undo operation (dispatch this job)
  final EventJob inverseJob;

  /// The result returned when [originalJob] was executed.
  ///
  /// Stored for potential use in:
  /// - Creating updated inverse jobs during coalescing
  /// - Debugging and logging
  /// - Custom undo logic that needs the original result
  final dynamic originalResult;

  /// When this operation was executed.
  ///
  /// Used for:
  /// - Coalescing check (actions within duration window)
  /// - Time-travel UI (undoToTimestamp)
  /// - History display (showing when actions occurred)
  final DateTime timestamp;

  /// Human-readable description for UI display.
  ///
  /// Derived from `ReversibleJob.undoDescription` when the entry is created.
  /// May be `null` if the job doesn't provide a description.
  ///
  /// Examples:
  /// - "Create chamber 'Savings'"
  /// - "Delete asset 'Bitcoin'"
  /// - "Transfer $100 from A to B"
  final String? description;

  /// Optional source identifier for the originating context.
  ///
  /// Useful in Global Undo mode where multiple orchestrators share
  /// a single undo stack. Allows filtering or grouping by source.
  ///
  /// Examples:
  /// - "NestOrchestrator"
  /// - "AssetOrchestrator"
  /// - "settings_screen"
  final String? sourceId;

  /// Creates a new UndoEntry.
  const UndoEntry({
    required this.originalJob,
    required this.inverseJob,
    required this.originalResult,
    required this.timestamp,
    this.description,
    this.sourceId,
  });

  /// Creates a copy with updated fields.
  ///
  /// Primarily used for coalescing, where we keep the original job
  /// but update the inverse job and timestamp:
  ///
  /// ```dart
  /// // Coalescing: update inverse but keep original
  /// final coalesced = entry.copyWith(
  ///   inverseJob: newInverseJob,
  ///   originalResult: newResult,
  ///   timestamp: DateTime.now(),
  /// );
  /// ```
  UndoEntry copyWith({
    EventJob? originalJob,
    EventJob? inverseJob,
    dynamic originalResult,
    DateTime? timestamp,
    String? description,
    String? sourceId,
  }) {
    return UndoEntry(
      originalJob: originalJob ?? this.originalJob,
      inverseJob: inverseJob ?? this.inverseJob,
      originalResult: originalResult ?? this.originalResult,
      timestamp: timestamp ?? this.timestamp,
      description: description ?? this.description,
      sourceId: sourceId ?? this.sourceId,
    );
  }

  @override
  String toString() =>
      'UndoEntry(job: ${originalJob.runtimeType}, desc: $description, '
      'source: $sourceId, time: $timestamp)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UndoEntry &&
        other.originalJob.id == originalJob.id &&
        other.inverseJob.id == inverseJob.id &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode => Object.hash(originalJob.id, inverseJob.id, timestamp);
}

/// Result of a multi-step undo operation (undoTo).
///
/// Contains information about how many steps were undone,
/// any errors encountered, and entries that were successfully undone.
@immutable
class UndoToResult {
  /// Number of entries successfully undone.
  final int undoneCount;

  /// Total number of entries that were attempted.
  final int attemptedCount;

  /// Target index that was requested.
  final int targetIndex;

  /// Final index after the operation.
  final int finalIndex;

  /// List of entries that were successfully undone.
  final List<UndoEntry> undoneEntries;

  /// Error encountered during the operation (if any).
  final Object? error;

  /// Stack trace of the error (if any).
  final StackTrace? stackTrace;

  /// Entry that failed (if any).
  final UndoEntry? failedEntry;

  const UndoToResult({
    required this.undoneCount,
    required this.attemptedCount,
    required this.targetIndex,
    required this.finalIndex,
    required this.undoneEntries,
    this.error,
    this.stackTrace,
    this.failedEntry,
  });

  /// Whether all requested undos completed successfully.
  bool get isFullySuccessful => undoneCount == attemptedCount && error == null;

  /// Whether at least one undo completed successfully.
  bool get isPartiallySuccessful => undoneCount > 0;

  /// Whether the operation completely failed.
  bool get isFailure => undoneCount == 0 && error != null;

  @override
  String toString() =>
      'UndoToResult(undone: $undoneCount/$attemptedCount, '
      'target: $targetIndex → final: $finalIndex, '
      'success: $isFullySuccessful)';
}

/// History entry for UI display purposes.
///
/// A lighter-weight representation of [UndoEntry] for rendering
/// in history panels, excluding the heavy job objects.
@immutable
class UndoHistoryEntry {
  /// Index in the history stack.
  final int index;

  /// Human-readable description.
  final String? description;

  /// When the action was performed.
  final DateTime timestamp;

  /// Type name of the original job.
  final String jobTypeName;

  /// Whether this entry is before the current index (can be redone).
  final bool isUndone;

  /// Source identifier.
  final String? sourceId;

  const UndoHistoryEntry({
    required this.index,
    required this.description,
    required this.timestamp,
    required this.jobTypeName,
    required this.isUndone,
    this.sourceId,
  });

  /// Creates a history entry from an [UndoEntry].
  factory UndoHistoryEntry.fromEntry(
    UndoEntry entry, {
    required int index,
    required bool isUndone,
  }) {
    return UndoHistoryEntry(
      index: index,
      description: entry.description,
      timestamp: entry.timestamp,
      jobTypeName: entry.originalJob.runtimeType.toString(),
      isUndone: isUndone,
      sourceId: entry.sourceId,
    );
  }

  @override
  String toString() =>
      'UndoHistoryEntry(#$index: $description, undone: $isUndone)';
}
