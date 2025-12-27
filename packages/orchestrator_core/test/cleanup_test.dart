import 'package:orchestrator_core/orchestrator_core.dart';
import 'package:test/test.dart';

void main() {
  group('InMemoryCacheProvider Enhanced Features', () {
    test('Stats return correct initial values', () {
      final cache = InMemoryCacheProvider(maxEntries: 100);
      final stats = cache.getStats();

      expect(stats.entryCount, 0);
      expect(stats.maxEntries, 100);
      expect(stats.usageRatio, 0.0);
    });

    test('LRU Eviction works when maxEntries exceeded', () async {
      // Create small cache of size 3
      final cache = InMemoryCacheProvider(maxEntries: 3);

      await cache.write('k1', 1);
      await cache.write('k2', 2);
      await cache.write('k3', 3);

      expect((cache.getStats()).entryCount, 3);

      // Access k1 to make it "recently used"
      await cache.read('k1');

      // Add k4 -> should evict oldest accessed (which is k2 now, since k1 was touched)
      // k1: touched just now
      // k2: untouched since creation
      // k3: untouched since creation (but created after k2)
      // Wait a bit to ensure timestamps differ if needed (usually microsecond precision is enough)
      await Future.delayed(Duration(milliseconds: 10));

      await cache.write('k4', 4);

      final stats = cache.getStats();
      expect(stats.entryCount, 3);

      // Verify content
      expect(await cache.read('k1'), 1); // Should still exist
      expect(await cache.read('k2'), null); // Should be evicted
      expect(await cache.read('k3'), 3);
      expect(await cache.read('k4'), 4);
    });

    test('evictExpired removes only expired entries', () async {
      final cache = InMemoryCacheProvider();

      // Expired entry (TTL 1ms)
      await cache.write('expired', 'val', ttl: Duration(milliseconds: 1));

      // Valid entry
      await cache.write('valid', 'val', ttl: Duration(hours: 1));

      // Wait for expiration
      await Future.delayed(Duration(milliseconds: 10));

      final statsBefore = cache.getStats();
      expect(statsBefore.expiredCount, 1);
      expect(statsBefore.entryCount, 2);

      // Run proactive eviction
      final count = await cache.evictExpired();

      expect(count, 1);

      final statsAfter = cache.getStats();
      expect(statsAfter.entryCount, 1);
      expect(statsAfter.expiredCount, 0);

      expect(await cache.read('expired'), null);
      expect(await cache.read('valid'), 'val');
    });
  });

  group('CleanupPolicy', () {
    test('Presets have correct values', () {
      expect(CleanupPolicy.aggressive.autoCleanup, true);
      expect(CleanupPolicy.aggressive.maxCacheEntries, 100);

      expect(CleanupPolicy.conservative.maxCacheEntries, 5000);
      expect(CleanupPolicy.manual.autoCleanup, false);
    });
  });
}
