import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:orchestrator_bloc/orchestrator_bloc.dart';
import 'package:shared/shared.dart';
import 'executors/task_executor.dart';
import 'jobs/task_jobs.dart';
import 'orchestrators/task_orchestrator.dart';
import 'ui/home_page.dart';

void main() {
  // Register executors with dispatcher
  _registerExecutors();

  runApp(const MyApp());
}

void _registerExecutors() {
  final dispatcher = Dispatcher();
  final api = MockApiService()..initialize();

  // Register specialized executors for each job type
  dispatcher.register<FetchTasksJob>(FetchTasksExecutor(api));
  dispatcher.register<SearchTasksJob>(SearchTasksExecutor(api));
  dispatcher.register<CreateTaskJob>(CreateTaskExecutor(api));
  dispatcher.register<UpdateTaskJob>(UpdateTaskExecutor(api));
  dispatcher.register<DeleteTaskJob>(DeleteTaskExecutor(api));
  dispatcher.register<FetchCategoriesJob>(FetchCategoriesExecutor(api));
  dispatcher.register<FetchStatsJob>(FetchStatsExecutor(api));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TaskOrchestrator(),
      child: MaterialApp(
        title: 'Orchestrator Task Manager',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.green,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        home: const HomePage(),
      ),
    );
  }
}
