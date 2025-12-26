// Copyright (c) 2024, Flutter Orchestrator
// SPDX-License-Identifier: MIT

/// Example demonstrating Flutter-specific utilities for Orchestrator.
///
/// This package provides:
/// - [FlutterConnectivityProvider] - Network connectivity detection
/// - [FileNetworkQueueStorage] - Persistent offline queue storage
/// - [FlutterFileSafety] - Safe file operations
library;

import 'package:orchestrator_core/orchestrator_core.dart';
import 'package:orchestrator_flutter/orchestrator_flutter.dart';

void main() async {
  // 1. Configure connectivity provider
  OrchestratorConfig.setConnectivityProvider(FlutterConnectivityProvider());

  // 2. Check connectivity
  final provider = OrchestratorConfig.connectivityProvider;
  final isOnline = await provider.isConnected;
  print('Is online: $isOnline');

  // 3. Listen to connectivity changes
  provider.onConnectivityChanged.listen((connected) {
    print('Connectivity changed: $connected');
  });

  // 4. Setup persistent offline queue (optional)
  // final storage = FileNetworkQueueStorage();
  // OrchestratorConfig.setNetworkQueueManager(
  //   NetworkQueueManager(storage: storage),
  // );

  print('Flutter orchestrator configured!');
}
