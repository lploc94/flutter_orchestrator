import 'cache_provider.dart';

/// Internal cache entry with expiry and access tracking for LRU.
class _CacheEntry {
  final dynamic value;
  final DateTime? expiry;
  DateTime lastAccess;

  _CacheEntry(this.value, this.expiry) : lastAccess = DateTime.now();

  bool get isExpired => expiry != null && DateTime.now().isAfter(expiry!);

  /// Update last access time (for LRU tracking).
  void touch() {
    lastAccess = DateTime.now();
  }
}

/// Statistics about current cache state.
class CacheStats {
  /// Current number of entries in the cache.
  final int entryCount;

  /// Maximum allowed entries (0 = unlimited).
  final int maxEntries;

  /// Number of expired entries (not yet evicted).
  final int expiredCount;

  const CacheStats({
    required this.entryCount,
    required this.maxEntries,
    required this.expiredCount,
  });

  /// Usage ratio (0.0 to 1.0). Returns 0 if unlimited.
  double get usageRatio => maxEntries > 0 ? entryCount / maxEntries : 0.0;

  @override
  String toString() =>
      'CacheStats(entries: $entryCount/$maxEntries, expired: $expiredCount)';
}

/// Enhanced In-Memory implementation of CacheProvider.
///
/// Features:
/// - LRU (Least Recently Used) eviction when maxEntries is exceeded.
/// - TTL (Time-To-Live) support with lazy expiration.
/// - Proactive eviction via [evictExpired].
/// - Statistics via [getStats].
///
/// Data is lost when the app restarts.
class InMemoryCacheProvider implements CacheProvider {
  /// Maximum number of entries. 0 = unlimited.
  int maxEntries;

  /// Default TTL for entries without explicit TTL.
  final Duration? defaultTtl;

  final Map<String, _CacheEntry> _store = {};

  /// Creates an InMemoryCacheProvider.
  ///
  /// [maxEntries]: Maximum entries before LRU eviction (0 = unlimited).
  /// [defaultTtl]: Default TTL applied when [write] is called without TTL.
  InMemoryCacheProvider({
    this.maxEntries = 1000,
    this.defaultTtl,
  });

  @override
  Future<void> write(String key, dynamic value, {Duration? ttl}) async {
    // Use provided TTL, fallback to default, or null (no expiry)
    final effectiveTtl = ttl ?? defaultTtl;
    final expiry =
        effectiveTtl != null ? DateTime.now().add(effectiveTtl) : null;

    // Evict if at capacity (and not just updating existing key)
    if (maxEntries > 0 &&
        _store.length >= maxEntries &&
        !_store.containsKey(key)) {
      _evictLRU();
    }

    _store[key] = _CacheEntry(value, expiry);
  }

  @override
  Future<dynamic> read(String key) async {
    final entry = _store[key];
    if (entry == null) return null;

    if (entry.isExpired) {
      _store.remove(key);
      return null;
    }

    // Update access time for LRU
    entry.touch();
    return entry.value;
  }

  @override
  Future<void> delete(String key) async {
    _store.remove(key);
  }

  @override
  Future<void> deleteMatching(bool Function(String key) predicate) async {
    _store.removeWhere((key, value) => predicate(key));
  }

  @override
  Future<void> clear() async {
    _store.clear();
  }

  // --- Enhanced Methods ---

  /// Proactively evict all expired entries.
  ///
  /// Returns the number of entries removed.
  /// Call this periodically from a cleanup service.
  Future<int> evictExpired() async {
    final expiredKeys = _store.entries
        .where((e) => e.value.isExpired)
        .map((e) => e.key)
        .toList();

    for (final key in expiredKeys) {
      _store.remove(key);
    }

    return expiredKeys.length;
  }

  /// Get current cache statistics.
  CacheStats getStats() {
    final expiredCount = _store.values.where((e) => e.isExpired).length;
    return CacheStats(
      entryCount: _store.length,
      maxEntries: maxEntries,
      expiredCount: expiredCount,
    );
  }

  /// Evict the least recently used entry.
  void _evictLRU() {
    if (_store.isEmpty) return;

    // Find entry with oldest lastAccess
    String? oldestKey;
    DateTime? oldestTime;

    for (final entry in _store.entries) {
      if (oldestTime == null || entry.value.lastAccess.isBefore(oldestTime)) {
        oldestTime = entry.value.lastAccess;
        oldestKey = entry.key;
      }
    }

    if (oldestKey != null) {
      _store.remove(oldestKey);
    }
  }
}
