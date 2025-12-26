import 'package:flutter/material.dart';
import '../models/event_entry.dart';
import 'event_tile.dart';

/// Tab 1: Event Timeline - Shows all events in real-time
class EventTimelineTab extends StatelessWidget {
  final List<EventEntry> events;

  const EventTimelineTab({super.key, required this.events});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_empty, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No events found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        return EventTile(event: event);
      },
    );
  }
}
