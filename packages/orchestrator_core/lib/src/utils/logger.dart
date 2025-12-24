/// Logging levels for the Orchestrator system.
enum LogLevel { debug, info, warning, error }

/// Abstract logger interface for custom implementations.
abstract class OrchestratorLogger {
  void log(
    LogLevel level,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]);

  void debug(String message) => log(LogLevel.debug, message);
  void info(String message) => log(LogLevel.info, message);
  void warning(String message, [Object? error]) =>
      log(LogLevel.warning, message, error);
  void error(String message, Object error, [StackTrace? stackTrace]) =>
      log(LogLevel.error, message, error, stackTrace);
}

/// Default console logger.
class ConsoleLogger extends OrchestratorLogger {
  final LogLevel minLevel;

  ConsoleLogger({this.minLevel = LogLevel.info});

  @override
  void log(
    LogLevel level,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    if (level.index < minLevel.index) return;

    final prefix = '[${level.name.toUpperCase()}]';
    final timestamp = DateTime.now().toIso8601String();

    print('$timestamp $prefix $message');
    if (error != null) print('  Error: $error');
    if (stackTrace != null) print('  Stack: $stackTrace');
  }
}

/// Silent logger for production or testing.
class NoOpLogger extends OrchestratorLogger {
  @override
  void log(
    LogLevel level,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    // Do nothing
  }
}

/// Global logger instance.
class OrchestratorConfig {
  static OrchestratorLogger _logger = NoOpLogger();

  static OrchestratorLogger get logger => _logger;

  static void setLogger(OrchestratorLogger logger) {
    _logger = logger;
  }

  /// Enable debug logging to console.
  static void enableDebugLogging() {
    _logger = ConsoleLogger(minLevel: LogLevel.debug);
  }
}
