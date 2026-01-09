import '../models/job.dart';
import '../models/event.dart';
import '../models/data_source.dart';

/// Global observer for logging and monitoring all orchestrator activity.
///
/// Inspired by BlocObserver from flutter_bloc, this provides a centralized
/// place to log job lifecycle events without polluting the domain event stream.
///
/// ## Usage
///
/// ```dart
/// void main() {
///   OrchestratorObserver.instance = MyAppObserver();
///   runApp(MyApp());
/// }
///
/// class MyAppObserver extends OrchestratorObserver {
///   @override
///   void onJobStart(EventJob job) {
///     print('Job started: ${job.runtimeType}');
///   }
///
///   @override
///   void onJobError(EventJob job, Object error, StackTrace stack) {
///     // Send to Sentry, Crashlytics, etc.
///     Sentry.captureException(error, stackTrace: stack);
///   }
///
///   @override
///   void onEvent(BaseEvent event) {
///     // Log all domain events for debugging
///     debugPrint('Event: ${event.runtimeType}');
///   }
/// }
/// ```
///
/// ## Design Rationale
///
/// This observer pattern separates concerns:
/// - **Domain Events**: Business state changes (user-defined)
/// - **Observer**: Logging, monitoring, analytics (framework-level)
///
/// Errors are NOT emitted as events because:
/// 1. Errors represent something that DIDN'T happen (not a state change)
/// 2. Caller can handle errors via JobHandle.future.catchError()
/// 3. Global logging should not affect domain event flow
abstract class OrchestratorObserver {
  /// Global singleton instance.
  ///
  /// Set this in your app's main() to enable global observation.
  /// If null, no observation occurs (zero overhead).
  static OrchestratorObserver? instance;

  /// Called when any job starts execution.
  ///
  /// This is called before any processing begins, useful for:
  /// - Logging job initiation
  /// - Performance timing start
  /// - Debug tracing
  void onJobStart(EventJob job) {}

  /// Called when any job completes successfully.
  ///
  /// Parameters:
  /// - [job]: The completed job
  /// - [result]: The result data
  /// - [source]: Where the data came from (fresh, cached, optimistic)
  void onJobSuccess(EventJob job, dynamic result, DataSource source) {}

  /// Called when any job fails with an error.
  ///
  /// This is for logging/monitoring only - it cannot affect the error flow.
  /// The error will still propagate to the caller via JobHandle.
  ///
  /// Use this for:
  /// - Sending errors to crash reporting (Sentry, Crashlytics)
  /// - Analytics tracking
  /// - Debug logging
  void onJobError(EventJob job, Object error, StackTrace stack) {}

  /// Called when any domain event is emitted.
  ///
  /// This receives ALL domain events from ALL orchestrators,
  /// useful for:
  /// - Event logging
  /// - Debug tracing
  /// - Analytics
  void onEvent(BaseEvent event) {}
}
