import 'package:test/test.dart';
import 'package:orchestrator_core/orchestrator_core.dart';
import 'dart:async';

// Reuse test classes
class TestJob extends BaseJob {
  final int value;
  TestJob(this.value)
      : super(id: 'job-${DateTime.now().millisecondsSinceEpoch}-$value');
}

class TestExecutor extends BaseExecutor<TestJob> {
  @override
  Future<dynamic> process(TestJob job) async {
    await Future.delayed(Duration(milliseconds: 10));
    return job.value * 2;
  }
}

class TestOrchestrator extends BaseOrchestrator<String> {
  final List<String> eventLog = [];

  TestOrchestrator({SignalBus? bus}) : super('Init', bus: bus);

  @override
  void onActiveSuccess(JobSuccessEvent event) {
    eventLog.add('Success:${event.data}');
    emit('Success: ${event.data}');
  }

  String run(int val) => dispatch(TestJob(val));
}

void main() {
  final dispatcher = Dispatcher();

  setUp(() {
    dispatcher.clear();
    dispatcher.register(TestExecutor());
  });

  group('Scoped Bus Isolation', () {
    test('Events are isolated between scopes', () async {
      // Setup Scope 1
      final bus1 = SignalBus.scoped();
      final orc1 = TestOrchestrator(bus: bus1);

      // Setup Scope 2
      final bus2 = SignalBus.scoped();
      final orc2 = TestOrchestrator(bus: bus2);

      // Spy on Global
      final globalEvents = <BaseEvent>[];
      final globalSub = SignalBus.instance.stream.listen(globalEvents.add);

      // Run Job in Scope 1
      orc1.run(10);

      await Future.delayed(Duration(milliseconds: 50));

      // Verify Scope 1 got it
      expect(orc1.eventLog, contains('Success:20'));

      // Verify Scope 2 saw NOTHING
      expect(orc2.eventLog, isEmpty);

      // Verify Global Bus saw NOTHING
      expect(globalEvents, isEmpty);

      await globalSub.cancel();
      orc1.dispose();
      orc2.dispose();
      bus1.dispose();
      bus2.dispose();
    });

    test('Global Orchestrator still uses Global Bus', () async {
      final orcGlobal = TestOrchestrator();
      final globalEvents = <BaseEvent>[];
      final globalSub = SignalBus.instance.stream.listen(globalEvents.add);

      orcGlobal.run(5);
      await Future.delayed(Duration(milliseconds: 50));

      expect(orcGlobal.eventLog, contains('Success:10'));
      expect(globalEvents.length, greaterThan(0));

      await globalSub.cancel();
      orcGlobal.dispose();
    });
  });
}
