import '../utils/logger.dart';

/// Saga Pattern for orchestrated workflows with rollback support.
///
/// Used in Orchestrator Scripts to coordinate a sequence of Jobs.
/// If any Job in the sequence fails, [SagaFlow] will rollback (compensate)
/// all previously successful Jobs in reverse order (LIFO).
///
/// Example:
/// ```dart
/// final saga = SagaFlow(name: 'TransferAsset');
///
/// try {
///   final deducted = await saga.run(
///     action: () => deductFromSource(amount),
///     compensate: (result) => refundSource(result),
///   );
///
///   await saga.run(
///     action: () => addToTarget(amount),
///     compensate: (result) => deductFromTarget(result),
///   );
///
///   saga.commit(); // Success - clear compensations
/// } catch (e) {
///   await saga.rollback(); // Failure - compensate all
///   rethrow;
/// }
/// ```
class SagaFlow {
  final List<Future<void> Function()> _compensations = [];

  /// Optional name for debugging purposes.
  final String? name;

  /// Logger for saga operations.
  OrchestratorLogger get _logger => OrchestratorConfig.logger;

  /// Creates a new SagaFlow instance.
  ///
  /// [name] is optional but recommended for debugging complex workflows.
  SagaFlow({this.name});

  /// Number of registered compensations.
  int get stepCount => _compensations.length;

  /// Execute a step and register its compensation.
  ///
  /// [action]: The main logic to execute (e.g., dispatch a Job).
  /// [compensate]: The rollback function to call if later steps fail.
  ///
  /// The [compensate] function receives the result of [action] so it can
  /// properly undo the operation (e.g., delete the created entity).
  ///
  /// If [action] throws, the compensation is NOT registered (since the
  /// action didn't succeed), and the error is rethrown.
  Future<T> run<T>({
    required Future<T> Function() action,
    required Future<void> Function(T result) compensate,
  }) async {
    final stepName = name != null
        ? '[$name] Step ${stepCount + 1}'
        : 'Step ${stepCount + 1}';
    _logger.debug('🎬 [Saga] $stepName: Executing...');

    try {
      final result = await action();

      // Register compensation with captured result
      _compensations.add(() async {
        _logger.debug('↩️ [Saga] $stepName: Compensating...');
        await compensate(result);
      });

      _logger.debug('✅ [Saga] $stepName: Success');
      return result;
    } catch (e) {
      _logger.error('❌ [Saga] $stepName: Failed', e, StackTrace.current);
      // If this step fails, don't add its compensation
      // (nothing to rollback for a failed action)
      rethrow;
    }
  }

  /// Rollback all successful steps in LIFO (Last-In-First-Out) order.
  ///
  /// Call this in the `catch` block of your orchestrator script.
  /// Each compensation is executed in reverse order of registration.
  ///
  /// If a compensation fails, the error is logged but rollback continues
  /// to attempt remaining compensations (best-effort).
  Future<void> rollback() async {
    if (_compensations.isEmpty) {
      _logger.debug('🛑 [Saga] ${name ?? 'Unnamed'}: Nothing to rollback');
      return;
    }

    _logger.info(
      '🛑 [Saga] ${name ?? 'Unnamed'}: Rolling back ${_compensations.length} steps...',
    );

    int successCount = 0;
    int failCount = 0;

    // Execute in reverse order (LIFO)
    for (final compensate in _compensations.reversed) {
      try {
        await compensate();
        successCount++;
      } catch (e, stack) {
        failCount++;
        // Critical: Log but continue - don't let one failure prevent other rollbacks
        _logger.error(
          '💀 [Saga] ${name ?? 'Unnamed'}: Compensation failed (continuing with others)',
          e,
          stack,
        );
      }
    }

    _compensations.clear();

    if (failCount > 0) {
      _logger.warning(
        '⚠️ [Saga] ${name ?? 'Unnamed'}: Rollback completed with errors '
        '($successCount success, $failCount failed)',
      );
    } else {
      _logger.info(
        '✅ [Saga] ${name ?? 'Unnamed'}: Rollback completed ($successCount steps)',
      );
    }
  }

  /// Clear all compensations without executing them.
  ///
  /// Call this when all steps succeed and you want to "commit" the saga.
  /// After calling [commit], [rollback] will have no effect.
  void commit() {
    if (_compensations.isEmpty) return;

    _logger.debug(
      '✅ [Saga] ${name ?? 'Unnamed'}: Committed (${_compensations.length} steps)',
    );
    _compensations.clear();
  }

  /// Check if any steps have been registered.
  bool get hasSteps => _compensations.isNotEmpty;
}
