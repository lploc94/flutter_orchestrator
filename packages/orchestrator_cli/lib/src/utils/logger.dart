import 'package:mason_logger/mason_logger.dart';

/// Log level for CLI output
enum CliLogLevel {
  quiet,
  normal,
  verbose,
}

/// CLI Logger wrapper using mason_logger
class CliLogger {
  final Logger _logger;
  final CliLogLevel _level;

  CliLogger({CliLogLevel level = CliLogLevel.normal})
      : _logger = Logger(level: _toMasonLevel(level)),
        _level = level;

  static Level _toMasonLevel(CliLogLevel level) {
    switch (level) {
      case CliLogLevel.quiet:
        return Level.error;
      case CliLogLevel.normal:
        return Level.info;
      case CliLogLevel.verbose:
        return Level.verbose;
    }
  }

  /// Log info message
  void info(String message) => _logger.info(message);

  /// Log success message (green checkmark)
  void success(String message) => _logger.success(message);

  /// Log warning message (yellow)
  void warn(String message) => _logger.warn(message);

  /// Log error message (red)
  void error(String message) => _logger.err(message);

  /// Log detail message (only visible in verbose mode)
  void detail(String message) => _logger.detail(message);

  /// Log a dimmed/muted message (always visible but subtle)
  void muted(String message) => _logger.info(darkGray.wrap(message) ?? message);

  /// Show progress spinner
  Progress progress(String message) => _logger.progress(message);

  /// Prompt for confirmation
  bool confirm(String message, {bool defaultValue = false}) =>
      _logger.confirm(message, defaultValue: defaultValue);

  /// Show a list of choices
  String chooseOne(
    String message, {
    required List<String> choices,
    String? defaultValue,
  }) =>
      _logger.chooseOne(
        message,
        choices: choices,
        defaultValue: defaultValue,
      );

  /// Prompt for input
  String prompt(String message, {String? defaultValue}) =>
      _logger.prompt(message, defaultValue: defaultValue);

  /// Show alert message
  void alert(String message) => _logger.alert(message);

  /// Write raw message without formatting
  void write(String message) => _logger.write(message);

  /// Check if verbose mode is enabled
  bool get isVerbose => _level == CliLogLevel.verbose;
}
