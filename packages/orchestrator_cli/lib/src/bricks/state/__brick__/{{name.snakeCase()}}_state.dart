/// {{name.pascalCase()}}State - Immutable state class
///
/// Contains the UI state for the {{name.pascalCase()}} feature.
/// Use copyWith() to create new instances with updated values.
class {{name.pascalCase()}}State {
  /// Whether an async operation is in progress
  final bool isLoading;

  /// Error message if the last operation failed
  final String? error;

  // TODO: Add your data fields
  // final {{name.pascalCase()}}? data;
  // final List<Item> items;

  const {{name.pascalCase()}}State({
    this.isLoading = false,
    this.error,
    // this.data,
    // this.items = const [],
  });

  /// Creates a copy with the given fields replaced
  {{name.pascalCase()}}State copyWith({
    bool? isLoading,
    String? error,
    // {{name.pascalCase()}}? data,
    // List<Item>? items,
  }) {
    return {{name.pascalCase()}}State(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      // data: data ?? this.data,
      // items: items ?? this.items,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is {{name.pascalCase()}}State &&
        other.isLoading == isLoading &&
        other.error == error;
  }

  @override
  int get hashCode => isLoading.hashCode ^ error.hashCode;

  @override
  String toString() => '{{name.pascalCase()}}State(isLoading: $isLoading, error: $error)';
}
