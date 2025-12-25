/// Task and Category models for the comparison example.
library;

enum TaskStatus { pending, inProgress, completed, cancelled }

enum TaskPriority { low, medium, high, urgent }

class Task {
  final String id;
  final String title;
  final String description;
  final String categoryId;
  final TaskPriority priority;
  final TaskStatus status;
  final DateTime createdAt;
  final DateTime? dueDate;
  final DateTime? completedAt;

  const Task({
    required this.id,
    required this.title,
    this.description = '',
    required this.categoryId,
    this.priority = TaskPriority.medium,
    this.status = TaskStatus.pending,
    required this.createdAt,
    this.dueDate,
    this.completedAt,
  });

  Task copyWith({
    String? title,
    String? description,
    String? categoryId,
    TaskPriority? priority,
    TaskStatus? status,
    DateTime? dueDate,
    DateTime? completedAt,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      createdAt: createdAt,
      dueDate: dueDate ?? this.dueDate,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

class Category {
  final String id;
  final String name;
  final String icon;
  final int taskCount;

  const Category({
    required this.id,
    required this.name,
    required this.icon,
    this.taskCount = 0,
  });

  static const List<Category> defaults = [
    Category(id: 'work', name: 'Work', icon: '💼', taskCount: 2),
    Category(id: 'personal', name: 'Personal', icon: '🏠', taskCount: 1),
    Category(id: 'shopping', name: 'Shopping', icon: '🛒', taskCount: 1),
    Category(id: 'health', name: 'Health', icon: '🏥', taskCount: 1),
  ];
}

class DashboardStats {
  final int totalTasks;
  final int completedTasks;
  final int pendingTasks;
  final int urgentTasks;

  const DashboardStats({
    this.totalTasks = 0,
    this.completedTasks = 0,
    this.pendingTasks = 0,
    this.urgentTasks = 0,
  });
}
