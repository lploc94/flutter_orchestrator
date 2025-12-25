import 'dart:async';
import 'dart:math';
import '../models/task.dart';
import '../models/category.dart';

/// Mock API service that simulates real-world network conditions.
///
/// This service is designed to expose problems in traditional architectures:
/// - Random delays (1-5 seconds) to trigger race conditions
/// - Random failures to test error handling
/// - Heavy computation to block UI thread
/// - Memory-heavy responses to test memory management
class MockApiService {
  static final MockApiService _instance = MockApiService._internal();
  factory MockApiService() => _instance;
  MockApiService._internal();

  final _random = Random();

  // Simulated database
  final List<Task> _tasks = [];
  final List<Category> _categories = List.from(Category.defaults);

  // Configuration for chaos engineering
  bool chaosMode = true;
  double failureRate = 0.3; // 30% chance to fail
  Duration minDelay = const Duration(milliseconds: 500);
  Duration maxDelay = const Duration(seconds: 3);

  // Track API call count for debugging
  int _apiCallCount = 0;
  int get apiCallCount => _apiCallCount;

  /// Initialize with sample data.
  void initialize() {
    if (_tasks.isNotEmpty) return;

    final now = DateTime.now();
    _tasks.addAll([
      Task(
        id: 'task_1',
        title: 'Complete project proposal',
        description: 'Write detailed proposal for Q2 project',
        categoryId: 'work',
        priority: TaskPriority.high,
        status: TaskStatus.inProgress,
        createdAt: now.subtract(const Duration(days: 2)),
        dueDate: now.add(const Duration(days: 5)),
      ),
      Task(
        id: 'task_2',
        title: 'Buy groceries',
        description: 'Milk, eggs, bread, vegetables',
        categoryId: 'shopping',
        priority: TaskPriority.medium,
        status: TaskStatus.pending,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      Task(
        id: 'task_3',
        title: 'Schedule doctor appointment',
        categoryId: 'health',
        priority: TaskPriority.high,
        status: TaskStatus.pending,
        createdAt: now,
        dueDate: now.add(const Duration(days: 3)),
      ),
      Task(
        id: 'task_4',
        title: 'Review pull requests',
        description: 'Review 5 pending PRs from team',
        categoryId: 'work',
        priority: TaskPriority.urgent,
        status: TaskStatus.pending,
        createdAt: now,
      ),
      Task(
        id: 'task_5',
        title: 'Clean the house',
        categoryId: 'personal',
        priority: TaskPriority.low,
        status: TaskStatus.completed,
        createdAt: now.subtract(const Duration(days: 3)),
        completedAt: now.subtract(const Duration(days: 1)),
      ),
    ]);
  }

  /// Simulate network delay with random duration.
  Future<void> _simulateNetworkDelay() async {
    if (!chaosMode) {
      await Future.delayed(const Duration(milliseconds: 200));
      return;
    }

    final delayMs = minDelay.inMilliseconds +
        _random.nextInt(maxDelay.inMilliseconds - minDelay.inMilliseconds);
    await Future.delayed(Duration(milliseconds: delayMs));
  }

  /// Randomly throw network errors.
  void _maybeThrowError(String operation) {
    if (chaosMode && _random.nextDouble() < failureRate) {
      final errors = [
        NetworkException('Connection timeout for $operation'),
        NetworkException('Server error 500 for $operation'),
        NetworkException('No internet connection'),
        NetworkException('Request cancelled'),
      ];
      throw errors[_random.nextInt(errors.length)];
    }
  }

  /// Simulate heavy computation that blocks the isolate.
  /// This is intentionally BAD to show the problem.
  void _simulateHeavyComputation() {
    if (!chaosMode) return;

    // Waste CPU cycles - this WILL cause jank
    var sum = 0;
    for (var i = 0; i < 5000000; i++) {
      sum += i % 7;
    }
    // Use sum to prevent compiler optimization
    if (sum < 0) print('never');
  }

  // ============ Task APIs ============

  /// Fetch all tasks with simulated delay and potential failure.
  Future<List<Task>> fetchTasks() async {
    _apiCallCount++;
    final callId = _apiCallCount;
    print('📡 API Call #$callId: fetchTasks() started');

    await _simulateNetworkDelay();
    _maybeThrowError('fetchTasks');
    _simulateHeavyComputation();

    print('✅ API Call #$callId: fetchTasks() completed with ${_tasks.length} tasks');
    return List.from(_tasks);
  }

  /// Fetch tasks by category.
  Future<List<Task>> fetchTasksByCategory(String categoryId) async {
    _apiCallCount++;
    final callId = _apiCallCount;
    print('📡 API Call #$callId: fetchTasksByCategory($categoryId) started');

    await _simulateNetworkDelay();
    _maybeThrowError('fetchTasksByCategory');

    final filtered = _tasks.where((t) => t.categoryId == categoryId).toList();
    print('✅ API Call #$callId: fetchTasksByCategory completed with ${filtered.length} tasks');
    return filtered;
  }

  /// Search tasks - INTENTIONALLY SLOW for demonstrating cancellation.
  Future<List<Task>> searchTasks(String query) async {
    _apiCallCount++;
    final callId = _apiCallCount;
    print('📡 API Call #$callId: searchTasks("$query") started');

    // Extra long delay for search to demonstrate cancellation need
    await Future.delayed(Duration(milliseconds: 800 + _random.nextInt(1500)));
    _maybeThrowError('searchTasks');

    final results = _tasks
        .where((t) =>
            t.title.toLowerCase().contains(query.toLowerCase()) ||
            t.description.toLowerCase().contains(query.toLowerCase()))
        .toList();

    print('✅ API Call #$callId: searchTasks completed with ${results.length} results');
    return results;
  }

  /// Create a new task.
  Future<Task> createTask(Task task) async {
    _apiCallCount++;
    final callId = _apiCallCount;
    print('📡 API Call #$callId: createTask("${task.title}") started');

    // Longer delay for create operations
    await Future.delayed(Duration(milliseconds: 1000 + _random.nextInt(2000)));
    _maybeThrowError('createTask');

    final newTask = task.copyWith(
      id: 'task_${DateTime.now().millisecondsSinceEpoch}',
      createdAt: DateTime.now(),
      isSynced: true,
    );
    _tasks.add(newTask);

    print('✅ API Call #$callId: createTask completed with id: ${newTask.id}');
    return newTask;
  }

  /// Update an existing task.
  Future<Task> updateTask(Task task) async {
    _apiCallCount++;
    final callId = _apiCallCount;
    print('📡 API Call #$callId: updateTask("${task.id}") started');

    await _simulateNetworkDelay();
    _maybeThrowError('updateTask');

    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index == -1) {
      throw NetworkException('Task not found: ${task.id}');
    }

    final updatedTask = task.copyWith(isSynced: true);
    _tasks[index] = updatedTask;

    print('✅ API Call #$callId: updateTask completed');
    return updatedTask;
  }

