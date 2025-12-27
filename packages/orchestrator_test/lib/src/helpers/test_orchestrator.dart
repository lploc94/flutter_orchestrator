import 'dart:async';

import 'package:meta/meta.dart';
import 'package:test/test.dart' as test_pkg;
import 'package:orchestrator_core/orchestrator_core.dart';

/// A BDD-style test helper for testing [BaseOrchestrator] implementations.
///
/// Similar to `blocTest` from the `bloc_test` package, this helper provides
/// a declarative way to test orchestrator state transitions.
///
/// ## Parameters
///
/// - [description]: Test description
/// - [build]: Builds and returns the orchestrator to test
/// - [setUp]: Optional setup function called before the test
/// - [act]: Actions to perform on the orchestrator
/// - [wait]: Duration to wait for async operations to complete
/// - [expect]: Expected states (values or matchers) emitted during the test
/// - [verify]: Additional verifications after states are checked
/// - [errors]: Expected errors (currently unused, reserved for future)
/// - [skip]: Skip reason if test should be skipped
///
/// ## Example
///
/// ```dart
/// testOrchestrator<CounterOrchestrator, int>(
///   'increments counter',
///   build: () => CounterOrchestrator(),
///   act: (orchestrator) => orchestrator.increment(),
///   expect: () => [1],
/// );
/// ```
@isTest
void testOrchestrator<O extends BaseOrchestrator<S>, S>(
  String description, {
  required O Function() build,
  void Function()? setUp,
  dynamic Function(O orchestrator)? act,
  Duration wait = Duration.zero,
  dynamic Function()? expect,
  void Function(O orchestrator)? verify,
  Object? Function()? errors,
  String? skip,
}) {
  test_pkg.test(
    description,
    () async {
      if (setUp != null) {
        setUp();
      }

      final orchestrator = build();
      final states = <S>[];
      final subscription = orchestrator.stream.listen(states.add);

      try {
        if (act != null) {
          final result = act(orchestrator);
          if (result is Future) {
            await result;
          }
        }

        if (wait > Duration.zero) {
          await Future<void>.delayed(wait);
        } else {
          // Allow microtasks to complete
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }

        if (expect != null) {
          final expected = expect();
          test_pkg.expect(states, expected);
        }

        if (verify != null) {
          verify(orchestrator);
        }
      } finally {
        await subscription.cancel();
        orchestrator.dispose();
      }
    },
    skip: skip,
  );
}

/// Test helper for testing orchestrator event handling.
@isTest
void testOrchestratorEvents<O extends BaseOrchestrator<S>, S>(
  String description, {
  required O Function() build,
  required List<BaseEvent> Function() events,
  void Function()? setUp,
  Duration wait = Duration.zero,
  dynamic Function()? expect,
  void Function(O orchestrator)? verify,
  String? skip,
}) {
  test_pkg.test(
    description,
    () async {
      if (setUp != null) {
        setUp();
      }

      final orchestrator = build();
      final bus = SignalBus();
      final states = <S>[];
      final subscription = orchestrator.stream.listen(states.add);

      try {
        for (final event in events()) {
          bus.emit(event);
        }

        if (wait > Duration.zero) {
          await Future<void>.delayed(wait);
        } else {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }

        if (expect != null) {
          final expected = expect();
          test_pkg.expect(states, expected);
        }

        if (verify != null) {
          verify(orchestrator);
        }
      } finally {
        await subscription.cancel();
        orchestrator.dispose();
      }
    },
    skip: skip,
  );
}
