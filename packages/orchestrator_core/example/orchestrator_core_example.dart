// Copyright (c) 2024, Flutter Orchestrator
// https://github.com/lploc94/flutter_orchestrator
//
// SPDX-License-Identifier: MIT

/// Example demonstrating the core Orchestrator pattern.
///
/// This example shows how to:
/// 1. Define a Job
/// 2. Create an Executor
/// 3. Set up an Orchestrator
/// 4. Dispatch jobs and handle results
library;

import 'dart:async';
import 'package:orchestrator_core/orchestrator_core.dart';

// ============ 1. Define Jobs ============

/// A job to fetch user data by ID.
class FetchUserJob extends BaseJob {
  /// The user ID to fetch.
  final String userId;

  /// Creates a [FetchUserJob] for the given [userId].
  FetchUserJob(this.userId) : super(id: generateJobId('user'));
}

/// A job to update a user's name.
class UpdateUserNameJob extends BaseJob {
  /// The user ID to update.
  final String userId;

  /// The new name for the user.
  final String newName;

  /// Creates an [UpdateUserNameJob].
  UpdateUserNameJob(this.userId, this.newName)
      : super(id: generateJobId('update-user'));
}

// ============ 2. Create Executors ============

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

// ============ 3. Create Orchestrator ============

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
class UserOrchestrator extends BaseOrchestrator<UserState> {
  /// Creates a [UserOrchestrator].
  UserOrchestrator() : super(const UserState());

  /// Load user by ID.
  void loadUser(String userId) {
    emit(state.copyWith(isLoading: true));
    dispatch(FetchUserJob(userId));
  }

  /// Update user's name.
  void updateName(String userId, String newName) {
    emit(state.copyWith(isLoading: true));
    dispatch(UpdateUserNameJob(userId, newName));
  }

  @override
  void onActiveSuccess(JobSuccessEvent event) {
    final data = event.data;
    if (data is Map<String, dynamic>) {
      emit(state.copyWith(user: data, isLoading: false));
    } else if (data == true) {
      emit(state.copyWith(isLoading: false));
    }
  }

  @override
  void onActiveFailure(JobFailureEvent event) {
    emit(state.copyWith(isLoading: false, error: event.error.toString()));
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

  // 4. Dispatch a job
  print('Fetching user...');
  orchestrator.loadUser('123');

  // Wait for completion
  await Future.delayed(Duration(seconds: 1));

  // 5. Cleanup
  orchestrator.dispose();

  print('Done!');
}
