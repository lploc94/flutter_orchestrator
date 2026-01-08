// Copyright (c) 2024, Flutter Orchestrator
// https://github.com/lploc94/flutter_orchestrator
//
// SPDX-License-Identifier: MIT

/// Example demonstrating the core Orchestrator pattern.
///
/// This example shows how to:
/// 1. Define a Job (EventJob for domain events)
/// 2. Create an Executor
/// 3. Set up an Orchestrator with unified event handling
/// 4. Dispatch jobs and handle results
library;

import 'dart:async';
import 'package:orchestrator_core/orchestrator_core.dart';

// ============ 1. Define Domain Events ============

/// Event emitted when a user is loaded.
class UserLoadedEvent extends BaseEvent {
  /// The loaded user data.
  final Map<String, dynamic> user;

  /// Creates a [UserLoadedEvent].
  UserLoadedEvent(super.correlationId, this.user);
}

/// Event emitted when a user is updated.
class UserUpdatedEvent extends BaseEvent {
  /// The updated user ID.
  final String userId;

  /// Creates a [UserUpdatedEvent].
  UserUpdatedEvent(super.correlationId, this.userId);
}

// ============ 2. Define Jobs ============

/// A job to fetch user data by ID.
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

/// A job to update a user's name.
class UpdateUserNameJob extends EventJob<bool, UserUpdatedEvent> {
  /// The user ID to update.
  final String userId;

  /// The new name for the user.
  final String newName;

  /// Creates an [UpdateUserNameJob].
  UpdateUserNameJob(this.userId, this.newName)
      : super(id: generateJobId('update-user'));

  @override
  UserUpdatedEvent createEventTyped(bool result) {
    return UserUpdatedEvent(id, userId);
  }
}

// ============ 3. Create Executors ============

/// Executor that handles [FetchUserJob].
class FetchUserExecutor extends BaseExecutor<FetchUserJob> {
  @override
  Future<Map<String, dynamic>> process(FetchUserJob job) async {
    // Simulate API call
    await Future.delayed(Duration(milliseconds: 500));

    return {
      'id': job.userId,
      'name': 'John Doe',
      'email': 'john@example.com',
    };
  }
}

/// Executor that handles [UpdateUserNameJob].
class UpdateUserNameExecutor extends BaseExecutor<UpdateUserNameJob> {
  @override
  Future<bool> process(UpdateUserNameJob job) async {
    // Simulate API call
    await Future.delayed(Duration(milliseconds: 300));
    return true;
  }
}

// ============ 4. Create Orchestrator ============

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
}

/// Orchestrator for the user feature.
///
/// Uses the unified `onEvent` handler for all domain events.
class UserOrchestrator extends BaseOrchestrator<UserState> {
  /// Creates a [UserOrchestrator].
  UserOrchestrator() : super(const UserState());

  /// Load user by ID.
  ///
  /// Returns a [JobHandle] that can be used to await the result directly.
  JobHandle<Map<String, dynamic>> loadUser(String userId) {
    emit(state.copyWith(isLoading: true));
    return dispatch(FetchUserJob(userId));
  }

  /// Update user's name.
  JobHandle<bool> updateName(String userId, String newName) {
    emit(state.copyWith(isLoading: true));
    return dispatch(UpdateUserNameJob(userId, newName));
  }

  /// Unified event handler for all domain events.
  ///
  /// This replaces the old onActiveSuccess/onActiveFailure pattern.
  @override
  void onEvent(BaseEvent event) {
    switch (event) {
      case UserLoadedEvent e:
        emit(state.copyWith(user: e.user, isLoading: false));
      case UserUpdatedEvent _:
        emit(state.copyWith(isLoading: false));
      default:
        // Ignore other events
        break;
    }
  }
}

// ============ Main ============

/// Entry point for the example.
void main() async {
  // 1. Register Executors
  final dispatcher = Dispatcher();
  dispatcher.register<FetchUserJob>(FetchUserExecutor());
  dispatcher.register<UpdateUserNameJob>(UpdateUserNameExecutor());

  // 2. Create Orchestrator
  final orchestrator = UserOrchestrator();

  // 3. Listen to state changes
  orchestrator.stream.listen((state) {
    if (state.isLoading) {
      print('Loading...');
    } else if (state.error != null) {
      print('Error: ${state.error}');
    } else if (state.user != null) {
      print('User loaded: ${state.user}');
    }
  });

  // 4. Dispatch a job and await result directly
  print('Fetching user...');
  final handle = orchestrator.loadUser('123');

  // Option A: Await result directly via JobHandle
  try {
    final result = await handle.future;
    print('Direct result: ${result.data} (source: ${result.source})');
  } catch (e) {
    print('Error: $e');
  }

  // 5. Cleanup
  orchestrator.dispose();

  print('Done!');
}
