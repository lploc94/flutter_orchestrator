import '../models/job.dart';
import '../models/event.dart';

/// System Job to invalidate cache.
///
/// Usage:
/// - Invalidate specific key: `InvalidateCacheJob(key: 'user_123')`
/// - Invalidate by prefix: `InvalidateCacheJob(prefix: 'product_')`
/// - Invalidate custom: `InvalidateCacheJob(predicate: (k) => k.contains('deleted'))`

/// Event emitted when cache invalidation completes.
class CacheInvalidatedEvent extends BaseEvent {
  final String? key;
  final String? prefix;
  final bool usedPredicate;

  CacheInvalidatedEvent(
    super.correlationId, {
    this.key,
    this.prefix,
    this.usedPredicate = false,
  });
}

class InvalidateCacheJob extends EventJob<void, CacheInvalidatedEvent> {
  final String? key;
  final String? prefix;
  final bool Function(String key)? predicate;

  InvalidateCacheJob({
    this.key,
    this.prefix,
    this.predicate,
  }) : assert(
          key != null || prefix != null || predicate != null,
          'Must provide at least one condition: key, prefix, or predicate',
        );

  @override
  CacheInvalidatedEvent createEventTyped(void _) => CacheInvalidatedEvent(
        id,
        key: key,
        prefix: prefix,
        usedPredicate: predicate != null,
      );
}
