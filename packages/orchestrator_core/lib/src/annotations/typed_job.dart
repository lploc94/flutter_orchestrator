/// Annotation to generate a sealed job hierarchy from an interface.
///
/// When applied to an abstract class, the generator will create:
/// - A sealed base class extending `BaseJob`
/// - Concrete job classes for each method in the interface
///
/// ## Example
///
/// ```dart
/// @TypedJob()
/// abstract class UserJobInterface {
///   Future<User> fetchUser(String userId);
///   Future<void> updateUser({required String userId, required String name});
///   Future<void> deleteUser(String userId);
/// }
/// ```
///
/// Generates:
/// ```dart
/// sealed class UserJob extends BaseJob {
///   UserJob({required super.id});
/// }
///
/// class FetchUserJob extends UserJob {
///   final String userId;
///   FetchUserJob(this.userId) : super(id: generateJobId('fetch_user'));
/// }
///
/// class UpdateUserJob extends UserJob {
///   final String userId;
///   final String name;
///   UpdateUserJob({required this.userId, required this.name})
///       : super(id: generateJobId('update_user'));
/// }
///
/// class DeleteUserJob extends UserJob {
///   final String userId;
///   DeleteUserJob(this.userId) : super(id: generateJobId('delete_user'));
/// }
/// ```
///
/// ## Naming Convention
///
/// - Interface: `{Feature}JobInterface` (e.g., `UserJobInterface`)
/// - Sealed class: `{Feature}Job` (e.g., `UserJob`)
/// - Concrete jobs: `{MethodName}Job` with PascalCase (e.g., `FetchUserJob`)
///
/// ## Configuration
///
/// ```dart
/// @TypedJob(
///   timeout: Duration(seconds: 30),    // Default timeout for all jobs
///   maxRetries: 3,                       // Default retry count
///   idPrefix: 'user',                    // Custom ID prefix (default: snake_case of sealed class)
/// )
/// abstract class UserJobInterface { ... }
/// ```
class TypedJob {
  /// Default timeout for all generated jobs.
  final Duration? timeout;

  /// Default maximum retry attempts for all generated jobs.
  final int? maxRetries;

  /// Initial retry delay for exponential backoff.
  final Duration? retryDelay;

  /// Custom ID prefix for all generated jobs.
  /// If not specified, uses snake_case of the sealed class name.
  final String? idPrefix;

  /// Suffix to remove from interface name to derive sealed class name.
  /// Default: 'Interface'
  final String interfaceSuffix;

  const TypedJob({
    this.timeout,
    this.maxRetries,
    this.retryDelay,
    this.idPrefix,
    this.interfaceSuffix = 'Interface',
  });
}
