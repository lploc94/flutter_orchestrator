import '../models/event.dart';
import '../infra/cache/cache_provider.dart';
import '../infra/cache/in_memory_cache_provider.dart';

import '../infra/offline/connectivity_provider.dart';
import '../infra/offline/offline_manager.dart';

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

  /// Maximum events processed per second before triggering Circuit Breaker.
  /// Default: 50. Set to higher value for high-frequency apps (e.g. 100).
  static int maxEventsPerSecond = 50;

  static final Map<Type, int> _typeLimits = {};

  /// Set specific limit for an Event Type.
  /// Example: `OrchestratorConfig.setTypeLimit<MyHighFreqEvent>(1000);`
  static void setTypeLimit<T extends BaseEvent>(int limit) {
    _typeLimits[T] = limit;
  }

  /// Get limit for a specific type (or default if not set).
  static int getLimit(Type type) {
    return _typeLimits[type] ?? maxEventsPerSecond;
  }

  static OrchestratorLogger get logger => _logger;

  static void setLogger(OrchestratorLogger logger) {
    _logger = logger;
  }

  /// Enable debug logging to console.
  static void enableDebugLogging() {
    _logger = ConsoleLogger(minLevel: LogLevel.debug);
  }

  // --- Cache Configuration ---

  static CacheProvider _cacheProvider = InMemoryCacheProvider();

  static CacheProvider get cacheProvider => _cacheProvider;

  static void setCacheProvider(CacheProvider provider) {
    _cacheProvider = provider;
  }

  // --- Network Queue Configuration ---

  static ConnectivityProvider _connectivityProvider = AlwaysOnlineProvider();

  static ConnectivityProvider get connectivityProvider => _connectivityProvider;

  static void setConnectivityProvider(ConnectivityProvider provider) {
    _connectivityProvider = provider;
  }

  static NetworkQueueManager? _networkQueueManager;

  static NetworkQueueManager? get networkQueueManager => _networkQueueManager;

  static void setNetworkQueueManager(NetworkQueueManager manager) {
    _networkQueueManager = manager;
  }
}
