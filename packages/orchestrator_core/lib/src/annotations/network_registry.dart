/// Annotation to define the central registry of network jobs.
///
/// Usage:
/// ```dart
/// @NetworkRegistry([
///   SendMessageJob,
///   LikePostJob,
/// ])
/// void setupNetworkRegistry();
/// ```
class NetworkRegistry {
  final List<Type> jobs;
  const NetworkRegistry(this.jobs);
}
