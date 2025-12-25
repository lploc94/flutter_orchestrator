import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../shared/shared.dart';
import '../traditional/traditional_cubit.dart';
import '../orchestrator/orchestrator_cubit.dart';
import 'widgets.dart';

/// Main comparison page - side-by-side view.
class ComparisonPage extends StatefulWidget {
  const ComparisonPage({super.key});

  @override
  State<ComparisonPage> createState() => _ComparisonPageState();
}

class _ComparisonPageState extends State<ComparisonPage> {
  final _traditionalSearchController = TextEditingController();
  final _orchestratorSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initial fetch - using addPostFrameCallback to avoid context issues
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TraditionalCubit>().fetchTasks();
      context.read<TraditionalCubit>().fetchCategories();
      context.read<TraditionalCubit>().fetchStats();

      context.read<TaskOrchestrator>().fetchTasks();
      context.read<TaskOrchestrator>().fetchCategories();
      context.read<TaskOrchestrator>().fetchStats();
    });
  }

  @override
  void dispose() {
    _traditionalSearchController.dispose();
    _orchestratorSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔬 Traditional vs Orchestrator'),
        backgroundColor: Colors.grey.shade800,
        foregroundColor: Colors.white,
        actions: [
          TextButton.icon(
            onPressed: _resetAll,
            icon: const Icon(Icons.refresh, color: Colors.white),
            label: const Text('Reset All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Instructions banner
          Container(
            color: Colors.blue.shade100,
            padding: const EdgeInsets.all(12),
            child: const Row(
              children: [
                Icon(Icons.info, color: Colors.blue),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '👆 Click "Fetch Tasks" rapidly 5+ times on BOTH sides, then compare the logs below!',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          // Main comparison area
          Expanded(
            flex: 3,
            child: Row(
              children: [
                // Traditional side
                Expanded(
                  child: _buildTraditionalSide(),
                ),

                // Divider
                Container(
                  width: 2,
                  color: Colors.grey.shade300,
                ),

                // Orchestrator side
                Expanded(
                  child: _buildOrchestratorSide(),
                ),
              ],
            ),
          ),

          // Log panels
          Expanded(
            flex: 2,
            child: _buildLogPanels(),
          ),
        ],
      ),
    );
  }

  Widget _buildTraditionalSide() {
    return BlocBuilder<TraditionalCubit, TraditionalState>(
      builder: (context, state) {
        return Container(
          color: Colors.red.shade50,
          child: Column(
            children: [
              // Header
              Container(
                color: Colors.red.shade700,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Text(
                      '🔴 Traditional',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    Chip(
                      label: Text(
                        'Fetches: ${state.fetchCount}',
                        style: const TextStyle(fontSize: 10),
                      ),
                      backgroundColor: Colors.red.shade100,
                    ),
                  ],
                ),
              ),

              // Search
              Padding(
                padding: const EdgeInsets.all(8),
                child: TextField(
                  controller: _traditionalSearchController,
                  decoration: InputDecoration(
                    hintText: 'Type fast to see race condition...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    suffixIcon: state.isSearching
                        ? const Padding(
                            padding: EdgeInsets.all(8),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                  onChanged: (v) => context.read<TraditionalCubit>().searchTasks(v),
                ),
              ),

              // Fetch button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => context.read<TraditionalCubit>().fetchTasks(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                    ),
                    icon: state.isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.download, size: 18),
                    label: const Text('Fetch Tasks'),
                  ),
                ),
              ),

              // Task list
              Expanded(
                child: _buildTaskList(state.tasks, state.isLoading, Colors.red),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrchestratorSide() {
    return BlocBuilder<TaskOrchestrator, OrchestratorState>(
      builder: (context, state) {
        return Container(
          color: Colors.green.shade50,
          child: Column(
            children: [
              // Header
              Container(
                color: Colors.green.shade700,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Text(
                      '🟢 Orchestrator',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    Chip(
                      label: Text(
                        'Fetches: ${state.fetchCount}',
                        style: const TextStyle(fontSize: 10),
                      ),
                      backgroundColor: Colors.green.shade100,
                    ),
                  ],
                ),
              ),

              // Search
              Padding(
                padding: const EdgeInsets.all(8),
                child: TextField(
                  controller: _orchestratorSearchController,
                  decoration: InputDecoration(
                    hintText: 'Previous searches auto-cancel...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    suffixIcon: state.isSearching
                        ? const Padding(
                            padding: EdgeInsets.all(8),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                  onChanged: (v) => context.read<TaskOrchestrator>().searchTasks(v),
                ),
              ),

              // Fetch button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => context.read<TaskOrchestrator>().fetchTasks(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                    ),
                    icon: state.isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.download, size: 18),
                    label: const Text('Fetch Tasks'),
                  ),
                ),
              ),

              // Task list
              Expanded(
                child: _buildTaskList(state.tasks, state.isLoading, Colors.green),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTaskList(List<Task> tasks, bool isLoading, Color color) {
    if (isLoading && tasks.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (tasks.isEmpty) {
      return Center(
        child: Text(
          'No tasks',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 4),
          child: ListTile(
            dense: true,
            leading: Icon(
              task.status == TaskStatus.completed
                  ? Icons.check_circle
                  : Icons.circle_outlined,
              color: color,
              size: 20,
            ),
            title: Text(
              task.title,
              style: const TextStyle(fontSize: 12),
            ),
            subtitle: Text(
              task.categoryId,
              style: const TextStyle(fontSize: 10),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogPanels() {
    return ListenableBuilder(
      listenable: LogService(),
      builder: (context, _) {
        final log = LogService();
        return Container(
          color: Colors.grey.shade100,
          child: Column(
            children: [
              // Stats row
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(
                      child: StatsCard(
                        title: '🔴 Traditional',
                        color: Colors.red,
                        apiCalls: log.traditionalApiCalls,
                        completed: context.read<TraditionalCubit>().state.completedFetches,
                        raceConditions: log.traditionalRaceConditions,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StatsCard(
                        title: '🟢 Orchestrator',
                        color: Colors.green,
                        apiCalls: log.orchestratorApiCalls,
                        completed: context.read<TaskOrchestrator>().state.completedFetches,
                        cancellations: log.orchestratorCancellations,
                      ),
                    ),
                  ],
                ),
              ),

              // Log panels
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: LogPanel(
                          logs: log.traditionalLogs,
                          title: '📋 Traditional Logs',
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: LogPanel(
                          logs: log.orchestratorLogs,
                          title: '📋 Orchestrator Logs',
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _resetAll() {
    LogService().clear();
    context.read<TraditionalCubit>().reset();
    context.read<TaskOrchestrator>().reset();
    _traditionalSearchController.clear();
    _orchestratorSearchController.clear();

    // Re-fetch
    context.read<TraditionalCubit>().fetchTasks();
    context.read<TaskOrchestrator>().fetchTasks();
  }
}
