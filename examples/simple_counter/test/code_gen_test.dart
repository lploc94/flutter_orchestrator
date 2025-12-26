import 'package:flutter_test/flutter_test.dart';
import 'package:orchestrator_core/orchestrator_core.dart';
import 'package:simple_counter/test_job.dart';
import 'package:simple_counter/test_orchestrator.dart';
import 'package:simple_counter/test_state.dart';

void main() {
  group('Phase 1: Enhanced Code Generation Tests', () {
    test('Mock Test for compilation', () {
      expect(true, isTrue);
    });

    test('toJson generates correct map', () {
      final job = TestJob(id: '1', data: 'abc', count: 10, ignored: true);
      final map = job.toJson();
      expect(map['id'], '1');
      expect(map['data'], 'abc');
      expect(map['renamed_field'], 10);
      expect(map.containsKey('ignored'), false);
    });

    test('fromJson restores object', () {
      final map = {'id': '2', 'data': 'xyz', 'renamed_field': 20};
      final job = TestJob.fromJson(map);
      expect(job.id, '2');
      expect(job.data, 'xyz');
      expect(job.count, 20);
      expect(job.ignored, false);
    });

    test('ExecutorRegistry generates registerExecutors', () {
      registerExecutors('api');
    });
  });

  group('Phase 2: @OnEvent Tests', () {
    test('Orchestrator dispatches active events correctly', () {
      final orchestrator = TestOrchestrator();

      // Initial state
      expect(orchestrator.state.isLoggedIn, false);
      expect(orchestrator.state.username, isNull);

      // Simulate login event through onActiveEvent
      final loginEvent = UserLoggedIn('job-1', 'testuser');
      orchestrator.onActiveEvent(loginEvent);

      // State should have changed
      expect(orchestrator.state.isLoggedIn, true);
      expect(orchestrator.state.username, 'testuser');

      // Simulate logout event
      final logoutEvent = UserLoggedOut('job-2');
      orchestrator.onActiveEvent(logoutEvent);

      expect(orchestrator.state.isLoggedIn, false);
      expect(orchestrator.state.username, isNull);

      // Cleanup
      orchestrator.dispose();
    });

    test('Orchestrator dispatches passive events correctly', () {
      final orchestrator = TestOrchestrator();

      // Passive event should be handled
      final refreshEvent = DataRefreshed('job-3', {'key': 'value'});
      // This should not throw
      orchestrator.onPassiveEvent(refreshEvent);

      // Cleanup
      orchestrator.dispose();
    });

    test('Unhandled events do not cause issues', () {
      final orchestrator = TestOrchestrator();

      // Create a custom event that's not handled
      final genericEvent = JobStartedEvent('job-999');
      // Should not throw
      orchestrator.onActiveEvent(genericEvent);
      orchestrator.onPassiveEvent(genericEvent);

      orchestrator.dispose();
    });
  });

  group('Phase 2: @GenerateAsyncState Tests', () {
    test('copyWith works correctly', () {
      const state = TestUserState(
        status: AsyncStatus.initial,
        data: null,
        error: null,
        username: null,
      );

      final loadingState = state.copyWith(status: AsyncStatus.loading);
      expect(loadingState.status, AsyncStatus.loading);
      expect(loadingState.data, isNull);

      final successState = loadingState.copyWith(
        status: AsyncStatus.success,
        data: 'Hello',
        username: 'user1',
      );
      expect(successState.status, AsyncStatus.success);
      expect(successState.data, 'Hello');
      expect(successState.username, 'user1');
    });

    test('toLoading transitions state correctly', () {
      const state = TestUserState(status: AsyncStatus.initial);
      final loadingState = state.toLoading();
      expect(loadingState.status, AsyncStatus.loading);
    });

    test('toRefreshing transitions state correctly', () {
      const state = TestUserState(
        status: AsyncStatus.success,
        data: 'existing',
      );
      final refreshingState = state.toRefreshing();
      expect(refreshingState.status, AsyncStatus.refreshing);
      expect(refreshingState.data, 'existing'); // Data preserved
    });

    test('toSuccess transitions state correctly', () {
      const state = TestUserState(status: AsyncStatus.loading);
      final successState = state.toSuccess('my data');
      expect(successState.status, AsyncStatus.success);
      expect(successState.data, 'my data');
    });

    test('toFailure transitions state correctly', () {
      const state = TestUserState(status: AsyncStatus.loading);
      final failureState = state.toFailure('Error message');
      expect(failureState.status, AsyncStatus.failure);
      expect(failureState.error, 'Error message');
    });

    test('when pattern matching works', () {
      const initialState = TestUserState(status: AsyncStatus.initial);
      const loadingState = TestUserState(status: AsyncStatus.loading);
      const successState = TestUserState(
        status: AsyncStatus.success,
        data: 'data',
      );
      const failureState = TestUserState(
        status: AsyncStatus.failure,
        error: 'error',
      );

      expect(
        initialState.when(
          initial: () => 'initial',
          loading: () => 'loading',
          success: (data) => 'success: $data',
          failure: (error) => 'failure: $error',
        ),
        'initial',
      );

      expect(
        loadingState.when(
          initial: () => 'initial',
          loading: () => 'loading',
          success: (data) => 'success: $data',
          failure: (error) => 'failure: $error',
        ),
        'loading',
      );

      expect(
        successState.when(
          initial: () => 'initial',
          loading: () => 'loading',
          success: (data) => 'success: $data',
          failure: (error) => 'failure: $error',
        ),
        'success: data',
      );

      expect(
        failureState.when(
          initial: () => 'initial',
          loading: () => 'loading',
          success: (data) => 'success: $data',
          failure: (error) => 'failure: $error',
        ),
        'failure: error',
      );
    });

    test('maybeWhen pattern matching with orElse', () {
      const loadingState = TestUserState(status: AsyncStatus.loading);
      const successState = TestUserState(
        status: AsyncStatus.success,
        data: 'data',
      );

      // Only handle success, use orElse for everything else
      expect(
        loadingState.maybeWhen(
          success: (data) => 'got data: $data',
          orElse: () => 'fallback',
        ),
        'fallback',
      );

      expect(
        successState.maybeWhen(
          success: (data) => 'got data: $data',
          orElse: () => 'fallback',
        ),
        'got data: data',
      );
    });
  });
}
