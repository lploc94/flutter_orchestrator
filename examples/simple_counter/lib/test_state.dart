import 'package:orchestrator_core/orchestrator_core.dart';

part 'test_state.g.dart';

/// Test state class with @GenerateAsyncState annotation
@GenerateAsyncState()
class TestUserState {
  final AsyncStatus status;
  final String? data;
  final Object? error;
  final String? username;

  const TestUserState({
    this.status = AsyncStatus.initial,
    this.data,
    this.error,
    this.username,
  });
}
