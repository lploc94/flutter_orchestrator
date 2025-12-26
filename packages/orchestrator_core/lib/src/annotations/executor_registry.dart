/// Annotation to register Executors for specific Jobs.
///
/// The [entries] list should contain records or pairs mapping a Job type to
/// an Executor type.
///
/// Example:
/// ```dart
/// @ExecutorRegistry()
/// void registerExecutors() {}
/// ```
class ExecutorRegistry {
  /// List of Job-Executor pairs to register.
  ///
  /// Currently, the generator expects this to be used on a function where the
  /// annotation itself might not carry all data if we rely on type inference,
  /// but typically we pass the mapping here.
  ///
  /// Usage: `@ExecutorRegistry([(JobType, ExecutorType), ...])`
  final List<Object> entries;

  const ExecutorRegistry(this.entries);
}
