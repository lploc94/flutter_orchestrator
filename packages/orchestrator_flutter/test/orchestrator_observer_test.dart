// Unit tests for OrchestratorObserver event structures.

import 'package:flutter_test/flutter_test.dart';
import 'package:orchestrator_core/orchestrator_core.dart';

void main() {
  group('OrchestratorObserver Event Structures', () {
    test('JobStartedEvent has correct fields', () {
      final event = JobStartedEvent('test-123', jobType: 'TestJob');

      expect(event.jobType, 'TestJob');
      expect(event.correlationId, 'test-123');
    });

    test('JobSuccessEvent has correct fields', () {
      final event =
          JobSuccessEvent<String>('test-123', 'result', isOptimistic: true);

      expect(event.data, 'result');
      expect(event.isOptimistic, true);
    });

    test('JobProgressEvent clamps progress to 0-1 range', () {
      final event = JobProgressEvent('test-123', progress: 1.5);

      expect(event.progress, 1.0); // Clamped from 1.5
    });

    test('ExecutorRegistryEvent stores registry', () {
      final event = ExecutorRegistryEvent({'TestJob': 'TestExecutor'});

      expect(event.registry, {'TestJob': 'TestExecutor'});
    });
  });
}
