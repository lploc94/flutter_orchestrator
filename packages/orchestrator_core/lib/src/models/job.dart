import 'dart:math';
import 'package:meta/meta.dart';
import '../utils/cancellation_token.dart';
import '../utils/retry_policy.dart';
import '../infra/signal_bus.dart';
import 'data_strategy.dart';
import 'event.dart';

/// Random generator for unique job IDs.
final Random _jobIdRandom = Random();

/// Base class for all Jobs (Commands/Intents) in the system.
/// A Job represents a "Packet of Work" sent from Orchestrator to Executor.
abstract class BaseJob {
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

  BaseJob({
    required this.id,
    this.timeout,
    this.cancellationToken,
    this.retryPolicy,
    this.metadata,
    this.strategy,
  });

  @override
  String toString() => '$runtimeType(id: $id)';
}

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
/// This is the recommended base class for jobs that need to communicate
/// their results to other parts of the system via domain events.
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
///   UsersLoadedEvent({required String correlationId, required this.users})
///       : super(correlationId);
/// }
///
/// // Define your job
/// class LoadUsersJob extends EventJob<List<User>, UsersLoadedEvent> {
///   LoadUsersJob() : super(id: generateJobId('load_users'));
///
///   @override
///   UsersLoadedEvent createEventTyped(List<User> result) {
///     return UsersLoadedEvent(correlationId: id, users: result);
///   }
///
///   // Optional: Enable caching
///   @override
///   String? get cacheKey => 'users_list';
///
///   @override
///   Duration? get cacheTtl => Duration(minutes: 5);
///
///   @override
///   bool get revalidate => true; // SWR pattern
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
/// When cached data is returned, the event's `correlationId` will be the
/// current job's ID, not the original job that cached the data.
///
/// ## Design Rationale
///
/// This pattern combines CQRS (Job = Command) with Event Sourcing principles:
/// - Jobs define their expected output type at compile time
/// - Events are domain-specific, not framework-specific
/// - Caching is transparent to the consumer
abstract class EventJob<TResult, TEvent extends BaseEvent> extends BaseJob {
  EventJob({
    String? id,
    super.timeout,
    super.cancellationToken,
    super.retryPolicy,
    super.metadata,
    super.strategy,
  }) : super(id: id ?? generateJobId());

  /// Creates the domain event from the worker result.
  ///
  /// This method handles Dart's type erasure at runtime by accepting
  /// `dynamic` and casting to [TResult] internally.
  ///
  /// **Do not override this method.** Override [createEventTyped] instead.
  TEvent createEvent(dynamic result) => createEventTyped(result as TResult);

  /// Override this method to create your domain event from the typed result.
  ///
  /// The [correlationId] of the event should be set to [id] to maintain
  /// the correlation chain.
  ///
  /// ```dart
  /// @override
  /// UsersLoadedEvent createEventTyped(List<User> result) {
  ///   return UsersLoadedEvent(correlationId: id, users: result);
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
}

