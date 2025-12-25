import 'package:flutter/material.dart';
import '../shared/shared.dart';

/// Widget to display real-time logs.
class LogPanel extends StatelessWidget {
  final List<LogEntry> logs;
  final String title;
  final Color color;

  const LogPanel({
    super.key,
    required this.logs,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withAlpha((0.2 * 255).round()),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Text(
              title,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: logs.isEmpty
                ? Center(
                    child: Text(
                      'No logs yet',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                    ),
                  )
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(8),
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[logs.length - 1 - index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          log.toString(),
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            color: _getLogColor(log.level),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Color _getLogColor(LogLevel level) {
    switch (level) {
      case LogLevel.info:
        return Colors.grey.shade400;
      case LogLevel.success:
        return Colors.green.shade400;
      case LogLevel.warning:
        return Colors.orange.shade400;
      case LogLevel.error:
        return Colors.red.shade400;
      case LogLevel.timing:
        return Colors.blue.shade400;
      case LogLevel.race:
        return Colors.purple.shade400;
    }
  }
}

/// Statistics card widget.
class StatsCard extends StatelessWidget {
  final String title;
  final Color color;
  final int apiCalls;
  final int completed;
  final int? raceConditions;
  final int? cancellations;

  const StatsCard({
    super.key,
    required this.title,
    required this.color,
    required this.apiCalls,
    required this.completed,
    this.raceConditions,
    this.cancellations,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withAlpha((0.1 * 255).round()),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            _buildStat('API Calls', '$apiCalls'),
            _buildStat('Completed', '$completed'),
            if (raceConditions != null)
              _buildStat(
                '⚠️ Race Conditions',
                '$raceConditions',
                isWarning: raceConditions! > 0,
              ),
            if (cancellations != null)
              _buildStat(
                '✅ Cancelled',
                '$cancellations',
                isGood: true,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value, {bool isWarning = false, bool isGood = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              color: isWarning
                  ? Colors.red
                  : isGood
                      ? Colors.green
                      : null,
            ),
          ),
        ],
      ),
    );
  }
}
