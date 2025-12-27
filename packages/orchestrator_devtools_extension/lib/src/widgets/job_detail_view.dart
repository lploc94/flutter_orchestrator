import 'package:flutter/material.dart';
import '../models/event_entry.dart';
import 'event_tile.dart';

class JobDetailView extends StatelessWidget {
  final String jobId;
  final List<EventEntry> events;

  const JobDetailView({super.key, required this.jobId, required this.events});

  @override
  Widget build(BuildContext context) {
    // Sort events by timestamp
    final sortedEvents = List<EventEntry>.from(events)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final startTime = sortedEvents.first.timestamp;
    final endTime = sortedEvents.last.timestamp;
    final duration = endTime.difference(startTime);

    return Scaffold(
      appBar: AppBar(
        title: Text('Job Details: ${jobId.substring(0, 8)}...'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                'Duration: ${duration.inMilliseconds}ms',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: sortedEvents.length,
        itemBuilder: (context, index) {
          final event = sortedEvents[index];
          final timeOffset = event.timestamp.difference(startTime);

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 60,
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  '+${timeOffset.inMilliseconds}ms',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: EventTile(event: event)),
            ],
          );
        },
      ),
    );
  }
}
