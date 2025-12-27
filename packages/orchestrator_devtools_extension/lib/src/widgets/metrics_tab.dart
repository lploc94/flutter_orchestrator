import 'package:flutter/material.dart';
import '../models/event_entry.dart';
import '../utils/metrics_aggregator.dart';

class MetricsTab extends StatelessWidget {
  final List<EventEntry> events;
  final int executorCount;
  final int networkQueueSize;

  const MetricsTab({
    super.key,
    required this.events,
    required this.executorCount,
    required this.networkQueueSize,
  });

  @override
  Widget build(BuildContext context) {
    final metrics = MetricsAggregator.calculate(
      events: events,
      executorCount: executorCount,
      networkQueueSize: networkQueueSize,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Key Metrics Cards
          _buildKeyMetricsRow(metrics),
          const SizedBox(height: 16),

          // Performance Section
          _buildPerformanceSection(metrics),
          const SizedBox(height: 16),

          // Anomaly Alerts
          if (metrics.anomalies.isNotEmpty) ...[
            _buildAnomalySection(metrics),
            const SizedBox(height: 16),
          ],

          // Top Jobs & Failures
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildTopJobsCard(metrics)),
              const SizedBox(width: 16),
              Expanded(child: _buildTopFailuresCard(metrics)),
            ],
          ),
          const SizedBox(height: 16),

          // Detailed Breakdown Table
          _buildBreakdownTable(metrics),
        ],
      ),
    );
  }

  Widget _buildKeyMetricsRow(OrchestratorMetrics metrics) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            title: 'Jobs Processed',
            value: metrics.totalJobs.toString(),
            icon: Icons.work,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            title: 'Success Rate',
            value: '${metrics.successRate.toStringAsFixed(1)}%',
            icon: Icons.check_circle,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            title: 'Errors',
            value: metrics.failureCount.toString(),
            icon: Icons.error,
            color: Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceSection(OrchestratorMetrics metrics) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PERFORMANCE',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatRow(
                    'Throughput',
                    '${metrics.jobsPerSecond.toStringAsFixed(2)} jobs/s',
                  ),
                ),
                Expanded(
                  child: _buildStatRow(
                    'Peak (1s)',
                    '${metrics.peakJobsPerSecond.toStringAsFixed(0)} jobs/s',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildStatRow(
                    'Avg Duration',
                    '${metrics.avgDuration.toStringAsFixed(0)}ms',
                  ),
                ),
                Expanded(
                  child: _buildStatRow(
                    'P95 Duration',
                    '${metrics.p95Duration.toStringAsFixed(0)}ms',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildStatRow(
                    'Cache Hit Rate',
                    '${metrics.cacheHitRate.toStringAsFixed(1)}%',
                  ),
                ),
                const Spacer(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildAnomalySection(OrchestratorMetrics metrics) {
    return Card(
      color: Colors.orange.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warning, color: Colors.orange, size: 18),
                SizedBox(width: 8),
                Text(
                  'ANOMALY ALERTS',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...metrics.anomalies.map(
              (a) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  a,
                  style: const TextStyle(fontSize: 12, color: Colors.orange),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopJobsCard(OrchestratorMetrics metrics) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'TOP JOBS (Frequency)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (metrics.topJobs.isEmpty)
              const Text(
                'No data',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              )
            else
              ...metrics.topJobs.map(
                (job) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          job.jobType,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        job.count.toString(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopFailuresCard(OrchestratorMetrics metrics) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'TOP FAILURES',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (metrics.topFailures.isEmpty)
              const Text(
                'No failures',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              )
            else
              ...metrics.topFailures.map(
                (job) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          job.jobType,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${job.failureCount} (${job.failureRate.toStringAsFixed(0)}%)',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownTable(OrchestratorMetrics metrics) {
    final jobs = metrics.jobTypeBreakdown.values.toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'DETAILED BREAKDOWN',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Table(
              border: TableBorder.all(
                color: Colors.grey.withValues(alpha: 0.3),
              ),
              columnWidths: const {
                0: FlexColumnWidth(3),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1),
                3: FlexColumnWidth(1),
                4: FlexColumnWidth(1.5),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                  ),
                  children: const [
                    _TableHeader('Job Type'),
                    _TableHeader('Count'),
                    _TableHeader('Success'),
                    _TableHeader('Failures'),
                    _TableHeader('Avg (ms)'),
                  ],
                ),
                if (jobs.isEmpty)
                  const TableRow(
                    children: [
                      Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text('No data', style: TextStyle(fontSize: 12)),
                      ),
                      SizedBox(),
                      SizedBox(),
                      SizedBox(),
                      SizedBox(),
                    ],
                  )
                else
                  ...jobs.map(
                    (job) => TableRow(
                      children: [
                        _TableCell(job.jobType),
                        _TableCell(job.count.toString()),
                        _TableCell(job.successCount.toString()),
                        _TableCell(
                          job.failureCount.toString(),
                          color: job.failureCount > 0 ? Colors.red : null,
                        ),
                        _TableCell(job.avgDuration.toStringAsFixed(0)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  final String text;

  const _TableHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  final String text;
  final Color? color;

  const _TableCell(this.text, {this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: color),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
