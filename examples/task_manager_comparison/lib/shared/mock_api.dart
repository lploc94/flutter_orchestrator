import 'dart:async';
import 'dart:math';
import 'models.dart';

/// Mock API service that simulates real-world network conditions.
/// 
/// Designed to expose race conditions and timing issues.
class MockApi {
  final _random = Random();
  final List<Task> _tasks = [];
  final List<Category> _categories = List.from(Category.defaults);

  // Configuration
  Duration minDelay = const Duration(milliseconds: 300);
  Duration maxDelay = const Duration(seconds: 2);
  double failureRate = 0.15; // 15% failure rate

  // Track pending requests to detect race conditions
  final Map<String, int> _pendingRequests = {};

  MockApi() {
    _initializeTasks();
  }

  void _initializeTasks() {
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
      ),
      Task(
        id: 'task_2',
        title: 'Buy groceries',
        description: 'Milk, eggs, bread',
        categoryId: 'shopping',
        priority: TaskPriority.medium,
        status: TaskStatus.pending,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      Task(
        id: 'task_3',
        title: 'Doctor appointment',
        categoryId: 'health',
        priority: TaskPriority.high,
        status: TaskStatus.pending,
        createdAt: now,
      ),
      Task(
        id: 'task_4',
        title: 'Review PRs',
        description: 'Review 5 pending PRs',
        categoryId: 'work',
        priority: TaskPriority.urgent,
        status: TaskStatus.pending,
        createdAt: now,
      ),
      Task(
        id: 'task_5',
        title: 'Clean house',
        categoryId: 'personal',
        priority: TaskPriority.low,
        status: TaskStatus.completed,
        createdAt: now.subtract(const Duration(days: 3)),
      ),
    ]);
  }

  /// Simulate random network delay.
  Future<Duration> _delay() async {
    final ms = minDelay.inMilliseconds +
        _random.nextInt(maxDelay.inMilliseconds - minDelay.inMilliseconds);
    final duration = Duration(milliseconds: ms);
    await Future.delayed(duration);
    return duration;
  }

  /// Maybe throw a network error.
  void _maybeThrow(String operation) {
    if (_random.nextDouble() < failureRate) {
      throw Exception('Network error: $operation failed');
    }
  }

  /// Check for race condition - returns request number.
  int _trackRequest(String operation) {
    final count = (_pendingRequests[operation] ?? 0) + 1;
    _pendingRequests[operation] = count;
    return count;
  }

  /// Check if this request is stale (newer request started).
  bool _isStaleRequest(String operation, int requestNum) {
    return (_pendingRequests[operation] ?? 0) > requestNum;
  }

  /// Fetch all tasks.
  Future<(List<Task>, int, bool)> fetchTasks() async {
    final requestNum = _trackRequest('fetchTasks');
    final delay = await _delay();
    _maybeThrow('fetchTasks');

    final isStale = _isStaleRequest('fetchTasks', requestNum);
    return (List<Task>.from(_tasks), delay.inMilliseconds, isStale);
  }

  /// Search tasks.
  Future<(List<Task>, int, bool, String)> searchTasks(String query) async {
    final requestNum = _trackRequest('search:$query');
    final delay = await _delay();
    _maybeThrow('searchTasks');

    final results = _tasks
        .where((t) => t.title.toLowerCase().contains(query.toLowerCase()))
        .toList();

    final isStale = _isStaleRequest('search:$query', requestNum);
    return (results, delay.inMilliseconds, isStale, query);
  }

  /// Create task.
  Future<Task> createTask(Task task) async {
    await _delay();
    _maybeThrow('createTask');

    final newTask = Task(
      id: 'task_${DateTime.now().millisecondsSinceEpoch}',
      title: task.title,
      description: task.description,
      categoryId: task.categoryId,
      priority: task.priority,
      status: TaskStatus.pending,
      createdAt: DateTime.now(),
    );
    _tasks.add(newTask);
    return newTask;
  }

  /// Delete task.
  Future<void> deleteTask(String taskId) async {
    await _delay();
    _maybeThrow('deleteTask');
    _tasks.removeWhere((t) => t.id == taskId);
  }

  /// Fetch categories.
  Future<List<Category>> fetchCategories() async {
    await _delay();
    return List.from(_categories);
  }

  /// Fetch stats.
  Future<DashboardStats> fetchStats() async {
    await _delay();
    return DashboardStats(
      totalTasks: _tasks.length,
      completedTasks: _tasks.where((t) => t.status == TaskStatus.completed).length,
      pendingTasks: _tasks.where((t) => t.status == TaskStatus.pending).length,
      urgentTasks: _tasks.where((t) => t.priority == TaskPriority.urgent).length,
    );
  }

  /// Reset for fresh comparison.
  void reset() {
    _pendingRequests.clear();
  }
}
