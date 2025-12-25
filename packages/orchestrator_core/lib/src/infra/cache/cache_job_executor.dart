import '../../base/base_executor.dart';
import '../../jobs/invalidate_cache_job.dart';

/// System executor to handle cache management jobs.
///
/// Handles [InvalidateCacheJob] to clear cache entries by:
/// - Specific key
/// - Prefix matching
/// - Custom predicate
///
/// Note: If multiple conditions are provided (e.g., both key and prefix),
/// ALL matching entries will be deleted. This is intentional to allow
/// flexible cache invalidation patterns.
class CacheJobExecutor extends BaseExecutor<InvalidateCacheJob> {
  @override
  Future<dynamic> process(InvalidateCacheJob job) async {
    final provider = cacheProvider;

    // Delete by specific key first
    if (job.key != null) {
      await provider.delete(job.key!);
    }

    // Then apply predicate or prefix (mutually exclusive in typical usage)
    if (job.predicate != null) {
      await provider.deleteMatching(job.predicate!);
      // Can't track count for predicate without additional provider support
    } else if (job.prefix != null) {
      // Default predicate for prefix
      await provider.deleteMatching((key) => key.startsWith(job.prefix!));
    }

    return {
      'success': true,
      'key': job.key,
      'prefix': job.prefix,
      'hasCustomPredicate': job.predicate != null,
    };
  }
}
