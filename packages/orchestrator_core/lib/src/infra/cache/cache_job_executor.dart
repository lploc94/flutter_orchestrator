import '../../base/base_executor.dart';
import '../../jobs/invalidate_cache_job.dart';

/// System executor to handle cache management jobs.
class CacheJobExecutor extends BaseExecutor<InvalidateCacheJob> {
  @override
  Future<dynamic> process(InvalidateCacheJob job) async {
    final provider = cacheProvider;

    if (job.key != null) {
      await provider.delete(job.key!);
    }

    if (job.predicate != null) {
      await provider.deleteMatching(job.predicate!);
    } else if (job.prefix != null) {
      // Default predicate for prefix
      await provider.deleteMatching((key) => key.startsWith(job.prefix!));
    }

    return true;
  }
}
