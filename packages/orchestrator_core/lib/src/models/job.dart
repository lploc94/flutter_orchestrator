import 'dart:math';
import 'package:meta/meta.dart';
import '../utils/cancellation_token.dart';
import '../utils/retry_policy.dart';
import '../infra/signal_bus.dart';
import 'data_source.dart';
import 'data_strategy.dart';
import 'event.dart';

/// Random generator for unique job IDs.
final Random _jobIdRandom = Random();

/// Helper to generate unique job IDs.
///
/// Uses microseconds timestamp combined with cryptographic-quality random
/// to ensure uniqueness even when creating multiple jobs in the same millisecond.
String generateJobId([String? prefix]) {
  final timestamp = DateTime.now().microsecondsSinceEpoch;
  // Generate a random 24-bit number (0-16777215) and convert to hex
  final randomPart =
      _jobIdRandom.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
  return '${prefix ?? 'job'}-$timestamp-$randomPart';
}

/// A Job that emits a domain event upon completion.
///
/// This is the **only** job class in the framework. Every job must:
/// 1. Define the result type [TResult]
/// 2. Define the domain event type [TEvent]
/// 3. Implement [createEventTyped] to create the event from the result
///
/// ## Type Parameters
///
/// - [TResult]: The data type returned by the worker (Executor)
/// - [TEvent]: The domain event type to emit after successful completion
///
/// ## Usage
///
/// ```dart
/// // Define your domain event
/// class UsersLoadedEvent extends BaseEvent {
///   final List<User> users;
///   UsersLoadedEvent(super.correlationId, this.users);
/// }
///
/// // Define your job
/// class LoadUsersJob extends EventJob<List<User>, UsersLoadedEvent> {
///   LoadUsersJob() : super(id: generateJobId('load_users'));
///
///   @override
///   UsersLoadedEvent createEventTyped(List<User> result) {
///     return UsersLoadedEvent(id, result);
///   }
/// }
///
/// // For jobs with no meaningful result, use void
/// class SeedCompletedEvent extends BaseEvent {
///   SeedCompletedEvent(super.correlationId);
/// }
///
/// class SeedJob extends EventJob<void, SeedCompletedEvent> {
///   SeedJob() : super(id: generateJobId('seed'));
///
///   @override
///   SeedCompletedEvent createEventTyped(void _) => SeedCompletedEvent(id);
/// }
/// ```
///
/// ## Cache Behavior
///
/// EventJob supports built-in caching via [cacheKey], [cacheTtl], and [revalidate]:
///
/// - **No caching** (default): `cacheKey` returns null
/// - **Cache-First**: Set `cacheKey`, `revalidate = false`
/// - **SWR (Stale-While-Revalidate)**: Set `cacheKey`, `revalidate = true`
///
/// ## Error Handling
///
/// Errors are NOT emitted as events. Use [JobHandle.future] to catch errors:
///
/// ```dart
/// final handle = dispatch<User>(CreateUserJob(name));
/// try {
///   final result = await handle.future;
///   // success
/// } catch (e) {
///   // error
/// }
/// ```
abstract class EventJob<TResult, TEvent extends BaseEvent> {
  /// Unique ID to track this specific job instance (Correlation ID).
  final String id;

  /// Optional timeout for this job.
  final Duration? timeout;

  /// Optional cancellation token.
  final CancellationToken? cancellationToken;

  /// Optional retry policy.
  final RetryPolicy? retryPolicy;

  /// Optional metadata.
  final Map<String, dynamic>? metadata;

  /// Context: The bus instance this job belongs to.
  /// Set by Orchestrator before dispatching.
  SignalBus? bus;

  /// Optional data strategy (Cache, Placeholder, etc).
  final DataStrategy? strategy;

  /// Internal: Data source context for current event creation.
  /// Set by framework before calling [createEvent].
  /// @internal - Do not set manually.
  DataSource? _dataSourceContext;

  /// Get the data source for current execution.
  ///
  /// Use this in [createEventTyped] to include data source in your event:
  /// ```dart
  /// @override
  /// PostLikedEvent createEventTyped(bool result) {
  ///   return PostLikedEvent(id, postId, result, dataSource);
  /// }
  /// ```
  @protected
  DataSource get dataSource => _dataSourceContext ?? DataSource.fresh;

  EventJob({
    String? id,
    this.timeout,
    this.cancellationToken,
    this.retryPolicy,
    this.metadata,
    this.strategy,
  }) : id = id ?? generateJobId();

  /// Creates the domain event from the worker result.
  ///
  /// This method handles Dart's type erasure at runtime by accepting
  /// `dynamic` and casting to [TResult] internally.
  ///
  /// The optional [source] parameter sets the data source context,
  /// accessible via the [dataSource] getter in [createEventTyped].
  ///
  /// **Do not override this method.** Override [createEventTyped] instead.
  TEvent createEvent(dynamic result, [DataSource? source]) {
    _dataSourceContext = source;
    try {
      return createEventTyped(result as TResult);
    } finally {
      _dataSourceContext = null;
    }
  }

  /// Override this method to create your domain event from the typed result.
  ///
  /// The [correlationId] of the event should be set to [id] to maintain
  /// the correlation chain.
  ///
  /// ```dart
  /// @override
  /// UsersLoadedEvent createEventTyped(List<User> result) {
  ///   return UsersLoadedEvent(id, result);
  /// }
  /// ```
  @protected
  TEvent createEventTyped(TResult result);

  /// Cache key for this job's result.
  ///
  /// Return `null` (default) to disable caching.
  /// Return a unique string to enable caching.
  ///
  /// **Best Practice**: Include discriminating parameters in the key:
  /// ```dart
  /// @override
  /// String? get cacheKey => 'users_dept_$departmentId';
  /// ```
  String? get cacheKey => null;

  /// Time-to-live for cached data.
  ///
  /// Return `null` for indefinite caching (until manually invalidated).
  Duration? get cacheTtl => null;

  /// Whether to fetch fresh data after returning cached data.
  ///
  /// - `false` (default): Cache-First pattern - return cached data and stop
  /// - `true`: SWR pattern - return cached data, then fetch fresh in background
  ///
  /// When `true`, the JobHandle completes immediately with cached data,
  /// and fresh data will be emitted as a new domain event.
  bool get revalidate => false;

  /// Optional: Create a domain event when offline sync fails permanently.
  ///
  /// Override this to handle rollback of optimistic updates when a
  /// [NetworkAction] job fails after all retries (poison pill).
  ///
  /// [error] - The error that caused the final sync failure
  /// [lastOptimisticResult] - The optimistic result returned when queued
  ///                          (may be null if not stored/available)
  ///
  /// Returns the domain event to emit, or `null` (default) to skip
  /// domain event emission. The framework will still emit
  /// [NetworkSyncFailureEvent] regardless.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// PostLikedEvent? createFailureEvent(Object error, bool? lastOptimistic) {
  ///   // Revert to unlike state
  ///   return PostLikedEvent(id, postId, false, DataSource.failed);
  /// }
  /// ```
  TEvent? createFailureEvent(Object error, TResult? lastOptimisticResult) =>
      null;

  @override
  String toString() => '$runtimeType(id: $id)';
}
