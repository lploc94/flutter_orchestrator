import 'package:flutter/foundation.dart';
import 'package:orchestrator_core/orchestrator_core.dart';

part 'test_orchestrator.g.dart';

// Simple test state
class TestState {
  static const _sentinel = Object();

  final String? username;
  final bool isLoggedIn;

  TestState({this.username, this.isLoggedIn = false});

  TestState copyWith({Object? username = _sentinel, bool? isLoggedIn}) =>
      TestState(
        username: username == _sentinel ? this.username : username as String?,
        isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      );
}

// Custom events for testing
class UserLoggedIn extends BaseEvent {
  final String username;
  UserLoggedIn(super.correlationId, this.username);
}

class UserLoggedOut extends BaseEvent {
  UserLoggedOut(super.correlationId);
}

class DataRefreshed extends BaseEvent {
  final Map<String, dynamic> payload;
  DataRefreshed(super.correlationId, this.payload);
}

// Test orchestrator with @OnEvent annotations
@Orchestrator()
class TestOrchestrator extends BaseOrchestrator<TestState>
    with _$TestOrchestratorEventRouting {
  TestOrchestrator() : super(TestState());

  @override
  @OnEvent(UserLoggedIn)
  void _handleLogin(UserLoggedIn event) {
    emit(state.copyWith(username: event.username, isLoggedIn: true));
  }

  @override
  @OnEvent(UserLoggedOut)
  void _handleLogout(UserLoggedOut event) {
    emit(state.copyWith(username: null, isLoggedIn: false));
  }

  @override
  @OnEvent(DataRefreshed, passive: true)
  void _handleDataRefresh(DataRefreshed event) {
    // Handle passive event from other orchestrators
    // ignore: avoid_print
    debugPrint('Data refreshed: ${event.payload}');
  }
}
