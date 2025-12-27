import '../models/event_entry.dart';

/// Aggregated metrics for dashboard
class OrchestratorMetrics {
  // System Health
  final int totalEvents;
  final int totalJobs;
  final int activeExecutors;
  final int networkQueueSize;

  // Performance
  final double jobsPerSecond;
  final double peakJobsPerSecond;
  final double avgDuration;
  final double p95Duration;
  final double cacheHitRate;

  // Reliability
  final int successCount;
  final int failureCount;
  final int retryCount;
  final int timeoutCount;
  final int cancelCount;
  final double successRate;

  // Job Distribution
  final Map<String, JobTypeStats> jobTypeBreakdown;
  final List<JobTypeStats> topJobs;
  final List<JobTypeStats> topFailures;

  // Anomalies
  final List<String> anomalies;

  OrchestratorMetrics({
    required this.totalEvents,
    required this.totalJobs,
    required this.activeExecutors,
    required this.networkQueueSize,
    required this.jobsPerSecond,
    required this.peakJobsPerSecond,
    required this.avgDuration,
    required this.p95Duration,
    required this.cacheHitRate,
    required this.successCount,
    required this.failureCount,
    required this.retryCount,
    required this.timeoutCount,
    required this.cancelCount,
    required this.successRate,
    required this.jobTypeBreakdown,
    required this.topJobs,
    required this.topFailures,
    required this.anomalies,
  });
}

/// Stats per Job Type
class JobTypeStats {
  final String jobType;
  final int count;
  final int successCount;
  final int failureCount;
  final double avgDuration;
  final double failureRate;

  JobTypeStats({
    required this.jobType,
    required this.count,
    required this.successCount,
    required this.failureCount,
    required this.avgDuration,
    required this.failureRate,
  });
}

