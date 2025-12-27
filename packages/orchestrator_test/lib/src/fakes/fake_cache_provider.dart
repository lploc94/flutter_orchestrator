import 'package:orchestrator_core/orchestrator_core.dart';

/// A fake [CacheProvider] for testing.
///
/// Stores cache entries in memory without expiration logic.
/// Useful for testing cache-dependent code in isolation.
///
/// ## Example
///
/// ```dart
/// final cache = FakeCacheProvider();
///
/// // Use in your code
/// await cache.write('key', 'value');
/// expect(await cache.read('key'), equals('value'));
///
/// // Verify cache contents
/// expect(cache.entries, {'key': 'value'});
/// ```
class FakeCacheProvider implements CacheProvider {
  /// Creates a [FakeCacheProvider].
  ///
  /// If [trackTtl] is `true`, entries will expire based on their TTL.
  FakeCacheProvider({this.trackTtl = false});

  final Map<String, dynamic> _cache = {};
  final Map<String, DateTime> _expirations = {};

  /// Whether to track TTL (time-to-live) for entries.
  ///
  /// If `true`, entries will be removed after their TTL expires
  /// when accessed via [read].
  final bool trackTtl;

  @override
  Future<void> write(String key, dynamic value, {Duration? ttl}) async {
    _cache[key] = value;
    if (trackTtl && ttl != null) {
      _expirations[key] = DateTime.now().add(ttl);
    }
  }

  @override
  Future<dynamic> read(String key) async {
    if (trackTtl && _expirations.containsKey(key)) {
      if (DateTime.now().isAfter(_expirations[key]!)) {
        await delete(key);
        return null;
      }
    }
    return _cache[key];
  }

  @override
  Future<void> delete(String key) async {
    _cache.remove(key);
    _expirations.remove(key);
  }

  @override
  Future<void> deleteMatching(bool Function(String key) predicate) async {
    final keysToRemove = _cache.keys.where(predicate).toList();
    for (final key in keysToRemove) {
      _cache.remove(key);
      _expirations.remove(key);
    }
  }

  @override
  Future<void> clear() async {
    _cache.clear();
    _expirations.clear();
  }

  /// Get all cached entries (for test verification).
  ///
  /// Returns an unmodifiable view of the cache.
  Map<String, dynamic> get entries => Map.unmodifiable(_cache);

  /// Get the number of entries in the cache.
  int get length => _cache.length;

  /// Check if the cache is empty.
  bool get isEmpty => _cache.isEmpty;

  /// Check if the cache is not empty.
  bool get isNotEmpty => _cache.isNotEmpty;

  /// Get all keys in the cache.
  Iterable<String> get keys => _cache.keys;

  /// Check if a key exists in the cache.
  bool containsKey(String key) => _cache.containsKey(key);
}
