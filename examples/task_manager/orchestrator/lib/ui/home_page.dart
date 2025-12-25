import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared/shared.dart';
import '../orchestrators/task_orchestrator.dart';
import '../orchestrators/task_state.dart';

/// Home page using Orchestrator pattern - SMOOTH edition.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final orchestrator = context.read<TaskOrchestrator>();
    orchestrator.fetchTasks();
    orchestrator.fetchCategories();
    orchestrator.fetchStats();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('✨ Orchestrator Task Manager'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          BlocBuilder<TaskOrchestrator, TaskState>(
            builder: (context, state) {
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Chip(
                  label: Text('Fetches: ${state.fetchCount}',
                      style: const TextStyle(fontSize: 12)),
                  backgroundColor: Colors.green.shade100,
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSuccessBanner(),
          _buildSearchBar(),
          _buildStatsCard(),
          _buildCategoryChips(),
          _buildActionButtons(),
          Expanded(child: _buildTaskList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateTaskDialog(context),
        backgroundColor: Colors.green.shade700,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildSuccessBanner() {
    return Container(
      width: double.infinity,
      color: Colors.green.shade100,
      padding: const EdgeInsets.all(12),
      child: const Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '✅ This app uses Orchestrator pattern. Try clicking rapidly - no race conditions!',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search tasks... (previous searches auto-cancel)',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          suffixIcon: BlocBuilder<TaskOrchestrator, TaskState>(
            builder: (context, state) {
              if (state.isSearching) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
        // Orchestrator automatically cancels previous search
        onChanged: (value) => context.read<TaskOrchestrator>().searchTasks(value),
      ),
    );
  }

  Widget _buildStatsCard() {
    return BlocBuilder<TaskOrchestrator, TaskState>(
      builder: (context, state) {
        final stats = state.stats;
        if (stats == null) {
          return const Card(
            margin: EdgeInsets.symmetric(horizontal: 16),
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem('Total', '${stats.totalTasks}', Colors.blue),
                _StatItem('Pending', '${stats.pendingTasks}', Colors.orange),
                _StatItem('Done', '${stats.completedTasks}', Colors.green),
                _StatItem('Urgent', '${stats.urgentTasks}', Colors.red),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryChips() {
    return BlocBuilder<TaskOrchestrator, TaskState>(
      builder: (context, state) {
        return SizedBox(
          height: 50,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              FilterChip(
                label: const Text('All'),
                selected: state.selectedCategoryId == null,
                onSelected: (_) => context.read<TaskOrchestrator>().setCategoryFilter(null),
              ),
              const SizedBox(width: 8),
              ...state.categories.map((cat) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text('${cat.icon} ${cat.name} (${cat.taskCount})'),
                      selected: state.selectedCategoryId == cat.id,
                      onSelected: (_) => context.read<TaskOrchestrator>().setCategoryFilter(cat.id),
                    ),
                  )),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButtons() {
    return BlocBuilder<TaskOrchestrator, TaskState>(
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: state.isLoading ? null : () => context.read<TaskOrchestrator>().fetchTasks(),
                icon: state.isLoading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh),
                label: const Text('Fetch Tasks'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade100),
              ),
              ElevatedButton.icon(
                onPressed: () => context.read<TaskOrchestrator>().refreshAll(),
                icon: const Icon(Icons.sync),
                label: const Text('Refresh All'),
              ),
              if (state.lastFetchTime != null)
                Chip(label: Text('Last: ${_formatTime(state.lastFetchTime!)}', style: const TextStyle(fontSize: 11))),
            ],
          ),
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }

  Widget _buildTaskList() {
    return BlocBuilder<TaskOrchestrator, TaskState>(
      builder: (context, state) {
        if (state.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 64, color: Colors.red.shade300),
                const SizedBox(height: 16),
                Text(state.error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: () => context.read<TaskOrchestrator>().fetchTasks(), child: const Text('Retry')),
              ],
            ),
          );
        }
        if (state.isLoading && state.tasks.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.filteredTasks.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [Icon(Icons.inbox, size: 64, color: Colors.grey), SizedBox(height: 16), Text('No tasks found')],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => context.read<TaskOrchestrator>().fetchTasks(),
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: state.filteredTasks.length,
            itemBuilder: (context, index) {
              final task = state.filteredTasks[index];
              return _TaskListItem(
                task: task,
                onTap: () => _showTaskDetail(context, task),
                onDelete: () => context.read<TaskOrchestrator>().deleteTask(task.id),
                onToggleComplete: () {
                  final newStatus = task.status == TaskStatus.completed ? 'pending' : 'completed';
                  context.read<TaskOrchestrator>().updateTask(task.id, status: newStatus);
                },
              );
            },
          ),
        );
      },
    );
  }

  void _showTaskDetail(BuildContext context, Task task) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(task.title, style: Theme.of(ctx).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(task.description),
            const SizedBox(height: 16),
            Text('Status: ${task.status.name}'),
            Text('Priority: ${task.priority.name}'),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showCreateTaskDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create Task'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 16),
            TextField(controller: descController, decoration: const InputDecoration(labelText: 'Description'), maxLines: 3),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          BlocBuilder<TaskOrchestrator, TaskState>(
            builder: (ctx, state) {
              return ElevatedButton(
                onPressed: state.isCreating ? null : () {
                  context.read<TaskOrchestrator>().createTask(
                    title: titleController.text,
                    description: descController.text,
                    categoryId: 'work',
                  );
                  Navigator.pop(dialogContext);
                },
                child: state.isCreating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Create'),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatItem(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

class _TaskListItem extends StatelessWidget {
  final Task task;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onToggleComplete;
  const _TaskListItem({required this.task, required this.onTap, required this.onDelete, required this.onToggleComplete});

  @override
  Widget build(BuildContext context) {
    final isCompleted = task.status == TaskStatus.completed;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: onTap,
        leading: Checkbox(value: isCompleted, onChanged: (_) => onToggleComplete()),
        title: Text(task.title, style: TextStyle(decoration: isCompleted ? TextDecoration.lineThrough : null, color: isCompleted ? Colors.grey : null)),
        subtitle: Text(task.description.isEmpty ? 'No description' : task.description, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PriorityBadge(priority: task.priority),
            IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: onDelete),
          ],
        ),
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  final TaskPriority priority;
  const _PriorityBadge({required this.priority});

  @override
  Widget build(BuildContext context) {
    final colors = {TaskPriority.low: Colors.grey, TaskPriority.medium: Colors.blue, TaskPriority.high: Colors.orange, TaskPriority.urgent: Colors.red};
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: colors[priority]!.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
      child: Text(priority.name.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colors[priority])),
    );
  }
}

