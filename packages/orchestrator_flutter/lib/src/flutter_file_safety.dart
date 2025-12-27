import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:orchestrator_core/orchestrator_core.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class FlutterFileSafety implements FileSafetyDelegate {
  static const String _safeDirName = 'orchestrator_offline_files';

  /// Cached safe directory path for performance and security checks
  String? _cachedSafeDirPath;

  @override
  Future<Map<String, dynamic>> secureFiles(Map<String, dynamic> jobData) async {
    // FIX BUG #5: True deep copy using JSON serialization
    // Map.from() only does shallow copy - nested objects are still references
    final newData = jsonDecode(jsonEncode(jobData)) as Map<String, dynamic>;
    await _recurseAndSecure(newData);
    return newData;
  }

  @override
  Future<void> cleanupFiles(Map<String, dynamic> jobData) async {
    await _recurseAndCleanup(jobData);
  }

  Future<void> _recurseAndSecure(Map<dynamic, dynamic> map) async {
    for (final key in map.keys) {
      final value = map[key];

      if (value is String) {
        if (await _isTempFile(value)) {
          final newPath = await _copyToSafeLocation(value);
          map[key] = newPath;
        }
      } else if (value is Map) {
        await _recurseAndSecure(value);
      } else if (value is List) {
        await _recurseAndSecureList(value);
      }
    }
  }

  /// FIX BUG #8: Handle nested lists recursively
  Future<void> _recurseAndSecureList(List<dynamic> list) async {
    for (var i = 0; i < list.length; i++) {
      final item = list[i];
      if (item is String) {
        if (await _isTempFile(item)) {
          final newPath = await _copyToSafeLocation(item);
          list[i] = newPath;
        }
      } else if (item is Map) {
        await _recurseAndSecure(item);
      } else if (item is List) {
        // Handle nested lists (e.g., [["/tmp/a.jpg", "/tmp/b.jpg"]])
        await _recurseAndSecureList(item);
      }
    }
  }

  Future<void> _recurseAndCleanup(Map<dynamic, dynamic> map) async {
    for (final value in map.values) {
      if (value is String) {
        if (await _isSafeFile(value)) {
          try {
            await File(value).delete();
          } catch (_) {}
        }
      } else if (value is Map) {
        await _recurseAndCleanup(value);
      } else if (value is List) {
        await _recurseAndCleanupList(value);
      }
    }
  }

  /// FIX BUG #8: Handle nested lists recursively for cleanup
  Future<void> _recurseAndCleanupList(List<dynamic> list) async {
    for (final item in list) {
      if (item is String) {
        if (await _isSafeFile(item)) {
          try {
            await File(item).delete();
          } catch (_) {}
        }
      } else if (item is Map) {
        await _recurseAndCleanup(item);
      } else if (item is List) {
        // Handle nested lists
        await _recurseAndCleanupList(item);
      }
    }
  }

  // --- Helpers ---

  /// Get and cache the safe directory path
  Future<String> _getSafeDirPath() async {
    if (_cachedSafeDirPath != null) return _cachedSafeDirPath!;
    final docs = await getApplicationDocumentsDirectory();
    _cachedSafeDirPath = p.join(docs.path, _safeDirName);
    return _cachedSafeDirPath!;
  }

  Future<bool> _isTempFile(String path) async {
    // Basic validation
    if (path.length > 255 || path.contains('\n')) return false;

    // Only copy files from known temporary/cache directories
    // This prevents copying system files or already-persistent files
    // Use path segment matching to avoid false positives like '/mycacheproject/'
    final tempSegments = [
      'tmp', // Linux/macOS temp
      'cache', // Android cache, generic cache
      'Caches', // iOS Caches
      'Cache', // Alternative cache naming
      'image_picker', // Flutter image_picker temp
      'file_picker', // Flutter file_picker temp
    ];

    // Split path into segments and check if any segment matches temp patterns
    final segments = path.split(Platform.pathSeparator);
    final isInTempDir = segments.any(
      (segment) => tempSegments.any(
        (pattern) => segment.toLowerCase() == pattern.toLowerCase(),
      ),
    );
    if (!isInTempDir) return false;

    // Check strict existence
    final file = File(path);
    if (!await file.exists()) return false;

    // Check if it's already in our safe dir (don't re-copy)
    final safeDirPath = await _getSafeDirPath();
    if (p.isWithin(safeDirPath, path)) return false;

    return true;
  }

  /// FIX WARNING #7: Secure path validation using p.isWithin
  /// Prevents path traversal attacks and ensures we only delete our own files
  Future<bool> _isSafeFile(String path) async {
    final safeDirPath = await _getSafeDirPath();

    // Security: Use proper path containment check instead of string contains
    // This prevents attacks like '/var/important/orchestrator_offline_files_fake/file'
    if (!p.isWithin(safeDirPath, path)) return false;

    // Also verify the file exists before attempting cleanup
    return await File(path).exists();
  }

  /// FIX WARNING #6: Use microseconds + random to prevent collision
  Future<String> _copyToSafeLocation(String oldPath) async {
    final safeDirPath = await _getSafeDirPath();
    final safeDir = Directory(safeDirPath);
    if (!await safeDir.exists()) {
      await safeDir.create(recursive: true);
    }

    final filename = p.basename(oldPath);
    // Use microseconds + random number to avoid collision even in fast loops
    final uniqueName =
        '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(99999)}_$filename';
    final newPath = p.join(safeDir.path, uniqueName);

    await File(oldPath).copy(newPath);
    return newPath;
  }

  // --- Cleanup Methods (RFC 004) ---

  /// Cleanup files older than [maxAge] in the safe directory.
  ///
  /// Returns a record with:
  /// - `count`: Number of files deleted.
  /// - `bytes`: Total bytes freed.
  ///
  /// Example:
  /// ```dart
  /// final result = await fileSafety.cleanupOldFiles(Duration(days: 7));
  /// print('Deleted ${result.count} files (${result.bytes} bytes)');
  /// ```
  Future<({int count, int bytes})> cleanupOldFiles(Duration maxAge) async {
    final safeDirPath = await _getSafeDirPath();
    final safeDir = Directory(safeDirPath);

    if (!await safeDir.exists()) return (count: 0, bytes: 0);

    int count = 0;
    int bytes = 0;
    final cutoff = DateTime.now().subtract(maxAge);

    await for (final entity in safeDir.list()) {
      if (entity is File) {
        try {
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoff)) {
            bytes += stat.size;
            await entity.delete();
            count++;
          }
        } catch (_) {
          // Ignore errors for individual files
        }
      }
    }

    return (count: count, bytes: bytes);
  }

  /// Get current storage usage in the safe directory.
  ///
  /// Returns a record with:
  /// - `fileCount`: Number of files.
  /// - `totalBytes`: Total size in bytes.
  Future<({int fileCount, int totalBytes})> getStorageUsage() async {
    final safeDirPath = await _getSafeDirPath();
    final safeDir = Directory(safeDirPath);

    if (!await safeDir.exists()) return (fileCount: 0, totalBytes: 0);

    int fileCount = 0;
    int totalBytes = 0;

    await for (final entity in safeDir.list()) {
      if (entity is File) {
        try {
          totalBytes += await entity.length();
          fileCount++;
        } catch (_) {
          // Ignore errors
        }
      }
    }

    return (fileCount: fileCount, totalBytes: totalBytes);
  }
}
