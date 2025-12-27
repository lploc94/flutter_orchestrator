import 'package:flutter/material.dart';
import 'json_viewer.dart';

class NetworkQueueTab extends StatelessWidget {
  final List<Map<String, dynamic>> queue;

  const NetworkQueueTab({super.key, required this.queue});

  @override
  Widget build(BuildContext context) {
    if (queue.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Network Queue is empty',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'No offline jobs waiting for connectivity',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: queue.length,
      itemBuilder: (context, index) {
        final job = queue[index];
        final id = job['id'] as String? ?? 'Unknown ID';
        final status = job['status'] as String? ?? 'Pending';
        final retryCount = job['retryCount'] as int? ?? 0;
        final createdAtRaw = job['timestamp'] ?? job['createdAt'];
        final createdAt = createdAtRaw != null
            ? DateTime.tryParse(createdAtRaw.toString())
            : null;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ExpansionTile(
            leading: Icon(Icons.cloud_queue, color: Colors.orange),
            title: Text(id, style: const TextStyle(fontFamily: 'monospace')),
            subtitle: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Retries: $retryCount',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                if (createdAt != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    'Created: ${_formatTime(createdAt)}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ],
            ),
            childrenPadding: const EdgeInsets.all(16),
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: JsonViewer(data: job),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
