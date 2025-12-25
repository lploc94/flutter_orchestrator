import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:orchestrator_bloc/orchestrator_bloc.dart';

import 'shared/shared.dart';
import 'traditional/traditional_cubit.dart';
import 'orchestrator/orchestrator_cubit.dart';
import 'orchestrator/executors.dart';
import 'orchestrator/jobs.dart';
import 'ui/comparison_page.dart';

void main() {
  // Shared services
  final api = MockApi();
  final log = LogService();

  // Register executors for Orchestrator pattern
  final dispatcher = Dispatcher();
  dispatcher.register<FetchTasksJob>(FetchTasksExecutor(api));
  dispatcher.register<SearchTasksJob>(SearchTasksExecutor(api));
  dispatcher.register<FetchCategoriesJob>(FetchCategoriesExecutor(api));
  dispatcher.register<FetchStatsJob>(FetchStatsExecutor(api));

  runApp(MyApp(api: api, log: log));
}

class MyApp extends StatelessWidget {
  final MockApi api;
  final LogService log;

  const MyApp({super.key, required this.api, required this.log});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // Traditional approach
        BlocProvider(create: (_) => TraditionalCubit(api, log)),
        // Orchestrator approach
        BlocProvider(create: (_) => TaskOrchestrator(log)),
      ],
      child: MaterialApp(
        title: 'Traditional vs Orchestrator',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const ComparisonPage(),
      ),
    );
  }
}
