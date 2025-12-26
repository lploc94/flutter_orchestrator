/// Common state patterns for orchestrators.
///
/// These mixins and base classes provide reusable state patterns
/// that are commonly needed in Flutter applications.
library;

/// Mixin for states that have loading status.
mixin LoadingState {
  bool get isLoading;
}

/// Mixin for states that can have errors.
mixin ErrorState {
  Object? get error;

  /// Whether an error has occurred.
  bool get hasError => error != null;

  /// Get error message as string.
  String? get errorMessage {
    final e = error;
    if (e == null) return null;
    if (e is Exception) {
      return e.toString().replaceFirst('Exception: ', '');
    }
    return e.toString();
  }
}

/// Mixin for states that have data.
mixin DataState<T> {
  T? get data;

  /// Whether data has been loaded.
  bool get hasData => data != null;
}

/// Enum representing async operation status.
enum AsyncStatus {
  /// Initial state, no operation has started.
  initial,

  /// Operation is in progress.
  loading,

  /// Operation completed successfully.
  success,

  /// Operation failed.
  failure,

  /// Operation is refreshing (reloading with existing data).
  refreshing,
}

/// Extension methods for [AsyncStatus].
extension AsyncStatusExtension on AsyncStatus {
  /// Whether an operation is in progress.
  bool get isLoading =>
      this == AsyncStatus.loading || this == AsyncStatus.refreshing;

  /// Whether the operation completed (success or failure).
  bool get isComplete =>
      this == AsyncStatus.success || this == AsyncStatus.failure;

  /// Whether this is the initial state.
  bool get isInitial => this == AsyncStatus.initial;

  /// Whether the operation succeeded.
  bool get isSuccess => this == AsyncStatus.success;

  /// Whether the operation failed.
  bool get isFailure => this == AsyncStatus.failure;
}

/// A generic async state container.
///
/// This provides a complete state pattern for async operations with
/// loading, success, failure, and refreshing states.
///
/// Example:
/// ```dart
/// class UserState extends AsyncState<User> {
///   const UserState({
///     super.status,
///     super.data,
///     super.error,
///   });
///
///   UserState copyWith({
///     AsyncStatus? status,
///     User? data,
///     Object? error,
///   }) => UserState(
///     status: status ?? this.status,
///     data: data ?? this.data,
///     error: error,
///   );
/// }
/// ```
class AsyncState<T> with LoadingState, ErrorState, DataState<T> {
  /// Current status of the async operation.
  final AsyncStatus status;

  /// The data loaded by the operation, if available.
  @override
  final T? data;

  /// The error that occurred, if the operation failed.
  @override
  final Object? error;

  /// Creates an [AsyncState] with optional status, data, and error.
  ///
  /// By default, [status] is [AsyncStatus.initial].
  const AsyncState({
    this.status = AsyncStatus.initial,
    this.data,
    this.error,
  });

  /// Whether an async operation is currently in progress.
  @override
  bool get isLoading => status.isLoading;

  /// Create a loading state.
  AsyncState<T> toLoading() => AsyncState<T>(
        status: AsyncStatus.loading,
        data: data,
      );

  /// Create a refreshing state (loading with existing data).
  AsyncState<T> toRefreshing() => AsyncState<T>(
        status: AsyncStatus.refreshing,
        data: data,
      );

  /// Create a success state with data.
  AsyncState<T> toSuccess(T data) => AsyncState<T>(
        status: AsyncStatus.success,
        data: data,
      );

  /// Create a failure state with error.
  AsyncState<T> toFailure(Object error) => AsyncState<T>(
        status: AsyncStatus.failure,
        data: data, // Preserve existing data
        error: error,
      );

  /// Pattern match on the state.
  R when<R>({
    required R Function() initial,
    required R Function() loading,
    required R Function(T data) success,
    required R Function(Object error) failure,
    R Function(T data)? refreshing,
  }) {
    return switch (status) {
      AsyncStatus.initial => initial(),
      AsyncStatus.loading => loading(),
      AsyncStatus.success => success(data as T),
      AsyncStatus.failure => failure(error!),
      AsyncStatus.refreshing => refreshing?.call(data as T) ?? loading(),
    };
  }

  /// Pattern match with optional handlers and orElse fallback.
  R maybeWhen<R>({
    R Function()? initial,
    R Function()? loading,
    R Function(T data)? success,
    R Function(Object error)? failure,
    R Function(T data)? refreshing,
    required R Function() orElse,
  }) {
    return switch (status) {
      AsyncStatus.initial => initial?.call() ?? orElse(),
      AsyncStatus.loading => loading?.call() ?? orElse(),
      AsyncStatus.success => success?.call(data as T) ?? orElse(),
      AsyncStatus.failure => failure?.call(error!) ?? orElse(),
      AsyncStatus.refreshing =>
        refreshing?.call(data as T) ?? loading?.call() ?? orElse(),
    };
  }
}
