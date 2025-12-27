// Unit tests for MetricsAggregator utility class.

import 'package:flutter_test/flutter_test.dart';
import 'package:orchestrator_devtools_extension/src/models/event_entry.dart';
import 'package:orchestrator_devtools_extension/src/utils/metrics_aggregator.dart';

void main() {
  group('MetricsAggregator', () {
    test('returns empty metrics for empty event list', () {
      final metrics = MetricsAggregator.calculate(
        events: [],
        executorCount: 0,
        networkQueueSize: 0,
      );

      expect(metrics.totalEvents, 0);
      expect(metrics.totalJobs, 0);
      expect(metrics.successCount, 0);
      expect(metrics.failureCount, 0);
      expect(metrics.jobsPerSecond, 0.0);
      expect(metrics.peakJobsPerSecond, 0.0);
    });

    test('calculates basic job metrics correctly', () {
      final now = DateTime.now();
      final events = <EventEntry>[
        EventEntry(
          type: 'JobStartedEvent',
          correlationId: 'job-1',
          timestamp: now,
          rawData: {},
        ),
        EventEntry(
          type: 'JobSuccessEvent',
          correlationId: 'job-1',
          timestamp: now.add(const Duration(milliseconds: 100)),
          rawData: {},
        ),
        EventEntry(
          type: 'JobStartedEvent',
          correlationId: 'job-2',
          timestamp: now.add(const Duration(milliseconds: 200)),
          rawData: {},
        ),
        EventEntry(
          type: 'JobFailureEvent',
          correlationId: 'job-2',
          timestamp: now.add(const Duration(milliseconds: 300)),
          rawData: {},
        ),
      ];

      final metrics = MetricsAggregator.calculate(
        events: events,
        executorCount: 5,
        networkQueueSize: 2,
      );

      expect(metrics.totalEvents, 4);
      expect(metrics.totalJobs, 2);
      expect(metrics.successCount, 1);
      expect(metrics.failureCount, 1);
      expect(metrics.successRate, 50.0);
      expect(metrics.activeExecutors, 5);
      expect(metrics.networkQueueSize, 2);
    });

    test('handles generic event types (e.g., JobSuccessEvent<dynamic>)', () {
      final now = DateTime.now();
      final events = <EventEntry>[
        EventEntry(
          type: 'JobStartedEvent<int>',
          correlationId: 'job-1',
          timestamp: now,
          rawData: {},
        ),
        EventEntry(
          type: 'JobSuccessEvent<dynamic>',
          correlationId: 'job-1',
          timestamp: now.add(const Duration(milliseconds: 50)),
          rawData: {},
        ),
      ];

      final metrics = MetricsAggregator.calculate(
        events: events,
        executorCount: 1,
        networkQueueSize: 0,
      );

      expect(metrics.successCount, 1);
      expect(metrics.failureCount, 0);
      expect(metrics.successRate, 100.0);
    });

    test('calculates peak throughput correctly', () {
      final baseTime = DateTime.now();
      // Create 5 jobs in first second, 2 in second second
      final events = <EventEntry>[
        // Second 0: 5 jobs
        ...List.generate(
          5,
          (i) => EventEntry(
            type: 'JobStartedEvent',
            correlationId: 'job-$i',
            timestamp: baseTime.add(Duration(milliseconds: i * 100)),
            rawData: {},
          ),
        ),
        // Second 1: 2 jobs
        ...List.generate(
          2,
          (i) => EventEntry(
            type: 'JobStartedEvent',
            correlationId: 'job-${i + 5}',
            timestamp: baseTime.add(Duration(milliseconds: 1000 + i * 100)),
            rawData: {},
          ),
        ),
      ];

      final metrics = MetricsAggregator.calculate(
        events: events,
        executorCount: 1,
        networkQueueSize: 0,
      );

      // Peak should be 5 (first second had 5 unique correlation IDs)
      expect(metrics.peakJobsPerSecond, 5.0);
    });

    test('detects anomalies correctly', () {
      final now = DateTime.now();
      final events = <EventEntry>[
        EventEntry(
          type: 'JobStartedEvent',
          correlationId: 'job-1',
          timestamp: now,
          rawData: {},
        ),
        EventEntry(
          type: 'JobFailureEvent',
          correlationId: 'job-1',
          timestamp: now.add(const Duration(milliseconds: 100)),
          rawData: {},
        ),
      ];

      final metrics = MetricsAggregator.calculate(
        events: events,
        executorCount: 1,
        networkQueueSize: 15, // High queue size
      );

      expect(metrics.anomalies, isNotEmpty);
      expect(
        metrics.anomalies.any((a) => a.contains('Low success rate')),
        true,
      );
      expect(
        metrics.anomalies.any((a) => a.contains('Network queue buildup')),
        true,
      );
    });

    test('extracts job type from any event in sequence', () {
      final now = DateTime.now();
      final events = <EventEntry>[
        EventEntry(
          type: 'JobProgressEvent',
          correlationId: 'job-1',
          timestamp: now,
          rawData: {},
          jobType: 'FetchDataJob', // JobType in later event
        ),
        EventEntry(
          type: 'JobSuccessEvent',
          correlationId: 'job-1',
          timestamp: now.add(const Duration(milliseconds: 100)),
          rawData: {},
        ),
      ];

      final metrics = MetricsAggregator.calculate(
        events: events,
        executorCount: 1,
        networkQueueSize: 0,
      );

      expect(metrics.jobTypeBreakdown.containsKey('FetchDataJob'), true);
      expect(metrics.jobTypeBreakdown['FetchDataJob']?.count, 1);
    });
  });
}
