import 'package:flutter/foundation.dart';

/// Log entry with timing information.
class LogEntry {
  final DateTime timestamp;
  final String source; // 'traditional' or 'orchestrator'
  final String event;
  final String? details;
  final Duration? duration;
  final LogLevel level;

  LogEntry({
    required this.timestamp,
    required this.source,
    required this.event,
    this.details,
    this.duration,
    this.level = LogLevel.info,
  });

  String get formattedTime {
    final ms = timestamp.millisecondsSinceEpoch % 100000;
    return ms.toString().padLeft(5, '0');
  }

  String get icon {
    switch (level) {
      case LogLevel.info:
        return 'ℹ️';
      case LogLevel.success:
        return '✅';
      case LogLevel.warning:
        return '⚠️';
      case LogLevel.error:
        return '❌';
      case LogLevel.timing:
        return '⏱️';
      case LogLevel.race:
        return '🏃';
    }
  }

  @override
  String toString() {
    final durationStr = duration != null ? ' [${duration!.inMilliseconds}ms]' : '';
    final detailStr = details != null ? ': $details' : '';
    return '[$formattedTime] $icon [$source] $event$durationStr$detailStr';
  }
}

enum LogLevel { info, success, warning, error, timing, race }

/// Centralized logging service for comparing Traditional vs Orchestrator.
class LogService extends ChangeNotifier {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  final List<LogEntry> _logs = [];
  List<LogEntry> get logs => List.unmodifiable(_logs);

  // Separate logs by source
  List<LogEntry> get traditionalLogs =>
      _logs.where((l) => l.source == 'traditional').toList();
  List<LogEntry> get orchestratorLogs =>
      _logs.where((l) => l.source == 'orchestrator').toList();

  // Statistics
  int _traditionalApiCalls = 0;
  int _orchestratorApiCalls = 0;
  int _traditionalRaceConditions = 0;
  int _orchestratorCancellations = 0;

  int get traditionalApiCalls => _traditionalApiCalls;
  int get orchestratorApiCalls => _orchestratorApiCalls;
  int get traditionalRaceConditions => _traditionalRaceConditions;
  int get orchestratorCancellations => _orchestratorCancellations;

  // Timing trackers
  final Map<String, Stopwatch> _timers = {};

  /// Start timing an operation.
  void startTimer(String source, String operation) {
    final key = '$source:$operation';
    _timers[key] = Stopwatch()..start();
    log(source, 'Started: $operation', level: LogLevel.info);
  }

  /// Stop timing and log the result.
  Duration? stopTimer(String source, String operation, {bool success = true}) {
    final key = '$source:$operation';
    final timer = _timers.remove(key);
    if (timer == null) return null;

    timer.stop();
    final duration = timer.elapsed;

    log(
      source,
      'Completed: $operation',
      duration: duration,
      level: success ? LogLevel.success : LogLevel.error,
    );

    // Track API calls
    if (operation.contains('fetch') || operation.contains('search')) {
      if (source == 'traditional') {
        _traditionalApiCalls++;
      } else {
        _orchestratorApiCalls++;
      }
    }

    return duration;
  }

  /// Log a race condition detected.
  void logRaceCondition(String source, String details) {
    if (source == 'traditional') {
      _traditionalRaceConditions++;
    }
    log(source, 'RACE CONDITION', details: details, level: LogLevel.race);
  }

  /// Log a cancellation.
  void logCancellation(String source, String operation) {
    if (source == 'orchestrator') {
      _orchestratorCancellations++;
    }
    log(source, 'Cancelled: $operation', level: LogLevel.warning);
  }

  /// Add a log entry.
  void log(
    String source,
    String event, {
    String? details,
    Duration? duration,
    LogLevel level = LogLevel.info,
  }) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      source: source,
      event: event,
      details: details,
      duration: duration,
      level: level,
    );

    _logs.add(entry);

    // Also print to console for debugging
    if (kDebugMode) {
      print(entry.toString());
    }

    notifyListeners();
  }

  /// Clear all logs and reset statistics.
  void clear() {
    _logs.clear();
    _timers.clear();
    _traditionalApiCalls = 0;
    _orchestratorApiCalls = 0;
    _traditionalRaceConditions = 0;
    _orchestratorCancellations = 0;
    notifyListeners();
  }

  /// Get a summary of the comparison.
  String getSummary() {
    return '''
📊 Comparison Summary:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Traditional:
  • API Calls: $_traditionalApiCalls
  • Race Conditions: $_traditionalRaceConditions

Orchestrator:
  • API Calls: $_orchestratorApiCalls
  • Cancellations: $_orchestratorCancellations
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
''';
  }
}
