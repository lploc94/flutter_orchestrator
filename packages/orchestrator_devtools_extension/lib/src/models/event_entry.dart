/// Represents an event entry received from the orchestrator.
class EventEntry {
  final String type;
  final String correlationId;
  final DateTime timestamp;
  final String? jobType;
  final Map<String, dynamic> rawData;

  EventEntry({
    required this.type,
    required this.correlationId,
    required this.timestamp,
    this.jobType,
    required this.rawData,
  });

  /// Create from JSON received via postEvent.
  factory EventEntry.fromJson(Map<String, dynamic> json) {
    return EventEntry(
      type: json['type'] as String? ?? 'UnknownEvent',
      correlationId: json['correlationId'] as String? ?? 'unknown',
      timestamp:
          DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      jobType: json['jobType'] as String?,
      rawData: json,
    );
  }

  /// Get formatted details string for display.
  String get details {
    final buffer = StringBuffer();

    // Handle specific event types
    if (rawData.containsKey('data')) {
      buffer.write('Data: ${rawData['data']}');
    }
    if (rawData.containsKey('error')) {
      buffer.write('Error: ${rawData['error']}');
    }
    if (rawData.containsKey('progress')) {
      final progress = (rawData['progress'] as num?) ?? 0;
      buffer.write('Progress: ${(progress * 100).toStringAsFixed(1)}%');
    }
    if (rawData.containsKey('attempt')) {
      buffer.write('Attempt: ${rawData['attempt']}/${rawData['maxRetries']}');
    }
    if (rawData.containsKey('isPoisoned') && rawData['isPoisoned'] == true) {
      buffer.write(' [POISONED]');
    }

    return buffer.toString();
  }

  @override
  String toString() => 'EventEntry($type, $correlationId)';
}
