import 'package:orchestrator_core/orchestrator_core.dart';

/// A fake [NetworkQueueStorage] for testing offline queue behavior.
///
/// Stores queued jobs in memory, allowing you to test offline scenarios
/// without actual file system access.
///
/// ## Example
///
/// ```dart
/// final storage = FakeNetworkQueueStorage();
///
/// // Save a job
/// await storage.saveJob('job-1', {'type': 'SendMessageJob', 'data': {}});
///
/// // Verify
/// expect(storage.jobs, hasLength(1));
/// expect(await storage.getJob('job-1'), isNotNull);
/// ```
class FakeNetworkQueueStorage implements NetworkQueueStorage {
  /// All stored jobs indexed by ID.
  final Map<String, Map<String, dynamic>> jobs = {};

  /// History of operations for verification.
  final List<String> operationHistory = [];

  /// Whether to simulate storage failures.
  bool shouldFail = false;

  /// Error message to throw when [shouldFail] is `true`.
  String failureMessage = 'Simulated storage failure';

  void _checkFailure() {
    if (shouldFail) {
      throw Exception(failureMessage);
    }
  }

  @override
  Future<void> saveJob(String id, Map<String, dynamic> data) async {
    _checkFailure();
    jobs[id] = Map<String, dynamic>.from(data);
    operationHistory.add('save:$id');
  }

  @override
  Future<void> removeJob(String id) async {
    _checkFailure();
    jobs.remove(id);
    operationHistory.add('remove:$id');
  }

  @override
  Future<Map<String, dynamic>?> getJob(String id) async {
    _checkFailure();
    operationHistory.add('get:$id');
    return jobs[id];
  }

  @override
  Future<List<Map<String, dynamic>>> getAllJobs() async {
    _checkFailure();
    operationHistory.add('getAll');
    return jobs.values.toList();
  }

  @override
  Future<void> updateJob(String id, Map<String, dynamic> updates) async {
    _checkFailure();
    if (jobs.containsKey(id)) {
      jobs[id]!.addAll(updates);
    }
    operationHistory.add('update:$id');
  }

  @override
  Future<void> clearAll() async {
    _checkFailure();
    jobs.clear();
    operationHistory.add('clearAll');
  }

  /// Get the number of stored jobs.
  int get length => jobs.length;

  /// Check if storage is empty.
  bool get isEmpty => jobs.isEmpty;

  /// Check if storage is not empty.
  bool get isNotEmpty => jobs.isNotEmpty;

  /// Get all job IDs.
  Iterable<String> get jobIds => jobs.keys;

  /// Get jobs with a specific status.
  List<Map<String, dynamic>> getJobsByStatus(String status) {
    return jobs.values.where((job) => job['status'] == status).toList();
  }

  /// Get pending jobs.
  List<Map<String, dynamic>> get pendingJobs => getJobsByStatus('pending');

  /// Get processing jobs.
  List<Map<String, dynamic>> get processingJobs =>
      getJobsByStatus('processing');

  /// Get poisoned jobs.
  List<Map<String, dynamic>> get poisonedJobs => getJobsByStatus('poisoned');

  /// Reset the storage to initial state.
  void reset() {
    jobs.clear();
    operationHistory.clear();
    shouldFail = false;
  }
}
