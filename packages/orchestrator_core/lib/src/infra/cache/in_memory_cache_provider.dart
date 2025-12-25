import 'cache_provider.dart';

class _CacheEntry {
  final dynamic value;
  final DateTime? expiry;

  _CacheEntry(this.value, this.expiry);

  bool get isExpired => expiry != null && DateTime.now().isAfter(expiry!);
}

/// Simple In-Memory implementation of CacheProvider.
/// Data is lost when the app restarts.
class InMemoryCacheProvider implements CacheProvider {
  final Map<String, _CacheEntry> _store = {};

  @override
  Future<void> write(String key, value, {Duration? ttl}) async {
    final expiry = ttl != null ? DateTime.now().add(ttl) : null;
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
}
