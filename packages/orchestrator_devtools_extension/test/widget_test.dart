// Basic smoke test for Orchestrator DevTools Extension.

import 'package:flutter_test/flutter_test.dart';
import 'package:orchestrator_devtools_extension/main.dart';

void main() {
  testWidgets('Extension renders without error', (WidgetTester tester) async {
    // Build our extension and trigger a frame.
    await tester.pumpWidget(const OrchestratorDevToolsExtension());

    // Verify that the extension title is visible.
    expect(find.text('Orchestrator Inspector'), findsOneWidget);

    // Verify that all tabs are present.
    expect(find.text('Events'), findsOneWidget);
    expect(find.text('Jobs'), findsOneWidget);
    expect(find.text('Executors'), findsOneWidget);
  });
}
