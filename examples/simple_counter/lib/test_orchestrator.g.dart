// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'test_orchestrator.dart';

// **************************************************************************
// OrchestratorGenerator
// **************************************************************************

// ignore_for_file: unused_element
mixin _$TestOrchestratorEventRouting on BaseOrchestrator<TestState> {
  void _handleLogin(UserLoggedIn event);
  void _handleLogout(UserLoggedOut event);
  void _handleDataRefresh(DataRefreshed event);

  @override
  void onActiveEvent(BaseEvent event) {
    super.onActiveEvent(event);
    if (event is UserLoggedIn) {
      _handleLogin(event);
      return;
    }
    if (event is UserLoggedOut) {
      _handleLogout(event);
      return;
    }
  }

  @override
  void onPassiveEvent(BaseEvent event) {
    super.onPassiveEvent(event);
    if (event is DataRefreshed) {
      _handleDataRefresh(event);
      return;
    }
  }
}
