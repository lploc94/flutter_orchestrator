// Copyright (c) 2024, Flutter Orchestrator
// https://github.com/lploc94/flutter_orchestrator
//
// SPDX-License-Identifier: MIT

/// Example demonstrating the core Orchestrator pattern.
///
/// This example shows how to:
/// 1. Define domain events and jobs (using EventJob)
/// 2. Create executors
/// 3. Set up an orchestrator with unified `onEvent()` + `isJobRunning()` pattern
/// 4. Handle success, failure, and cross-orchestrator events
library;

import 'dart:async';
import 'package:orchestrator_core/orchestrator_core.dart';

// ============ 1. Define Domain Events ============

/// Event emitted when a user is successfully loaded.
class UserLoadedEvent extends BaseEvent {
  /// The loaded user data.
  final Map<String, dynamic> user;

  /// Creates a [UserLoadedEvent].
  UserLoadedEvent(super.correlationId, this.user);
}

/// Event emitted when a user is updated (from another orchestrator).
class UserUpdatedEvent extends BaseEvent {
  /// The updated user data.
  final Map<String, dynamic> user;

  /// Creates a [UserUpdatedEvent].
  UserUpdatedEvent(super.correlationId, this.user);
}

// ============ 2. Define Jobs (using EventJob) ============

/// A job to fetch user data by ID.
///
/// Uses [EventJob] to automatically emit [UserLoadedEvent] on success.
class FetchUserJob extends EventJob<Map<String, dynamic>, UserLoadedEvent> {
  /// The user ID to fetch.
  final String userId;

  /// Creates a [FetchUserJob] for the given [userId].
  FetchUserJob(this.userId) : super(id: generateJobId('user'));

  @override
  UserLoadedEvent createEventTyped(Map<String, dynamic> result) {
    return UserLoadedEvent(id, result);
  }
}

/// A simple job without domain event (uses JobSuccessEvent/JobFailureEvent).
class DeleteUserJob extends BaseJob {
  /// The user ID to delete.
  final String userId;

  /// Creates a [DeleteUserJob].
  DeleteUserJob(this.userId) : super(id: generateJobId('delete-user'));
}

// ============ 3. Create Executors ============

/// Executor that handles [FetchUserJob].
class FetchUserExecutor extends BaseExecutor<FetchUserJob> {
  @override
  Future<Map<String, dynamic>> process(FetchUserJob job) async {
    // Simulate API call
    await Future.delayed(Duration(milliseconds: 500));

    // Simulate error for user ID "error"
    if (job.userId == 'error') {
      throw Exception('User not found: ${job.userId}');
    }

    return {
      'id': job.userId,
      'name': 'John Doe',
      'email': 'john@example.com',
    };
  }
}

/// Executor that handles [DeleteUserJob].
class DeleteUserExecutor extends BaseExecutor<DeleteUserJob> {
  @override
  Future<bool> process(DeleteUserJob job) async {
    await Future.delayed(Duration(milliseconds: 300));
    return true;
  }
}

// ============ 4. Define State ============

/// State for the user feature.
class UserState {
  /// Whether data is loading.
  final bool isLoading;

  /// The user data, if loaded.
  final Map<String, dynamic>? user;

  /// Error message, if any.
  final String? error;

  /// Creates a [UserState].
  const UserState({this.isLoading = false, this.user, this.error});

  /// Creates a copy with updated values.
  UserState copyWith({
    bool? isLoading,
    Map<String, dynamic>? user,
    String? error,
  }) =>
      UserState(
        isLoading: isLoading ?? this.isLoading,
        user: user ?? this.user,
        error: error,
      );

  @override
  String toString() =>
      'UserState(isLoading: $isLoading, user: $user, error: $error)';
}

// ============ 5. Create Orchestrator ============

/// Orchestrator for the user feature.
///
/// Demonstrates the v0.6.0 unified `onEvent()` pattern with `isJobRunning()`.
class UserOrchestrator extends BaseOrchestrator<UserState> {
  /// Creates a [UserOrchestrator].
  UserOrchestrator() : super(const UserState());

  /// Load user by ID.
  JobHandle<Map<String, dynamic>> loadUser(String userId) {
    emit(state.copyWith(isLoading: true, error: null));
    return dispatch(FetchUserJob(userId));
  }

