/// Annotation to mark a class for async state pattern code generation.
///
/// When applied to a class, the generator will create:
/// - `copyWith` method
/// - `toLoading`, `toSuccess`, `toFailure`, `toRefreshing` methods
/// - `when` and `maybeWhen` pattern matching methods
///
/// Example:
/// ```dart
/// @GenerateAsyncState()
/// class UserState {
///   final User? user;
///   final List<Permission> permissions;
///   final String? errorMessage;
/// }
/// ```
///
/// Generated:
/// ```dart
/// extension _$UserStateCopyWith on UserState {
///   UserState copyWith({User? user, List<Permission>? permissions, String? errorMessage}) => ...
///   UserState toLoading() => ...
///   R when<R>({...}) => ...
/// }
/// ```
class GenerateAsyncState {
  /// Whether to generate equality operators (== and hashCode).
  final bool generateEquality;

  /// Custom status field name if not using default 'status'.
  final String? statusField;

  const GenerateAsyncState({
    this.generateEquality = false,
    this.statusField,
  });
}
