import 'package:meta/meta.dart';

/// Define how data should be fetched and cached.
@immutable
class DataStrategy {
  /// Optional placeholder data to emit immediately while loading.
  /// Useful for Skeleton UI or optimistic updates.
  final dynamic placeholder;

  /// Cache configuration. If null, caching is disabled.
  final CachePolicy? cachePolicy;

  const DataStrategy({
    this.placeholder,
    this.cachePolicy,
  });
}

/// Helper to configure caching behavior.
@immutable
class CachePolicy {
  /// Unique key to identify the data in cache.
  final String key;

  /// Time-to-live. If null, persists indefinitely (or until manually cleared).
  final Duration? ttl;

  /// If true (SWR pattern): The executor will emit cached data (if hit),
  /// THEN continue to fetch fresh data from the worker.
  ///
  /// If false (Cache-First pattern): The executor will emit cached data (if hit)
  /// AND STOP execution immediately.
  final bool revalidate;

  /// If true, we SKIP reading from cache completely (Network First / Force Refresh).
  /// This is useful for "Pull to Refresh" scenarios.
  final bool forceRefresh;

  const CachePolicy({
    required this.key,
    this.ttl,
    this.revalidate = true,
    this.forceRefresh = false,
  });
}
