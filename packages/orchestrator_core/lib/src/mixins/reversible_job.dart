import '../models/job.dart';

/// Mixin that enables undo/redo capabilities for EventJobs.
///
/// Jobs implementing this mixin can be tracked by [UndoStackManager]
/// and support automatic inverse operation generation.
///
/// ## Design Philosophy
///
/// This mixin follows the **Inverse Jobs Pattern** (Command Pattern):
/// - Each job knows how to create its inverse operation
/// - Undo dispatches the inverse job
/// - Redo re-dispatches the original job
///
/// This approach has advantages over state snapshots:
/// - **Low memory**: Only stores job parameters, not full state clones
/// - **Real sync**: Re-executes business logic, maintaining DB consistency
/// - **Reusability**: Leverages existing executor infrastructure
///
/// ## Usage
///
/// ```dart
/// class CreateChamberJob extends EventJob<Chamber, ChamberCreatedEvent>
///     with ReversibleJob {
///   final String name;
///   CreateChamberJob(this.name);
///
///   @override
///   ChamberCreatedEvent createEventTyped(Chamber result) =>
///       ChamberCreatedEvent(id, result);
///
///   @override
///   EventJob createInverse(dynamic result) {
///     final chamber = result as Chamber;
///     return DeleteChamberJob(chamber.id);
///   }
///
///   @override
///   String? get undoDescription => 'Create chamber: $name';
/// }
/// ```
///
/// ## Inverse Job Patterns
///
/// | Original Operation | Inverse Operation |
/// |--------------------|-------------------|
/// | Create entity      | Delete entity (by ID from result) |
/// | Delete entity      | Create entity (restore from cached data) |
/// | Update entity      | Update entity (with previous values) |
/// | Move A→B           | Move B→A |
///
/// ## Composition
///
/// This mixin can be combined with other mixins:
///
/// ```dart
/// // Reversible + Network (offline-capable)
/// class SyncableCreateJob extends EventJob<Item, ItemCreatedEvent>
///     with ReversibleJob, NetworkAction {
///   // ...
/// }
/// ```
mixin ReversibleJob on EventJob {
  /// Creates the inverse job that will undo this operation.
  ///
  /// The [result] parameter contains the data returned by executing this job.
  /// Use it to extract IDs, previous values, or other data needed for reversal.
  ///
  /// ## Implementation Guidelines
  ///
  /// 1. **Create → Delete**: Extract ID from result
  ///    ```dart
  ///    @override
  ///    EventJob createInverse(dynamic result) {
  ///      final entity = result as MyEntity;
  ///      return DeleteMyEntityJob(entity.id);
  ///    }
  ///    ```
  ///
  /// 2. **Delete → Restore**: Cache deleted data in job for restoration
  ///    ```dart
  ///    class DeleteChamberJob extends EventJob<Chamber, ChamberDeletedEvent>
  ///        with ReversibleJob {
  ///      final String chamberId;
  ///      Chamber? _deletedData; // Cache for undo
  ///
  ///      @override
  ///      EventJob createInverse(dynamic result) {
  ///        // result contains the deleted chamber data
  ///        final deleted = result as Chamber;
  ///        return RestoreChamberJob(deleted);
  ///      }
  ///    }
  ///    ```
  ///
  /// 3. **Update → Restore Previous**: Store old values
  ///    ```dart
  ///    class UpdateNameJob extends EventJob<void, NameUpdatedEvent>
  ///        with ReversibleJob {
  ///      final String id;
  ///      final String newName;
  ///      final String previousName; // Required for undo
  ///
  ///      @override
  ///      EventJob createInverse(dynamic _) {
  ///        return UpdateNameJob(
  ///          id: id,
  ///          newName: previousName,
  ///          previousName: newName,
  ///        );
  ///      }
  ///    }
  ///    ```
  EventJob createInverse(dynamic result);

  /// Optional human-readable description for UI display.
  ///
  /// This description appears in:
  /// - Undo/Redo confirmation dialogs
  /// - History panel/timeline
  /// - Snackbar messages ("Undone: Create chamber 'Savings'")
  ///
  /// Returns `null` by default. Override to provide context:
  ///
  /// ```dart
  /// @override
  /// String? get undoDescription => 'Create chamber "$name"';
  /// ```
  ///
  /// ## Best Practices
  ///
  /// - Keep descriptions short and action-oriented
  /// - Include key identifiers (name, amount, etc.)
  /// - Use present tense ("Create...", "Delete...", "Move...")
  String? get undoDescription => null;
}
