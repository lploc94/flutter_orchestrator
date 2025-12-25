// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:orchestrator_bloc/orchestrator_bloc.dart';

import 'package:task_manager_comparison/main.dart';
import 'package:task_manager_comparison/shared/shared.dart';
import 'package:task_manager_comparison/orchestrator/executors.dart';
import 'package:task_manager_comparison/orchestrator/jobs.dart';

void main() {
  testWidgets('App renders comparison page', (WidgetTester tester) async {
    final api = MockApi();
    final log = LogService();

    // Register executors (same as main.dart)
    final dispatcher = Dispatcher();
    dispatcher.register<FetchTasksJob>(FetchTasksExecutor(api));
    dispatcher.register<SearchTasksJob>(SearchTasksExecutor(api));
    dispatcher.register<FetchCategoriesJob>(FetchCategoriesExecutor(api));
    dispatcher.register<FetchStatsJob>(FetchStatsExecutor(api));

    await tester.pumpWidget(MyApp(api: api, log: log));
    await tester.pump(const Duration(seconds: 3)); // Wait for async ops

    // Verify both sides are rendered (may have multiple instances due to stats panel)
    expect(find.text('🔴 Traditional'), findsWidgets);
    expect(find.text('🟢 Orchestrator'), findsWidgets);
    
    // Verify comparison page structure
    expect(find.text('Fetch Tasks'), findsNWidgets(2)); // One on each side
  });
}
