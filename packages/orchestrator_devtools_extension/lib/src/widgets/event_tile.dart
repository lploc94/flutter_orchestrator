import 'package:flutter/material.dart';
import '../models/event_entry.dart';
import '../widgets/json_viewer.dart';

/// Single event tile in the timeline
class EventTile extends StatelessWidget {
  final EventEntry event;

  const EventTile({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final isOptimistic = event.rawData['isOptimistic'] == true;
    final isCacheHit = event.type == 'JobCacheHitEvent';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ExpansionTile(
        leading: _buildIcon(),
        title: Text(
          event.type,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'ID: ${event.correlationId.length > 8 ? event.correlationId.substring(0, 8) + '...' : event.correlationId}',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                    ),
                  ),
                ),
                if (isOptimistic)
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.orange, width: 0.5),
                    ),
                    child: const Text(
                      'Optimistic',
                      style: TextStyle(fontSize: 9, color: Colors.orange),
                    ),
                  ),
                if (isCacheHit)
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.teal, width: 0.5),
                    ),
                    child: const Text(
                      'Cache Hit',
                      style: TextStyle(fontSize: 9, color: Colors.teal),
                    ),
                  ),
              ],
            ),
            Text(
              _formatTime(event.timestamp),
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.all(8),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.05),
              borderRadius: BorderRadius.circular(4),
            ),
            child: JsonViewer(data: event.rawData),
          ),
        ],
      ),
    );
  }

  Widget _buildIcon() {
    final (icon, color) = switch (event.type) {
      'JobSuccessEvent' => (Icons.check_circle, Colors.green),
      'JobFailureEvent' => (Icons.error, Colors.red),
      'JobCancelledEvent' => (Icons.cancel, Colors.orange),
      'JobTimeoutEvent' => (Icons.timer_off, Colors.amber),
      'JobStartedEvent' => (Icons.play_circle, Colors.blue),
      'JobProgressEvent' => (Icons.pending, Colors.cyan),
      'JobRetryingEvent' => (Icons.refresh, Colors.purple),
      'JobCacheHitEvent' => (Icons.cached, Colors.teal),
      'JobPlaceholderEvent' => (Icons.hourglass_bottom, Colors.grey),
      'NetworkSyncFailureEvent' => (Icons.cloud_off, Colors.red),
      _ => (Icons.radio_button_checked, Colors.grey),
    };
    return Icon(icon, color: color, size: 24);
  }

  String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    final ms = time.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }
}
