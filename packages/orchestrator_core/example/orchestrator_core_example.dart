// Copyright (c) 2024, Flutter Orchestrator
// https://github.com/lploc94/flutter_orchestrator
//
// SPDX-License-Identifier: MIT

/// Example demonstrating the EventJob pattern in Orchestrator Core v0.6.0.
///
/// This example shows:
/// 1. Every job must extend `EventJob<TResult, TEvent>`
/// 2. Every job defines its own domain event
/// 3. Progress reporting via `JobHandle.progress`
/// 4. Error handling via `JobHandle.future`
/// 5. Cross-orchestrator event communication
library;

import 'dart:async';
import 'package:orchestrator_core/orchestrator_core.dart';

// ============ 1. Define Domain Events ============

/// Event emitted when a user is successfully loaded.
class UserLoadedEvent extends BaseEvent {
  final Map<String, dynamic> user;
  UserLoadedEvent(super.correlationId, this.user);
}

/// Event emitted when file upload completes.
class FileUploadedEvent extends BaseEvent {
  final String fileUrl;
  FileUploadedEvent(super.correlationId, this.fileUrl);
}

/// Event emitted when flaky API call completes.
class FlakyCompletedEvent extends BaseEvent {
  final String result;
  FlakyCompletedEvent(super.correlationId, this.result);
}

// ============ 2. Define Jobs ============

/// A job to fetch user data by ID.
class FetchUserJob extends EventJob<Map<String, dynamic>, UserLoadedEvent> {
  final String userId;

  FetchUserJob(this.userId);

  @override
  UserLoadedEvent createEventTyped(Map<String, dynamic> result) {
    return UserLoadedEvent(id, result);
  }
}

/// A job that simulates file upload with progress reporting.
class UploadFileJob extends EventJob<String, FileUploadedEvent> {
  final String fileName;
  final int fileSizeKb;

  UploadFileJob(this.fileName, {this.fileSizeKb = 100});

  @override
  FileUploadedEvent createEventTyped(String result) {
    return FileUploadedEvent(id, result);
  }
}

/// A job that may fail transiently (for retry demo).
class FlakyApiJob extends EventJob<String, FlakyCompletedEvent> {
  final int failCount;

  FlakyApiJob({
    this.failCount = 2,
    super.retryPolicy,
  });

  @override
  FlakyCompletedEvent createEventTyped(String result) {
    return FlakyCompletedEvent(id, result);
  }
}

// ============ 3. Create Executors ============

/// Executor that handles [FetchUserJob].
class FetchUserExecutor extends BaseExecutor<FetchUserJob> {
  @override
  Future<Map<String, dynamic>> process(FetchUserJob job) async {
    await Future.delayed(const Duration(milliseconds: 500));

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

/// Executor that handles [UploadFileJob] with progress reporting.
class UploadFileExecutor extends BaseExecutor<UploadFileJob> {
  @override
  Future<String> process(UploadFileJob job) async {
    final chunks = 10;
    for (var i = 1; i <= chunks; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      // Report progress via JobHandle
      reportProgress(
        job.id,
        progress: i / chunks,
        message: 'Uploading ${job.fileName}: ${i * 10}%',
      );
    }
    return 'https://cdn.example.com/${job.fileName}';
  }
}

/// Executor that simulates transient failures.
class FlakyApiExecutor extends BaseExecutor<FlakyApiJob> {
  int _attempts = 0;

  @override
  Future<String> process(FlakyApiJob job) async {
    _attempts++;
    await Future.delayed(const Duration(milliseconds: 200));

    if (_attempts <= job.failCount) {
      throw Exception('Transient failure #$_attempts');
    }

    return 'Success after $_attempts attempts';
  }
}

// ============ 4. Define Orchestrator State ============

class AppState {
  final Map<String, dynamic>? user;
  final String? uploadedFileUrl;
  final double uploadProgress;
  final String? error;

  AppState({
    this.user,
    this.uploadedFileUrl,
    this.uploadProgress = 0,
    this.error,
  });

  AppState copyWith({
    Map<String, dynamic>? user,
    String? uploadedFileUrl,
    double? uploadProgress,
    String? error,
  }) {
    return AppState(
      user: user ?? this.user,
      uploadedFileUrl: uploadedFileUrl ?? this.uploadedFileUrl,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      error: error ?? this.error,
    );
  }
}

// ============ 5. Define Orchestrator ============

class AppOrchestrator extends BaseOrchestrator<AppState> {
  AppOrchestrator() : super(AppState());

  /// Fetch a user by ID.
  JobHandle<Map<String, dynamic>> fetchUser(String userId) {
    return dispatch<Map<String, dynamic>>(FetchUserJob(userId));
  }

  /// Upload a file with progress tracking.
  JobHandle<String> uploadFile(String fileName) {
    return dispatch<String>(UploadFileJob(fileName));
  }

  /// Call a flaky API with retry.
  JobHandle<String> callFlakyApi() {
    return dispatch<String>(FlakyApiJob(
      failCount: 2,
      retryPolicy: RetryPolicy(
        maxRetries: 3,
        baseDelay: const Duration(milliseconds: 100),
      ),
    ));
  }

  @override
  void onEvent(BaseEvent event) {
    // Handle domain events using pattern matching
    switch (event) {
      case UserLoadedEvent e:
        emit(state.copyWith(user: e.user));
      case FileUploadedEvent e:
        emit(state.copyWith(
          uploadedFileUrl: e.fileUrl,
          uploadProgress: 1.0,
        ));
      case FlakyCompletedEvent e:
        print('Flaky API completed: ${e.result}');
      default:
        break;
    }
  }
}

// ============ 6. Main Demo ============

void main() async {
  print('=== Orchestrator Core v0.6.0 Demo ===\n');

  // Setup
  final dispatcher = Dispatcher()
    ..register(FetchUserExecutor())
    ..register(UploadFileExecutor())
    ..register(FlakyApiExecutor());

  final orchestrator = AppOrchestrator();

  // Listen to state changes
  orchestrator.stream.listen((state) {
    print('State updated: user=${state.user?['name']}, '
        'progress=${(state.uploadProgress * 100).toInt()}%, '
        'url=${state.uploadedFileUrl}');
  });

  // Demo 1: Fetch User
  print('\n--- Demo 1: Fetch User ---');
  final userHandle = orchestrator.fetchUser('user-123');
  try {
    final result = await userHandle.future;
    print('User loaded: ${result.data}');
  } catch (e) {
    print('Error: $e');
  }

  // Demo 2: Upload File with Progress
  print('\n--- Demo 2: Upload with Progress ---');
  final uploadHandle = orchestrator.uploadFile('photo.jpg');

  // Track progress
  uploadHandle.progress.listen((p) {
    print('Progress: ${(p.value * 100).toInt()}% - ${p.message}');
  });

  try {
    final result = await uploadHandle.future;
    print('Upload complete: ${result.data}');
  } catch (e) {
    print('Upload error: $e');
  }

  // Demo 3: Retry with FlakyApi
  print('\n--- Demo 3: Retry on Failure ---');
  final flakyHandle = orchestrator.callFlakyApi();
  try {
    final result = await flakyHandle.future;
    print('Flaky API result: ${result.data}');
  } catch (e) {
    print('Flaky API failed after retries: $e');
  }

  // Cleanup
  orchestrator.dispose();
  dispatcher.clear();

  print('\n=== Demo Complete ===');
}
