import 'package:flutter/material.dart';
import '../models/event_entry.dart';
import 'event_tile.dart';

/// Tab 2: Job Inspector - Shows jobs grouped by correlation ID
class JobInspectorTab extends StatelessWidget {
  final List<EventEntry> events;

  const JobInspectorTab({super.key, required this.events});

  @override
  Widget build(BuildContext context) {
    // Group events by correlation ID
    final jobs = <String, List<EventEntry>>{};
    for (final event in events) {
      jobs.putIfAbsent(event.correlationId, () => []).add(event);
    }

    if (jobs.isEmpty) {
      return const Center(
        child: Text('No jobs found', style: TextStyle(color: Colors.grey)),
      );
    }

    final jobIds = jobs.keys.toList();

    return ListView.builder(
      itemCount: jobIds.length,
      itemBuilder: (context, index) {
        final jobId = jobIds[index];
        final jobEvents = jobs[jobId]!;

        // Duration Logic
        final latestEvent = jobEvents.first;
        final earliestEvent = jobEvents.last;

        final duration = latestEvent.timestamp.difference(
          earliestEvent.timestamp,
        );

        final t = latestEvent.type;
        final isFinished =
            t.contains('JobSuccessEvent') ||
            t.contains('JobFailureEvent') ||
            t.contains('JobCancelledEvent') ||
            t.contains('JobTimeoutEvent');

        return ExpansionTile(
          leading: _getJobStatusIcon(latestEvent.type),
          title: Text(
            jobId.substring(0, 8),
            style: const TextStyle(fontFamily: 'monospace'),
          ),
          subtitle: Row(
            children: [
              Text('${jobEvents.length} events'),
              const SizedBox(width: 12),
              if (isFinished)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: duration.inMilliseconds > 500
                        ? Colors.red.withOpacity(0.1)
                        : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: duration.inMilliseconds > 500
                          ? Colors.red
                          : Colors.green,
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    '${duration.inMilliseconds}ms',
                    style: TextStyle(
                      fontSize: 10,
                      color: duration.inMilliseconds > 500
                          ? Colors.red
                          : Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          children: jobEvents.map((e) {
            return EventTile(event: e);
          }).toList(),
        );
      },
    );
  }

  Widget _getJobStatusIcon(String lastEventType) {
    final (icon, color) = switch (lastEventType) {
      'JobSuccessEvent' => (Icons.check_circle, Colors.green),
      'JobFailureEvent' => (Icons.error, Colors.red),
      'JobCancelledEvent' => (Icons.cancel, Colors.orange),
      'JobTimeoutEvent' => (Icons.timer_off, Colors.amber),
      _ => (Icons.pending, Colors.blue),
    };
    return Icon(icon, color: color);
  }
}
