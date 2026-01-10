import '../models/event.dart';
import '../models/job.dart';

/// Mixin that enables undo/redo capabilities for EventJobs.
///
/// Jobs implementing this mixin can be tracked by [UndoStackManager]
/// and support automatic inverse operation generation.
///
/// ## Type Parameters
///
/// - [TResult]: The result type of the job (same as EventJob's TResult)
/// - [TEvent]: The event type emitted by the job (same as EventJob's TEvent)
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
///     with ReversibleJob<Chamber, ChamberCreatedEvent> {
///   final String name;
///   CreateChamberJob(this.name);
///
///   @override
///   ChamberCreatedEvent createEventTyped(Chamber result) =>
///       ChamberCreatedEvent(id, result);
///
///   @override
///   EventJob createInverse(Chamber result) {  // Typed!
///     return DeleteChamberJob(result.id);
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
///     with ReversibleJob<Item, ItemCreatedEvent>, NetworkAction {
///   // ...
/// }
/// ```
mixin ReversibleJob<TResult, TEvent extends BaseEvent>
    on EventJob<TResult, TEvent> {
  /// Creates the inverse job that will undo this operation.
  ///
  /// The [result] parameter contains the typed data returned by executing
  /// this job. Use it to extract IDs, previous values, or other data needed
  /// for reversal.
  ///
  /// ## Implementation Guidelines
  ///
  /// 1. **Create → Delete**: Extract ID from result
  ///    ```dart
  ///    @override
  ///    EventJob createInverse(MyEntity result) {
  ///      return DeleteMyEntityJob(result.id);
  ///    }
  ///    ```
  ///
  /// 2. **Delete → Restore**: Cache deleted data in job for restoration
  ///    ```dart
  ///    class DeleteChamberJob extends EventJob<Chamber, ChamberDeletedEvent>
  ///        with ReversibleJob<Chamber, ChamberDeletedEvent> {
  ///      final String chamberId;
  ///
  ///      @override
  ///      EventJob createInverse(Chamber result) {
  ///        // result contains the deleted chamber data
  ///        return RestoreChamberJob(result);
  ///      }
  ///    }
  ///    ```
  ///
  /// 3. **Update → Restore Previous**: Store old values
  ///    ```dart
  ///    class UpdateNameJob extends EventJob<OldNewPair, NameUpdatedEvent>
  ///        with ReversibleJob<OldNewPair, NameUpdatedEvent> {
  ///      final String id;
  ///      final String newName;
  ///
  ///      @override
  ///      EventJob createInverse(OldNewPair result) {
  ///        return UpdateNameJob(
  ///          id: id,
  ///          newName: result.oldName,  // Swap back
  ///        );
  ///      }
  ///    }
  ///    ```
  EventJob createInverse(TResult result);

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
