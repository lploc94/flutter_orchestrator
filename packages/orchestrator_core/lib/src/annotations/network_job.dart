/// Annotation to mark a class as a Network Job.
///
/// This annotation signals the [NetworkJobGenerator] to generate serialization
/// code (toJson, fromJson, etc.) for the annotated class.
class NetworkJob {
  /// Whether to generate serialization logic (toJson/fromJson).
  ///
  /// Defaults to `true` for forward compatibility.
  /// If set to `false`, the generator will skip this class.
  final bool generateSerialization;

  const NetworkJob({
    this.generateSerialization = true,
  });
}
