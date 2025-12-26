// @template-name: Counter
// Golden example file for CLI template generation
// Run: dart run scripts/sync_templates.dart

/// CounterState - Immutable state class
///
/// Contains the UI state for the Counter feature.
/// Use copyWith() to create new instances with updated values.
class CounterState {
  /// Whether an async operation is in progress
  final bool isLoading;

  /// Error message if the last operation failed
  final String? error;

  // TODO: Add your data fields
  // final Counter? data;
  // final List<Item> items;

  const CounterState({
    this.isLoading = false,
    this.error,
    // this.data,
    // this.items = const [],
  });

  /// Creates a copy with the given fields replaced
  CounterState copyWith({
    bool? isLoading,
    String? error,
    // Counter? data,
    // List<Item>? items,
  }) {
    return CounterState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      // data: data ?? this.data,
      // items: items ?? this.items,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CounterState &&
        other.isLoading == isLoading &&
        other.error == error;
  }

  @override
  int get hashCode => isLoading.hashCode ^ error.hashCode;

  @override
  String toString() => 'CounterState(isLoading: $isLoading, error: $error)';
}
