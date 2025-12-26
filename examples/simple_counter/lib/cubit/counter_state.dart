// lib/cubit/counter_state.dart
// Immutable state class for Counter

class CounterState {
  final int count;
  final bool isLoading;
  final String? error;

  const CounterState({this.count = 0, this.isLoading = false, this.error});

  CounterState copyWith({int? count, bool? isLoading, String? error}) {
    return CounterState(
      count: count ?? this.count,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  @override
  String toString() =>
      'CounterState(count: $count, isLoading: $isLoading, error: $error)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CounterState &&
        other.count == count &&
        other.isLoading == isLoading &&
        other.error == error;
  }

  @override
  int get hashCode => count.hashCode ^ isLoading.hashCode ^ error.hashCode;
}
