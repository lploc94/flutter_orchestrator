import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';

import 'src/orchestrator_inspector.dart';

void main() {
  runApp(const OrchestratorDevToolsExtension());
}

/// Root widget for the Orchestrator DevTools Extension.
///
/// Wraps the [OrchestratorInspector] with [DevToolsExtension] to enable
/// communication with Flutter DevTools.
class OrchestratorDevToolsExtension extends StatelessWidget {
  const OrchestratorDevToolsExtension({super.key});

  @override
  Widget build(BuildContext context) {
    return const DevToolsExtension(child: OrchestratorInspector());
  }
}