  /// Delete user by ID.
  JobHandle<bool> deleteUser(String userId) {
    emit(state.copyWith(isLoading: true, error: null));
    return dispatch(DeleteUserJob(userId));
  }

  /// Unified event handler for all domain events.
  ///
  /// Key patterns:
  /// - Use `isJobRunning(correlationId)` to check if event is from OUR job
  /// - Use pattern matching with `when` clause for filtering
  /// - Handle both domain events (UserLoadedEvent) and generic events (JobFailureEvent)
  @override
  void onEvent(BaseEvent event) {
    switch (event) {
      // ========== OUR JOBS: Domain Events ==========
      // Handle UserLoadedEvent from our FetchUserJob
      case UserLoadedEvent e when isJobRunning(e.correlationId):
        emit(state.copyWith(user: e.user, isLoading: false));

      // ========== OUR JOBS: Generic Success (for BaseJob) ==========
      // Handle success from DeleteUserJob (which uses BaseJob, not EventJob)
      case JobSuccessEvent e when isJobRunning(e.correlationId):
        // For BaseJob, success data is in e.data
        emit(state.copyWith(isLoading: false));

      // ========== OUR JOBS: Failure ==========
      // Handle any failure from our jobs
      case JobFailureEvent e when isJobRunning(e.correlationId):
        emit(state.copyWith(
          isLoading: false,
          error: e.error.toString(),
        ));

      // ========== CROSS-ORCHESTRATOR: Domain Events ==========
      // Handle UserUpdatedEvent from OTHER orchestrators
      // (no isJobRunning check - we want ALL updates)
      case UserUpdatedEvent e:
        emit(state.copyWith(user: e.user));

      // Ignore all other events
      default:
        break;
    }
  }
}

// ============ 6. Simulating Cross-Orchestrator Communication ============

/// Another orchestrator that updates users.
///
/// When this updates a user, UserOrchestrator will receive the event.
class AdminOrchestrator extends BaseOrchestrator<String> {
  AdminOrchestrator() : super('idle');

  /// Simulate admin updating a user (emits UserUpdatedEvent).
  void updateUser(String userId, String newName) {
    final event = UserUpdatedEvent(
      generateJobId('admin'),
      {'id': userId, 'name': newName, 'email': 'updated@example.com'},
    );
    // Emit directly to global bus (simulating another service updating user)
    SignalBus.instance.emit(event);
    emit('Updated user: $userId');
  }
}

// ============ Main ============

/// Entry point for the example.
void main() async {
  print('=== Orchestrator Core v0.6.0 Example ===\n');

  // 1. Register Executors
  final dispatcher = Dispatcher();
  dispatcher.register<FetchUserJob>(FetchUserExecutor());
  dispatcher.register<DeleteUserJob>(DeleteUserExecutor());

  // 2. Create Orchestrators
  final userOrchestrator = UserOrchestrator();
  final adminOrchestrator = AdminOrchestrator();

  // 3. Listen to state changes
  userOrchestrator.stream.listen((state) {
    print('[UserOrchestrator] State: $state');
  });

  // ========== SCENARIO 1: Successful Load ==========
  print('\n--- Scenario 1: Load User (Success) ---');
  final handle1 = userOrchestrator.loadUser('123');
  await handle1.future;
  await Future.delayed(Duration(milliseconds: 100));

  // ========== SCENARIO 2: Failed Load ==========
  print('\n--- Scenario 2: Load User (Failure) ---');
  final handle2 = userOrchestrator.loadUser('error');
  try {
    await handle2.future;
  } catch (e) {
    print('[Main] Caught error: $e');
  }
  await Future.delayed(Duration(milliseconds: 100));

  // ========== SCENARIO 3: Cross-Orchestrator Event ==========
  print('\n--- Scenario 3: Admin Updates User (Cross-Orchestrator) ---');
  adminOrchestrator.updateUser('123', 'Jane Doe');
  await Future.delayed(Duration(milliseconds: 100));

  // 4. Cleanup
  userOrchestrator.dispose();
  adminOrchestrator.dispose();

  print('\n=== Done! ===');
}
