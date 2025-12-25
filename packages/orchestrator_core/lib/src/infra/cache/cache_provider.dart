/// Interface for low-level cache operations.
/// Implementations can be In-Memory, Hive, SharedPrefs, SQLite, etc.
abstract class CacheProvider {
  /// Write data to cache.
  Future<void> write(String key, dynamic value, {Duration? ttl});

  /// Read data from cache. Returns null if not found or expired.
  Future<dynamic> read(String key);

  /// Delete specific key.
  Future<void> delete(String key);

  /// Delete keys matching the predicate.
  /// Useful for prefix-based invalidation.
  Future<void> deleteMatching(bool Function(String key) predicate);

  /// Clear all cache.
  Future<void> clear();
}
