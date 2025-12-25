import 'package:meta/meta.dart';

/// Category model for grouping tasks.
@immutable
class Category {
  final String id;
  final String name;
  final String icon;
  final int color;
  final int taskCount;

  const Category({
    required this.id,
    required this.name,
    this.icon = '📁',
    this.color = 0xFF2196F3,
    this.taskCount = 0,
  });

  Category copyWith({
    String? id,
    String? name,
    String? icon,
    int? color,
    int? taskCount,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      taskCount: taskCount ?? this.taskCount,
    );
  }

  /// Predefined categories.
  static const List<Category> defaults = [
    Category(id: 'work', name: 'Work', icon: '💼', color: 0xFF2196F3),
    Category(id: 'personal', name: 'Personal', icon: '🏠', color: 0xFF4CAF50),
    Category(id: 'shopping', name: 'Shopping', icon: '🛒', color: 0xFFFF9800),
    Category(id: 'health', name: 'Health', icon: '❤️', color: 0xFFF44336),
  ];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Category && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Category(id: $id, name: $name)';
}

