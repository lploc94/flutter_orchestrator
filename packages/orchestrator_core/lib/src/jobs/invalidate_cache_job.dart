import '../models/job.dart';

/// System Job to invalidate cache.
///
/// Usage:
/// - Invalidate specific key: `InvalidateCacheJob(key: 'user_123')`
/// - Invalidate by prefix: `InvalidateCacheJob(prefix: 'product_')`
/// - Invalidate custom: `InvalidateCacheJob(predicate: (k) => k.contains('deleted'))`
class InvalidateCacheJob extends BaseJob {
  final String? key;
  final String? prefix;
  final bool Function(String key)? predicate;

  InvalidateCacheJob({
    this.key,
    this.prefix,
    this.predicate,
    String? id, // Optional custom ID
  })  : assert(
          key != null || prefix != null || predicate != null,
          'Must provide at least one condition: key, prefix, or predicate',
        ),
        super(id: id ?? generateJobId('invalidate_cache'));
}
