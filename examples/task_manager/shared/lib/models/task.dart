import 'package:meta/meta.dart';

/// Task priority levels.
enum TaskPriority { low, medium, high, urgent }

/// Task status.
enum TaskStatus { pending, inProgress, completed, cancelled }

/// Task model representing a todo item.
@immutable
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
  final List<String> attachmentIds;
  final bool isSynced;

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
    this.attachmentIds = const [],
    this.isSynced = true,
  });

  Task copyWith({
    String? id,
    String? title,
    String? description,
    String? categoryId,
    TaskPriority? priority,
    TaskStatus? status,
    DateTime? createdAt,
    DateTime? dueDate,
    DateTime? completedAt,
    List<String>? attachmentIds,
    bool? isSynced,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate ?? this.dueDate,
      completedAt: completedAt ?? this.completedAt,
      attachmentIds: attachmentIds ?? this.attachmentIds,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  /// Create a placeholder task for skeleton UI.
  static Task placeholder({String? id}) => Task(
        id: id ?? 'placeholder',
        title: '',
        categoryId: '',
        createdAt: DateTime.now(),
      );

  /// Check if this is a placeholder.
  bool get isPlaceholder => id == 'placeholder' || title.isEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Task && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Task(id: $id, title: $title, status: $status)';
}

