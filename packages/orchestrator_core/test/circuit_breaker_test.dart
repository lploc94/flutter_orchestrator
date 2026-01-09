import 'package:test/test.dart';
import 'package:orchestrator_core/orchestrator_core.dart';

// Custom events for circuit breaker tests
class FloodEvent extends BaseEvent {
  final int index;
  FloodEvent(super.correlationId, this.index);
}

class AnotherEvent extends BaseEvent {
  final int index;
  AnotherEvent(super.correlationId, this.index);
}

class SimpleCompletedEvent extends BaseEvent {
  final String result;
  SimpleCompletedEvent(super.correlationId, this.result);
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
      SignalBus.scoped();
      orchestrator = CircuitBreakerOrchestrator();
      OrchestratorConfig.maxEventsPerSecond = 50;
    });

    tearDown(() {
      orchestrator.dispose();
    });

    test('allows events under limit', () async {
      for (int i = 0; i < 10; i++) {
        SignalBus.instance.emit(FloodEvent('test-$i', i));
      }

      await Future.delayed(const Duration(milliseconds: 50));

      expect(orchestrator.receivedEvents.length, equals(10));
    });

    test('blocks events exceeding per-type limit', () async {
      OrchestratorConfig.maxEventsPerSecond = 5;

      for (int i = 0; i < 10; i++) {
        SignalBus.instance.emit(FloodEvent('flood-$i', i));
      }

      await Future.delayed(const Duration(milliseconds: 50));

      expect(orchestrator.receivedEvents.length, equals(5));
    });

    test('blocks only specific event type, not others', () async {
      OrchestratorConfig.maxEventsPerSecond = 3;

      for (int i = 0; i < 5; i++) {
        SignalBus.instance.emit(FloodEvent('flood-$i', i));
      }

      for (int i = 0; i < 5; i++) {
        SignalBus.instance.emit(AnotherEvent('another-$i', i));
      }

      await Future.delayed(const Duration(milliseconds: 50));

      final floodCount =
          orchestrator.receivedEvents.whereType<FloodEvent>().length;
      final anotherCount =
          orchestrator.receivedEvents.whereType<AnotherEvent>().length;

      expect(floodCount, equals(3));
      expect(anotherCount, equals(3));
      expect(orchestrator.receivedEvents.length, equals(6));
    });

    test('resets counter after 1 second window', () async {
      OrchestratorConfig.maxEventsPerSecond = 3;

      for (int i = 0; i < 5; i++) {
        SignalBus.instance.emit(FloodEvent('batch1-$i', i));
      }

      await Future.delayed(const Duration(milliseconds: 50));
      expect(orchestrator.receivedEvents.length, equals(3));

      await Future.delayed(const Duration(seconds: 1));

      for (int i = 0; i < 3; i++) {
        SignalBus.instance.emit(FloodEvent('batch2-$i', i));
      }

      await Future.delayed(const Duration(milliseconds: 50));

      expect(orchestrator.receivedEvents.length, equals(6));
    });

    test('supports custom limit per event type', () async {
      OrchestratorConfig.maxEventsPerSecond = 2;
      OrchestratorConfig.setTypeLimit<AnotherEvent>(10);

      for (int i = 0; i < 5; i++) {
        SignalBus.instance.emit(FloodEvent('flood-$i', i));
        SignalBus.instance.emit(AnotherEvent('another-$i', i));
      }

      await Future.delayed(const Duration(milliseconds: 50));

      final floodCount =
          orchestrator.receivedEvents.whereType<FloodEvent>().length;
      final anotherCount =
          orchestrator.receivedEvents.whereType<AnotherEvent>().length;

      expect(floodCount, equals(2));
      expect(anotherCount, equals(5));
    });

    test('error in onEvent does not crash orchestrator', () async {
      final errorOrchestrator = _ThrowingOrchestrator();

      SignalBus.instance.emit(FloodEvent('normal-1', 1));
      SignalBus.instance.emit(FloodEvent('throw', 2));
      SignalBus.instance.emit(FloodEvent('normal-2', 3));

      await Future.delayed(const Duration(milliseconds: 50));

      expect(errorOrchestrator.processedCount, equals(2));

      errorOrchestrator.dispose();
    });
  });

  group('Circuit Breaker - Terminal Event Cleanup', () {
    test('removes job from tracking after terminal event', () async {
      final dispatcher = Dispatcher();
      dispatcher.register(_SimpleExecutor());

      final orchestrator = _TrackingOrchestrator();

      orchestrator.dispatchTestJob();

      await Future.delayed(const Duration(milliseconds: 10));

      await Future.delayed(const Duration(milliseconds: 100));

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

class _SimpleJob extends EventJob<String, SimpleCompletedEvent> {
  _SimpleJob();

  @override
  SimpleCompletedEvent createEventTyped(String result) =>
      SimpleCompletedEvent(id, result);
}

class _SimpleExecutor extends BaseExecutor<_SimpleJob> {
  @override
  Future<dynamic> process(_SimpleJob job) async {
    await Future.delayed(const Duration(milliseconds: 20));
    return 'done';
  }
}

class _TrackingOrchestrator extends BaseOrchestrator<String> {
  _TrackingOrchestrator() : super('init');

  int get activeJobCount => hasActiveJobs ? 1 : 0;

  void dispatchTestJob() {
    dispatch<String>(_SimpleJob());
  }

  @override
  void onEvent(BaseEvent event) {
    if (event is SimpleCompletedEvent) {
      emit('success: ${event.result}');
    }
  }
}
