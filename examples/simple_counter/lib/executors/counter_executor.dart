// lib/executors/counter_executor.dart
// Executors contain business logic - pure Dart, no Flutter dependencies

import 'package:orchestrator_core/orchestrator_core.dart';
import '../jobs/counter_jobs.dart';

/// Executor for IncrementJob
/// Simulates async operation (could be API call, database update, etc.)
class IncrementExecutor extends BaseExecutor<IncrementJob> {
  // Simulated database/state
  int _count = 0;

  @override
  Future<int> process(IncrementJob job) async {
    // Simulate async operation (e.g., API call, DB write)
    await Future.delayed(const Duration(milliseconds: 300));

    _count++;
    return _count;
  }
}

/// Executor for DecrementJob
class DecrementExecutor extends BaseExecutor<DecrementJob> {
  int _count = 0;

  @override
  Future<int> process(DecrementJob job) async {
    await Future.delayed(const Duration(milliseconds: 300));

    _count--;
    return _count;
  }
}

/// Executor for ResetJob
class ResetExecutor extends BaseExecutor<ResetJob> {
  @override
  Future<int> process(ResetJob job) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return 0;
  }
}

/// Shared counter service that all executors can use
/// This demonstrates dependency injection pattern
class CounterService {
  int _count = 0;

  int get count => _count;

  int increment() => ++_count;
  int decrement() => --_count;
  int reset() => _count = 0;
}

/// Alternative: Executors with injected service
class IncrementWithServiceExecutor extends BaseExecutor<IncrementJob> {
  final CounterService _service;

  IncrementWithServiceExecutor(this._service);

  @override
  Future<int> process(IncrementJob job) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _service.increment();
  }
}

class DecrementWithServiceExecutor extends BaseExecutor<DecrementJob> {
  final CounterService _service;

  DecrementWithServiceExecutor(this._service);

  @override
  Future<int> process(DecrementJob job) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _service.decrement();
  }
}

class ResetWithServiceExecutor extends BaseExecutor<ResetJob> {
  final CounterService _service;

  ResetWithServiceExecutor(this._service);

  @override
  Future<int> process(ResetJob job) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _service.reset();
  }
}
