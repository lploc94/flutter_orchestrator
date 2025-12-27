import 'package:flutter/material.dart';

/// Tab 3: Executor Registry - Shows registered executors
class ExecutorRegistryTab extends StatelessWidget {
  final Map<String, String> registry;

  const ExecutorRegistryTab({super.key, required this.registry});

  @override
  Widget build(BuildContext context) {
    if (registry.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hub, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No executors registered',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Waiting for app to connect...',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final sortedKeys = registry.keys.toList()..sort();

    return ListView.builder(
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final jobType = sortedKeys[index];
        final executorType = registry[jobType]!;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green.withValues(alpha: 0.1),
              child: const Icon(Icons.bolt, color: Colors.blue),
            ),
            title: Text(
              jobType,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('Handled by: $executorType'),
          ),
        );
      },
    );
  }
}
