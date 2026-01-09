/// Indicates the source of data in an event or result.
///
/// This enum helps consumers understand where data originated,
/// which can be useful for:
/// - Showing staleness indicators in UI
/// - Deciding whether to trigger revalidation
/// - Logging and debugging data flow
///
/// ## Usage in Domain Events
///
/// ```dart
/// class HopesLoadedEvent extends BaseEvent {
///   final List<Hope> hopes;
///   final DataSource source;
///
///   HopesLoadedEvent(super.correlationId, this.hopes, {this.source = DataSource.fresh});
/// }
/// ```
enum DataSource {
  /// Data fetched directly from the source (API, database, etc.)
  fresh,

  /// Data retrieved from cache.
  cached,

  /// Data created optimistically while offline.
  /// The real request will be synced when connectivity restores.
  optimistic,

  /// Data from a permanently failed sync operation.
  /// Used when offline sync fails after all retries (poison pill).
  /// UI should rollback optimistic state when receiving this.
  failed,
}