  /// Delete a task.
  Future<void> deleteTask(String taskId) async {
    _apiCallCount++;
    final callId = _apiCallCount;
    print('📡 API Call #$callId: deleteTask("$taskId") started');

    await _simulateNetworkDelay();
    _maybeThrowError('deleteTask');

    _tasks.removeWhere((t) => t.id == taskId);
    print('✅ API Call #$callId: deleteTask completed');
  }

  /// Upload attachment - Reports progress for demonstrating progress events.
  Stream<UploadProgress> uploadAttachment(String taskId, String fileName) async* {
    _apiCallCount++;
    final callId = _apiCallCount;
    print('📡 API Call #$callId: uploadAttachment("$fileName") started');

    final totalChunks = 10;
    for (var i = 1; i <= totalChunks; i++) {
      await Future.delayed(Duration(milliseconds: 200 + _random.nextInt(300)));

      // Random failure during upload
      if (chaosMode && i > 5 && _random.nextDouble() < 0.2) {
        throw NetworkException('Upload interrupted at ${i * 10}%');
      }

      yield UploadProgress(
        progress: i / totalChunks,
        bytesUploaded: i * 1024 * 100,
        totalBytes: totalChunks * 1024 * 100,
      );
    }

    print('✅ API Call #$callId: uploadAttachment completed');
  }

  // ============ Category APIs ============

  /// Fetch all categories with task counts.
  Future<List<Category>> fetchCategories() async {
    _apiCallCount++;
    final callId = _apiCallCount;
    print('📡 API Call #$callId: fetchCategories() started');

    await _simulateNetworkDelay();
    _maybeThrowError('fetchCategories');

    // Calculate task counts
    final result = _categories.map((cat) {
      final count = _tasks.where((t) => t.categoryId == cat.id).length;
      return cat.copyWith(taskCount: count);
    }).toList();

    print('✅ API Call #$callId: fetchCategories completed');
    return result;
  }

  // ============ Stats APIs ============

  /// Fetch dashboard stats - HEAVY operation.
  Future<DashboardStats> fetchDashboardStats() async {
    _apiCallCount++;
    final callId = _apiCallCount;
    print('📡 API Call #$callId: fetchDashboardStats() started');

    await _simulateNetworkDelay();
    _maybeThrowError('fetchDashboardStats');
    _simulateHeavyComputation(); // Extra heavy

    final stats = DashboardStats(
      totalTasks: _tasks.length,
      completedTasks: _tasks.where((t) => t.status == TaskStatus.completed).length,
      pendingTasks: _tasks.where((t) => t.status == TaskStatus.pending).length,
      urgentTasks: _tasks.where((t) => t.priority == TaskPriority.urgent).length,
      overdueTask: _tasks.where((t) =>
          t.dueDate != null &&
          t.dueDate!.isBefore(DateTime.now()) &&
          t.status != TaskStatus.completed).length,
    );

    print('✅ API Call #$callId: fetchDashboardStats completed');
    return stats;
  }

  /// Reset for testing.
  void reset() {
    _tasks.clear();
    _apiCallCount = 0;
  }
}

/// Network exception for simulating failures.
class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);

  @override
  String toString() => 'NetworkException: $message';
}

/// Upload progress model.
class UploadProgress {
  final double progress;
  final int bytesUploaded;
  final int totalBytes;

  UploadProgress({
    required this.progress,
    required this.bytesUploaded,
    required this.totalBytes,
  });
}

/// Dashboard statistics model.
class DashboardStats {
  final int totalTasks;
  final int completedTasks;
  final int pendingTasks;
  final int urgentTasks;
  final int overdueTask;

  DashboardStats({
    required this.totalTasks,
    required this.completedTasks,
    required this.pendingTasks,
    required this.urgentTasks,
    required this.overdueTask,
  });

  double get completionRate =>
      totalTasks > 0 ? completedTasks / totalTasks : 0.0;
}

