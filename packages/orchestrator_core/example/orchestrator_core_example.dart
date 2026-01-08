// Copyright (c) 2024, Flutter Orchestrator
// https://github.com/lploc94/flutter_orchestrator
//
// SPDX-License-Identifier: MIT

/// Example demonstrating the core Orchestrator pattern.
///
/// This example shows how to:
/// 1. Define domain events and jobs (using EventJob)
/// 2. Create executors with progress reporting
/// 3. Set up an orchestrator with unified `onEvent()` + `isJobRunning()` pattern
/// 4. Handle success, failure, progress, and cross-orchestrator events
/// 5. Use RetryPolicy for transient failures
library;

import 'dart:async';
import 'package:orchestrator_core/orchestrator_core.dart';

// ============ 1. Define Domain Events ============

/// Event emitted when a user is successfully loaded.
class UserLoadedEvent extends BaseEvent {
  final Map<String, dynamic> user;
  UserLoadedEvent(super.correlationId, this.user);
}

/// Event emitted when a user is updated (from another orchestrator).
class UserUpdatedEvent extends BaseEvent {
  final Map<String, dynamic> user;
  UserUpdatedEvent(super.correlationId, this.user);
}

/// Event emitted when file upload completes.
class FileUploadedEvent extends BaseEvent {
  final String fileUrl;
  FileUploadedEvent(super.correlationId, this.fileUrl);
}

// ============ 2. Define Jobs ============

/// A job to fetch user data by ID.
///
/// Uses [EventJob] to automatically emit [UserLoadedEvent] on success.
class FetchUserJob extends EventJob<Map<String, dynamic>, UserLoadedEvent> {
  final String userId;

  FetchUserJob(this.userId) : super(id: generateJobId('user'));

  @override
  UserLoadedEvent createEventTyped(Map<String, dynamic> result) {
    return UserLoadedEvent(id, result);
  }
}

/// A job that simulates file upload with progress reporting.
class UploadFileJob extends EventJob<String, FileUploadedEvent> {
  final String fileName;
  final int fileSizeKb;

  UploadFileJob(this.fileName, {this.fileSizeKb = 100})
      : super(id: generateJobId('upload'));

  @override
  FileUploadedEvent createEventTyped(String result) {
    return FileUploadedEvent(id, result);
  }
}

/// A job that may fail transiently (for retry demo).
class FlakyApiJob extends BaseJob {
  final int failCount;

  FlakyApiJob({
    this.failCount = 2,
    super.retryPolicy,
  }) : super(id: generateJobId('flaky'));
}

// ============ 3. Create Executors ============

