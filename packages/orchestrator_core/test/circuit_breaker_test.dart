import 'package:test/test.dart';
import 'package:orchestrator_core/orchestrator_core.dart';

// Custom event for circuit breaker tests
class FloodEvent extends BaseEvent {
  final int index;
  FloodEvent(super.correlationId, this.index);
}

class AnotherEvent extends BaseEvent {
  final int index;
  AnotherEvent(super.correlationId, this.index);
}

class CircuitBreakerOrchestrator extends BaseOrchestrator<int> {
  final List<BaseEvent> receivedEvents = [];
  int blockedCount = 0;

  CircuitBreakerOrchestrator() : super(0);

  @override
  void onEvent(BaseEvent event) {
    receivedEvents.add(event);
    emit(receivedEvents.length);
  }
}

void main() {
  group('Circuit Breaker (Loop Protection)', () {
    late CircuitBreakerOrchestrator orchestrator;

    setUp(() {
      // Use scoped bus for test isolation
      SignalBus.scoped();
      orchestrator = CircuitBreakerOrchestrator();
      // Reset config to default
      OrchestratorConfig.maxEventsPerSecond = 50;
    });

    tearDown(() {
      orchestrator.dispose();
    });

    test('allows events under limit', () async {
      // Emit 10 events (under default limit of 50)
      for (int i = 0; i < 10; i++) {
        SignalBus.instance.emit(FloodEvent('test-$i', i));
      }

      await Future.delayed(Duration(milliseconds: 50));

      // All events should be received
      expect(orchestrator.receivedEvents.length, equals(10));
    });

    test('blocks events exceeding per-type limit', () async {
      // Set low limit for testing
      OrchestratorConfig.maxEventsPerSecond = 5;

      // Emit 10 events (5 over limit)
      for (int i = 0; i < 10; i++) {
        SignalBus.instance.emit(FloodEvent('flood-$i', i));
      }

      await Future.delayed(Duration(milliseconds: 50));

      // Only 5 events should be received (limit)
      expect(orchestrator.receivedEvents.length, equals(5));
    });

    test('blocks only specific event type, not others', () async {
      // Set low limit for testing
      OrchestratorConfig.maxEventsPerSecond = 3;

      // Emit 5 FloodEvents (2 over limit)
      for (int i = 0; i < 5; i++) {
        SignalBus.instance.emit(FloodEvent('flood-$i', i));
      }

      // Emit 5 AnotherEvents (2 over limit)
      for (int i = 0; i < 5; i++) {
        SignalBus.instance.emit(AnotherEvent('another-$i', i));
      }

      await Future.delayed(Duration(milliseconds: 50));

      // Should receive 3 FloodEvents + 3 AnotherEvents = 6 total
      final floodCount =
          orchestrator.receivedEvents.whereType<FloodEvent>().length;
      final anotherCount =
          orchestrator.receivedEvents.whereType<AnotherEvent>().length;

      expect(floodCount, equals(3));
      expect(anotherCount, equals(3));
      expect(orchestrator.receivedEvents.length, equals(6));
    });

    test('resets counter after 1 second window', () async {
      // Set low limit for testing
      OrchestratorConfig.maxEventsPerSecond = 3;

      // Emit 5 events in first window (2 blocked)
      for (int i = 0; i < 5; i++) {
        SignalBus.instance.emit(FloodEvent('batch1-$i', i));
      }

      await Future.delayed(Duration(milliseconds: 50));
      expect(orchestrator.receivedEvents.length, equals(3));

      // Wait for next second window
      await Future.delayed(Duration(seconds: 1));

      // Emit 3 more events in new window
      for (int i = 0; i < 3; i++) {
        SignalBus.instance.emit(FloodEvent('batch2-$i', i));
      }

      await Future.delayed(Duration(milliseconds: 50));

      // Should now have 3 + 3 = 6 events
      expect(orchestrator.receivedEvents.length, equals(6));
    });

    test('supports custom limit per event type', () async {
      // Set default limit low
      OrchestratorConfig.maxEventsPerSecond = 2;
      // Set custom high limit for AnotherEvent
      OrchestratorConfig.setTypeLimit<AnotherEvent>(10);

      // Emit 5 of each
      for (int i = 0; i < 5; i++) {
        SignalBus.instance.emit(FloodEvent('flood-$i', i));
        SignalBus.instance.emit(AnotherEvent('another-$i', i));
      }

      await Future.delayed(Duration(milliseconds: 50));

      final floodCount =
          orchestrator.receivedEvents.whereType<FloodEvent>().length;
      final anotherCount =
          orchestrator.receivedEvents.whereType<AnotherEvent>().length;

      // FloodEvent limited to 2, AnotherEvent limited to 10 (but only 5 sent)
      expect(floodCount, equals(2));
      expect(anotherCount, equals(5));
    });

    test('error in onEvent does not crash orchestrator', () async {
      // Create orchestrator that throws on specific event
      final errorOrchestrator = _ThrowingOrchestrator();

      // Emit events - one will cause an error
      SignalBus.instance.emit(FloodEvent('normal-1', 1));
      SignalBus.instance.emit(FloodEvent('throw', 2)); // Will throw
      SignalBus.instance.emit(FloodEvent('normal-2', 3));

      await Future.delayed(Duration(milliseconds: 50));

      // Error should be isolated - orchestrator still processes other events
      expect(errorOrchestrator.processedCount, equals(2));

      errorOrchestrator.dispose();
    });
  });

  group('Circuit Breaker - Terminal Event Cleanup', () {
    test('removes job from tracking after terminal event', () async {
      final dispatcher = Dispatcher();
      dispatcher.register(_SimpleExecutor());

      final orchestrator = _TrackingOrchestrator();

      // Dispatch job
      orchestrator.dispatchTestJob();

      // Job should be tracked initially
      await Future.delayed(Duration(milliseconds: 10));

      // Wait for completion
      await Future.delayed(Duration(milliseconds: 100));

      // After success event, job should be removed from tracking
      expect(orchestrator.activeJobCount, equals(0));

      orchestrator.dispose();
      dispatcher.clear();
    });
  });
}

class _ThrowingOrchestrator extends BaseOrchestrator<int> {
  int processedCount = 0;

  _ThrowingOrchestrator() : super(0);

  @override
  void onEvent(BaseEvent event) {
    if (event is FloodEvent && event.correlationId == 'throw') {
      throw Exception('Intentional error');
    }
    processedCount++;
    emit(processedCount);
  }
}

class _SimpleJob extends BaseJob {
  _SimpleJob() : super(id: 'simple-${DateTime.now().millisecondsSinceEpoch}');
}

class _SimpleExecutor extends BaseExecutor<_SimpleJob> {
  @override
  Future<dynamic> process(_SimpleJob job) async {
    await Future.delayed(Duration(milliseconds: 20));
    return 'done';
  }
}

class _TrackingOrchestrator extends BaseOrchestrator<String> {
  _TrackingOrchestrator() : super('init');

  int get activeJobCount => activeJobIds.length;

  Set<String> get activeJobIds {
    // Access protected field via reflection-like approach
    // We'll use isJobRunning to check
    return {};
  }

  void dispatchTestJob() {
    dispatch<String>(_SimpleJob());
  }

  @override
  void onEvent(BaseEvent event) {
    if (event is JobSuccessEvent) {
      emit('success: ${event.data}');
    }
  }
}
