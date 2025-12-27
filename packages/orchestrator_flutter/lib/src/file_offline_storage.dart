import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:orchestrator_core/orchestrator_core.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Stores offline jobs as JSON files in the app's documents directory.
class FileNetworkQueueStorage implements NetworkQueueStorage {
  static const String _dirName = 'orchestrator_offline_queue';

  Future<Directory> get _queueDir async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, _dirName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _getFile(String id) async {
    final dir = await _queueDir;
    // Sanitize ID using base64 to prevent collisions
    // (different IDs like "a:b" and "a_b" won't map to same filename)
    final safeId = base64Url.encode(utf8.encode(id)).replaceAll('=', '');
    return File(p.join(dir.path, '$safeId.json'));
  }

  @override
  Future<void> saveJob(String id, Map<String, dynamic> data) async {
    final file = await _getFile(id);
    await file.writeAsString(jsonEncode(data));
  }

  @override
  Future<Map<String, dynamic>?> getJob(String id) async {
    final file = await _getFile(id);
    if (!await file.exists()) return null;
    final content = await file.readAsString();
    return jsonDecode(content) as Map<String, dynamic>;
  }

  @override
  Future<List<Map<String, dynamic>>> getAllJobs() async {
    final dir = await _queueDir;
    final List<Map<String, dynamic>> jobs = [];

    // Check if directory exists (might be deleted by clearAll or never created)
    if (!await dir.exists()) {
      return jobs;
    }

    // List all files
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        try {
          final content = await entity.readAsString();
          final decoded = jsonDecode(content);
          if (decoded is Map<String, dynamic>) {
            jobs.add(decoded);
          }
          // Skip if decoded is not a valid Map
        } on FormatException {
          // JSON parse error - corrupt file, skip it
          // Consider: await entity.delete(); to auto-cleanup corrupt files
        } on FileSystemException {
          // File read error - skip
        } catch (e) {
          // Other unexpected errors - skip but don't crash
        }
      }
    }

    // Sort by timestamp to ensure FIFO order (RFC requirement)
    jobs.sort((a, b) {
      final tsA =
          DateTime.tryParse(a['timestamp']?.toString() ?? '') ?? DateTime(0);
      final tsB =
          DateTime.tryParse(b['timestamp']?.toString() ?? '') ?? DateTime(0);
      return tsA.compareTo(tsB);
    });

    return jobs;
  }

  @override
  Future<void> removeJob(String id) async {
    final file = await _getFile(id);
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<void> updateJob(String id, Map<String, dynamic> updates) async {
    final file = await _getFile(id);
    final tempPath = '${file.path}.tmp.${Random().nextInt(99999)}';

    // Retry logic for transient file system errors
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        if (!await file.exists()) {
          // Job doesn't exist - this is not necessarily an error,
          // the job might have been removed by another process
          return;
        }

        final content = await file.readAsString();
        final existing = jsonDecode(content) as Map<String, dynamic>;
        final updated = {...existing, ...updates};

        // Atomic write: write to temp file then rename
        final tempFile = File(tempPath);
        await tempFile.writeAsString(jsonEncode(updated));
        await tempFile.rename(file.path);
        return;
      } on FileSystemException {
        // Cleanup temp file if it exists
        try {
          await File(tempPath).delete();
        } catch (_) {}

        if (attempt == 2) rethrow; // Last attempt, propagate error
        await Future.delayed(Duration(milliseconds: 50 * (attempt + 1)));
      }
    }
  }

  @override
  Future<void> clearAll() async {
    final dir = await _queueDir;
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}
