import 'package:meta/meta.dart';
import '../utils/cancellation_token.dart';
import '../utils/retry_policy.dart';

/// Base class for all Jobs (Commands/Intents) in the system.
/// A Job represents a "Packet of Work" sent from Orchestrator to Executor.
@immutable
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

  const BaseJob({
    required this.id,
    this.timeout,
    this.cancellationToken,
    this.retryPolicy,
    this.metadata,
  });

  @override
  String toString() => '$runtimeType(id: $id)';
}

/// Helper to generate unique job IDs.
String generateJobId([String? prefix]) {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final random = timestamp.hashCode.abs() % 10000;
  return '${prefix ?? 'job'}-$timestamp-$random';
}
