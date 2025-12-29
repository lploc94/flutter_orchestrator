// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orchestrator_core/orchestrator_core.dart';

import 'package:simple_counter/main.dart';
import 'package:simple_counter/jobs/counter_jobs.dart';
import 'package:simple_counter/executors/counter_executor.dart';

void main() {
  setUp(() {
    // Register executors before each test
    final dispatcher = Dispatcher();
    dispatcher.resetForTesting();
    final counterService = CounterService();
    dispatcher.register<IncrementJob>(
      IncrementWithServiceExecutor(counterService),
    );
    dispatcher.register<DecrementJob>(
      DecrementWithServiceExecutor(counterService),
    );
    dispatcher.register<ResetJob>(ResetWithServiceExecutor(counterService));
  });

  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that our counter starts at 0.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Tap the '+' icon and trigger a frame.
    await tester.tap(find.byIcon(Icons.add));
    // Wait for async job to complete
    await tester.pumpAndSettle();

    // Verify that our counter has incremented.
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}