/// Aggregates metrics from event list
class MetricsAggregator {
  static OrchestratorMetrics calculate({
    required List<EventEntry> events,
    required int executorCount,
    required int networkQueueSize,
    DateTime? startTime,
  }) {
    if (events.isEmpty) {
      return _emptyMetrics(executorCount, networkQueueSize);
    }

    // Group events by correlation ID to track jobs
    final jobMap = <String, List<EventEntry>>{};
    for (final event in events) {
      jobMap.putIfAbsent(event.correlationId, () => []).add(event);
    }

    // Count event types
    int successCount = 0;
    int failureCount = 0;
    int retryCount = 0;
    int timeoutCount = 0;
    int cancelCount = 0;
    int cacheHits = 0;

    for (final event in events) {
      final type = event.type;
      if (type.contains('JobSuccessEvent')) {
        successCount++;
      } else if (type.contains('JobFailureEvent')) {
        failureCount++;
      } else if (type.contains('JobRetryingEvent')) {
        retryCount++;
      } else if (type.contains('JobTimeoutEvent')) {
        timeoutCount++;
      } else if (type.contains('JobCancelledEvent')) {
        cancelCount++;
      } else if (type.contains('JobCacheHitEvent')) {
        cacheHits++;
      }
    }

    // Calculate job durations
    final durations = <double>[];
    final jobTypeMap = <String, _JobTypeAccumulator>{};

    for (final entry in jobMap.entries) {
      final jobEvents = entry.value;
      if (jobEvents.length < 2) continue;

      // Sort by timestamp
      jobEvents.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // Robustly find job type from ANY event in the sequence
      String jobType = 'Unknown';
      for (final e in jobEvents) {
        if (e.jobType != null && e.jobType!.isNotEmpty) {
          jobType = e.jobType!;
          break;
        }
      }

      final start = jobEvents.first.timestamp;
      final end = jobEvents.last.timestamp;
      final duration = end.difference(start).inMilliseconds.toDouble();

      if (duration > 0) {
        durations.add(duration);
      }

      // Robustly determine success/failure from all events
      bool isSuccess = false;
      bool isFailure = false;

      for (final e in jobEvents) {
        if (e.type.contains('JobSuccessEvent')) {
          isSuccess = true;
        } else if (e.type.contains('JobFailureEvent')) {
          isFailure = true;
        }
      }

      final accumulator = jobTypeMap.putIfAbsent(
        jobType,
        () => _JobTypeAccumulator(jobType),
      );

      accumulator.count++;
      if (isSuccess) accumulator.successCount++;
      if (isFailure) accumulator.failureCount++;
      if (duration > 0) {
        accumulator.totalDuration += duration;
        accumulator.durationCount++;
      }
    }

    // Calculate metrics
    final avgDuration = durations.isEmpty
        ? 0.0
        : durations.reduce((a, b) => a + b) / durations.length;

    durations.sort();
    final p95Duration = durations.isEmpty
        ? 0.0
        : durations[(durations.length * 0.95).floor().clamp(
            0,
            durations.length - 1,
          )];

    final totalJobs = jobMap.length;
    final successRate = totalJobs > 0 ? (successCount / totalJobs) * 100 : 0.0;

    final cacheHitRate = successCount > 0
        ? (cacheHits / successCount) * 100
        : 0.0;

    // Calculate throughput (Peak & Average)
    final now = DateTime.now();
    final earliestEvent = events
        .map((e) => e.timestamp)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final timeSpanSeconds = now.difference(earliestEvent).inSeconds.toDouble();
    final jobsPerSecond = timeSpanSeconds > 0
        ? totalJobs / timeSpanSeconds
        : 0.0;

    // Calculate Peak Jobs Per Second
    final eventsPerSecond = <int, int>{};
    for (final event in events) {
      // Group by second (integer timestamp)
      final second = event.timestamp.millisecondsSinceEpoch ~/ 1000;
      eventsPerSecond[second] = (eventsPerSecond[second] ?? 0) + 1;
    }

    // We want jobs per second, not events. Approximation: events / 2 (start+end)
    // or just track unique correlation IDs per second.
    final jobsPerSecondMap = <int, Set<String>>{};
    for (final event in events) {
      final second = event.timestamp.millisecondsSinceEpoch ~/ 1000;
      jobsPerSecondMap
          .putIfAbsent(second, () => <String>{})
          .add(event.correlationId);
    }

    final peakJobsPerSecond = jobsPerSecondMap.values.fold<int>(0, (max, jobs) {
      return jobs.length > max ? jobs.length : max;
    }).toDouble();

    // Job type breakdown
    final jobTypeBreakdown = <String, JobTypeStats>{};
    for (final accumulator in jobTypeMap.values) {
      final avgDur = accumulator.durationCount > 0
          ? accumulator.totalDuration / accumulator.durationCount
          : 0.0;
      final failRate = accumulator.count > 0
          ? (accumulator.failureCount / accumulator.count) * 100
          : 0.0;

      jobTypeBreakdown[accumulator.jobType] = JobTypeStats(
        jobType: accumulator.jobType,
        count: accumulator.count,
        successCount: accumulator.successCount,
        failureCount: accumulator.failureCount,
        avgDuration: avgDur,
        failureRate: failRate,
      );
    }

    // Top jobs (by frequency)
    final topJobs = jobTypeBreakdown.values.toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    // Top failures (by failure rate)
    final topFailures =
        jobTypeBreakdown.values.where((s) => s.failureCount > 0).toList()
          ..sort((a, b) => b.failureRate.compareTo(a.failureRate));

    // Anomaly detection
    final anomalies = <String>[];
    if (successRate < 80) {
      anomalies.add('⚠️ Low success rate: ${successRate.toStringAsFixed(1)}%');
    }
    if (failureCount > totalJobs * 0.2) {
      anomalies.add('⚠️ High error rate: $failureCount failures');
    }
    if (networkQueueSize > 10) {
      anomalies.add('⚠️ Network queue buildup: $networkQueueSize pending');
    }
    if (avgDuration > 1000) {
      anomalies.add(
        '⚠️ Slow performance: ${avgDuration.toStringAsFixed(0)}ms avg',
      );
    }

    return OrchestratorMetrics(
      totalEvents: events.length,
      totalJobs: totalJobs,
      activeExecutors: executorCount,
      networkQueueSize: networkQueueSize,
      jobsPerSecond: jobsPerSecond,
      peakJobsPerSecond: peakJobsPerSecond, // Real peak calculation
      avgDuration: avgDuration,
      p95Duration: p95Duration,
      cacheHitRate: cacheHitRate,
      successCount: successCount,
      failureCount: failureCount,
      retryCount: retryCount,
      timeoutCount: timeoutCount,
      cancelCount: cancelCount,
      successRate: successRate,
      jobTypeBreakdown: jobTypeBreakdown,
      topJobs: topJobs.take(5).toList(),
      topFailures: topFailures.take(5).toList(),
      anomalies: anomalies,
    );
  }

  static OrchestratorMetrics _emptyMetrics(int executorCount, int queueSize) {
    return OrchestratorMetrics(
      totalEvents: 0,
      totalJobs: 0,
      activeExecutors: executorCount,
      networkQueueSize: queueSize,
      jobsPerSecond: 0,
      peakJobsPerSecond: 0,
      avgDuration: 0,
      p95Duration: 0,
      cacheHitRate: 0,
      successCount: 0,
      failureCount: 0,
      retryCount: 0,
      timeoutCount: 0,
      cancelCount: 0,
      successRate: 0,
      jobTypeBreakdown: {},
      topJobs: [],
      topFailures: [],
      anomalies: [],
    );
  }
}

class _JobTypeAccumulator {
  final String jobType;
  int count = 0;
  int successCount = 0;
  int failureCount = 0;
  double totalDuration = 0;
  int durationCount = 0;

  _JobTypeAccumulator(this.jobType);
}
