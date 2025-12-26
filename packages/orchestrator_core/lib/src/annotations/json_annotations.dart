/// Annotation to customize JSON serialization for a field.
class JsonKey {
  /// The key name to use in the JSON map.
  final String? name;

  /// Whether to include this field in serialization.
  final bool includeIfNull;

  /// The default value to use if the key is missing in the JSON map.
  final Object? defaultValue;

  const JsonKey({
    this.name,
    this.includeIfNull = true,
    this.defaultValue,
  });
}

/// Annotation to ignore a field during serialization.
class JsonIgnore {
  const JsonIgnore();
}
