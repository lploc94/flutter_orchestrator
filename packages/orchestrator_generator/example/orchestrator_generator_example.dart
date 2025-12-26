// Copyright (c) 2024, Flutter Orchestrator
// SPDX-License-Identifier: MIT

/// Example demonstrating code generation for NetworkJob registry.
///
/// This package generates `registerNetworkJobs()` function for offline
/// queue restoration.
///
/// ## Usage
///
/// 1. Annotate your entry point:
/// ```dart
/// @NetworkRegistry([
///   SendMessageJob,
///   LikePostJob,
/// ])
/// void setupNetworkRegistry() {}
/// ```
///
/// 2. Run build_runner:
/// ```bash
/// dart run build_runner build
/// ```
///
/// 3. Call generated function in main:
/// ```dart
/// void main() {
///   setupNetworkRegistry();
///   // or: registerNetworkJobs();
///   runApp(MyApp());
/// }
/// ```
library;

import 'package:orchestrator_core/orchestrator_core.dart';

// Example job that implements NetworkAction
class SendMessageJob extends BaseJob implements NetworkAction<String> {
  final String message;

  SendMessageJob(this.message) : super(id: generateJobId('msg'));

  @override
  Map<String, dynamic> toJson() => {'message': message};

  @override
  String createOptimisticResult() => message;

  // Required for deserialization from queue
  static SendMessageJob fromJson(Map<String, dynamic> json) {
    return SendMessageJob(json['message'] as String);
  }
}

// Annotate to generate registry
@NetworkRegistry([SendMessageJob])
void setupNetworkRegistry() {
  // Generated code will register:
  // NetworkJobRegistry.register('SendMessageJob', SendMessageJob.fromJson);
}

void main() {
  print('Run: dart run build_runner build');
  print('This generates registerNetworkJobs() function');
}
