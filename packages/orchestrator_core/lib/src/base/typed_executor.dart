import 'base_executor.dart';
import '../models/job.dart';

/// Type-safe executor with explicit result type.
///
/// Unlike [BaseExecutor] which returns `dynamic` from [process], [TypedExecutor]
/// provides compile-time type safety for the result of job execution.
///
/// ## Example
///
/// ```dart
/// class FetchUserExecutor extends TypedExecutor<FetchUserJob, User> {
///   @override
///   Future<User> run(FetchUserJob job) async {
///     final response = await api.getUser(job.userId);
///     return User.fromJson(response);
///   }
/// }
///
/// // The executor guarantees User type at compile time
/// dispatcher.register(FetchUserExecutor());
/// ```
///
/// ## Benefits
///
/// - **Type Safety**: Compiler enforces return type, catching errors early.
/// - **Better IDE Support**: Autocomplete knows the exact return type.
/// - **Self-Documenting**: Method signature clearly shows expected result.
///
/// ## When to Use
///
/// Use [TypedExecutor] when:
/// - You want compile-time guarantees on result types
/// - Building a typed API layer
/// - Working with strongly-typed state management
abstract class TypedExecutor<T extends EventJob, R> extends BaseExecutor<T> {
  /// Override this method to implement your typed business logic.
  ///
  /// The return type [R] is enforced at compile time.
  ///
  /// ## Example
  ///
  /// ```dart
  /// @override
  /// Future<User> run(FetchUserJob job) async {
  ///   return await userRepository.getById(job.userId);
  /// }
  /// ```
  Future<R> run(T job);

  /// Internal process method that delegates to [run].
  ///
  /// You should NOT override this. Override [run] instead.
  @override
  Future<dynamic> process(T job) => run(job);
}

/// A typed executor that processes jobs synchronously.
///
/// Use this for simple, non-async operations where you want type safety.
///
/// ## Example
///
/// ```dart
/// class CalculateTaxExecutor extends SyncTypedExecutor<CalculateTaxJob, double> {
///   @override
///   double runSync(CalculateTaxJob job) {
///     return job.amount * 0.1;
///   }
/// }
/// ```
abstract class SyncTypedExecutor<T extends EventJob, R> extends BaseExecutor<T> {
  /// Override this method to implement synchronous business logic.
  ///
  /// For async operations, use [TypedExecutor] instead.
  R runSync(T job);

  @override
  Future<dynamic> process(T job) async => runSync(job);
}