/// Executor that handles [FetchUserJob].
class FetchUserExecutor extends BaseExecutor<FetchUserJob> {
  @override
  Future<Map<String, dynamic>> process(FetchUserJob job) async {
    await Future.delayed(Duration(milliseconds: 500));

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
///
/// Demonstrates how to use [emitProgress] to report upload progress.
class UploadFileExecutor extends BaseExecutor<UploadFileJob> {
  @override
  Future<String> process(UploadFileJob job) async {
    final totalChunks = 5;

    for (int i = 1; i <= totalChunks; i++) {
      // Simulate chunk upload
      await Future.delayed(Duration(milliseconds: 200));

      // Report progress (0.0 to 1.0)
      emitProgress(
        job.id,
        progress: i / totalChunks,
        message: 'Uploading chunk $i/$totalChunks',
        currentStep: i,
        totalSteps: totalChunks,
      );
    }

    return 'https://cdn.example.com/${job.fileName}';
  }
}

/// Executor that simulates transient failures (for retry demo).
///
/// Will fail [job.failCount] times before succeeding.
class FlakyApiExecutor extends BaseExecutor<FlakyApiJob> {
  final Map<String, int> _attempts = {};

  @override
  Future<String> process(FlakyApiJob job) async {
    await Future.delayed(Duration(milliseconds: 100));

    final attempt = (_attempts[job.id] ?? 0) + 1;
    _attempts[job.id] = attempt;

    if (attempt <= job.failCount) {
      throw Exception('Transient failure (attempt $attempt)');
    }

    return 'Success after $attempt attempts';
  }
}

// ============ 4. Define State ============

/// State for the upload feature.
class UploadState {
  final bool isUploading;
  final double progress;
  final String? progressMessage;
  final String? fileUrl;
  final String? error;
  final int retryAttempt;

  const UploadState({
    this.isUploading = false,
    this.progress = 0.0,
    this.progressMessage,
    this.fileUrl,
    this.error,
    this.retryAttempt = 0,
  });

  UploadState copyWith({
    bool? isUploading,
    double? progress,
    String? progressMessage,
    String? fileUrl,
    String? error,
    int? retryAttempt,
  }) =>
      UploadState(
        isUploading: isUploading ?? this.isUploading,
        progress: progress ?? this.progress,
        progressMessage: progressMessage ?? this.progressMessage,
        fileUrl: fileUrl ?? this.fileUrl,
        error: error,
        retryAttempt: retryAttempt ?? this.retryAttempt,
      );

  @override
  String toString() {
    if (isUploading) {
      return 'UploadState(uploading: ${(progress * 100).toInt()}% - $progressMessage)';
    }
    if (error != null) return 'UploadState(error: $error)';
    if (fileUrl != null) return 'UploadState(done: $fileUrl)';
    return 'UploadState(idle)';
  }
}

// ============ 5. Create Orchestrator ============

/// Orchestrator demonstrating progress tracking and retry handling.
class UploadOrchestrator extends BaseOrchestrator<UploadState> {
  UploadOrchestrator() : super(const UploadState());

  /// Upload a file with progress tracking.
  JobHandle<String> uploadFile(String fileName) {
    emit(state.copyWith(
      isUploading: true,
      progress: 0.0,
      progressMessage: 'Starting upload...',
      error: null,
    ));
    return dispatch(UploadFileJob(fileName));
  }

  /// Call a flaky API with retry policy.
  ///
  /// The job will fail [failCount] times before succeeding.
  /// RetryPolicy will automatically retry with exponential backoff.
  JobHandle<String> callFlakyApi({int failCount = 2}) {
    emit(state.copyWith(
      isUploading: true,
      progress: 0.0,
      error: null,
      retryAttempt: 0,
    ));

    // Configure retry policy: 3 retries with exponential backoff
    final job = FlakyApiJob(
      failCount: failCount,
      retryPolicy: RetryPolicy(
        maxRetries: 3,
        baseDelay: Duration(milliseconds: 100),
        maxDelay: Duration(seconds: 1),
        exponentialBackoff: true,
      ),
    );

    return dispatch(job);
  }

  /// Unified event handler with progress and retry support.
  @override
  void onEvent(BaseEvent event) {
    switch (event) {
      // ========== Progress Events ==========
      case JobProgressEvent e when isJobRunning(e.correlationId):
        emit(state.copyWith(
          progress: e.progress,
          progressMessage: e.message,
        ));

      // ========== Domain Events ==========
      case FileUploadedEvent e when isJobRunning(e.correlationId):
        emit(state.copyWith(
          isUploading: false,
          progress: 1.0,
          fileUrl: e.fileUrl,
        ));

      // ========== Generic Success (for BaseJob like FlakyApiJob) ==========
      case JobSuccessEvent e when isJobRunning(e.correlationId):
        emit(state.copyWith(
          isUploading: false,
          progress: 1.0,
          progressMessage: 'Completed: ${e.data}',
        ));

      // ========== Retry Events ==========
      case JobRetryingEvent e when isJobRunning(e.correlationId):
        emit(state.copyWith(
          retryAttempt: e.attempt,
          progressMessage: 'Retrying (${e.attempt}/${e.maxRetries})...',
        ));

      // ========== Failure ==========
      case JobFailureEvent e when isJobRunning(e.correlationId):
        emit(state.copyWith(
          isUploading: false,
          error: e.error.toString(),
        ));

      default:
        break;
    }
  }

  /// Optional: Dedicated progress handler (alternative to handling in onEvent).
  ///
  /// This is called for ALL progress events from our jobs.
  /// Useful if you want to separate progress handling logic.
  @override
  void onProgress(JobProgressEvent event) {
    // Already handled in onEvent, but you could handle here instead
    // print('Progress: ${(event.progress * 100).toInt()}%');
  }

  /// Optional: Called when a job is retrying.
  @override
  void onJobRetrying(JobRetryingEvent event) {
    // Already handled in onEvent, but you could handle here instead
    // print('Retrying: attempt ${event.attempt}');
  }
}

/// Simple user orchestrator (from previous example).
class UserOrchestrator extends BaseOrchestrator<Map<String, dynamic>?> {
  UserOrchestrator() : super(null);

  JobHandle<Map<String, dynamic>> loadUser(String userId) {
    return dispatch(FetchUserJob(userId));
  }

  @override
  void onEvent(BaseEvent event) {
    switch (event) {
      case UserLoadedEvent e when isJobRunning(e.correlationId):
        emit(e.user);
      case UserUpdatedEvent e:
        emit(e.user);
      default:
        break;
    }
  }
}

/// Admin orchestrator for cross-orchestrator demo.
class AdminOrchestrator extends BaseOrchestrator<String> {
  AdminOrchestrator() : super('idle');

  void updateUser(String userId, String newName) {
    final event = UserUpdatedEvent(
      generateJobId('admin'),
      {'id': userId, 'name': newName, 'email': 'updated@example.com'},
    );
    SignalBus.instance.emit(event);
    emit('Updated user: $userId');
  }
}

// ============ Main ============

void main() async {
  print('=== Orchestrator Core v0.6.0 Example ===\n');

  // 1. Register Executors
  final dispatcher = Dispatcher();
  dispatcher.register<FetchUserJob>(FetchUserExecutor());
  dispatcher.register<UploadFileJob>(UploadFileExecutor());
  dispatcher.register<FlakyApiJob>(FlakyApiExecutor());

  // ========== SCENARIO 1: Basic Load (Success/Failure) ==========
  print('--- Scenario 1: Basic Load ---');
  final userOrchestrator = UserOrchestrator();
  userOrchestrator.stream.listen((user) {
    print('[User] ${user ?? "null"}');
  });

  await userOrchestrator.loadUser('123').future;
  await Future.delayed(Duration(milliseconds: 50));

  // ========== SCENARIO 2: Progress Tracking ==========
  print('\n--- Scenario 2: Upload with Progress ---');
  final uploadOrchestrator = UploadOrchestrator();
  uploadOrchestrator.stream.listen((state) {
    print('[Upload] $state');
  });

  await uploadOrchestrator.uploadFile('photo.jpg').future;
  await Future.delayed(Duration(milliseconds: 50));

  // ========== SCENARIO 3: Retry with Exponential Backoff ==========
  print('\n--- Scenario 3: Retry (fails 2x, succeeds on 3rd) ---');
  final retryOrchestrator = UploadOrchestrator();
  retryOrchestrator.stream.listen((state) {
    print('[Retry] $state');
  });

  try {
    await retryOrchestrator.callFlakyApi(failCount: 2).future;
  } catch (e) {
    print('[Retry] Final error: $e');
  }
  await Future.delayed(Duration(milliseconds: 50));

  // ========== SCENARIO 4: Cross-Orchestrator Events ==========
  print('\n--- Scenario 4: Cross-Orchestrator ---');
  final adminOrchestrator = AdminOrchestrator();
  adminOrchestrator.updateUser('123', 'Jane Doe');
  await Future.delayed(Duration(milliseconds: 50));

  // Cleanup
  userOrchestrator.dispose();
  uploadOrchestrator.dispose();
  retryOrchestrator.dispose();
  adminOrchestrator.dispose();

  print('\n=== Done! ===');
}
