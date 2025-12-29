// lib/orchestrator/test_orchestrator.dart
// Test file for @OrchestratorProvider code generation

// ignore_for_file: unused_import
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orchestrator_riverpod/orchestrator_riverpod.dart';

part 'test_orchestrator.g.dart';

/// State for the test orchestrator
class TestState {
  final int count;
  final AsyncStatus status;

  const TestState({this.count = 0, this.status = AsyncStatus.initial});

  TestState copyWith({int? count, AsyncStatus? status}) {
    return TestState(
      count: count ?? this.count,
      status: status ?? this.status,
    );
  }
}

/// Test orchestrator to verify @OrchestratorProvider code generation.
/// The generator will create:
/// `final testOrchestratorProvider = NotifierProvider<TestOrchestrator, TestState>(...);`
@OrchestratorProvider()
class TestOrchestrator extends OrchestratorNotifier<TestState> {
  @override
  TestState buildState() => const TestState();

  void increment() {
    state = state.copyWith(count: state.count + 1);
  }
}

/// Test with custom name
/// The generator will create:
/// `final customNameProvider = NotifierProvider<CustomNameOrchestrator, TestState>(...);`
@OrchestratorProvider(name: 'customNameProvider')
class CustomNameOrchestrator extends OrchestratorNotifier<TestState> {
  @override
  TestState buildState() => const TestState();
}
