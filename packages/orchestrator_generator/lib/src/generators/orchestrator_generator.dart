// ignore_for_file: deprecated_member_use

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:orchestrator_core/orchestrator_core.dart';

/// Generator for classes annotated with `@Orchestrator`.
///
/// Scans for `@OnEvent` annotated methods and generates event routing logic.
class OrchestratorGenerator extends GeneratorForAnnotation<Orchestrator> {
  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        'Generator cannot target non-class element ${element.name}.',
        element: element,
      );
    }

    final classElement = element;
    final className = classElement.name;
    // ignore: unnecessary_null_comparison
    if (className == null) {
      throw InvalidGenerationSourceError(
        'Generator cannot target unnamed class.',
        element: element,
      );
    }

    // Find all methods with @OnEvent annotation
    final eventHandlers = _findEventHandlers(classElement);

    if (eventHandlers.isEmpty) {
      return ''; // No handlers, no code to generate
    }

    final buffer = StringBuffer();
    buffer.writeln('// ignore_for_file: type=lint');

    // Separate active and passive handlers
    final activeHandlers = eventHandlers.where((h) => !h.isPassive).toList();
    final passiveHandlers = eventHandlers.where((h) => h.isPassive).toList();

    // Sort by priority (higher first)
    activeHandlers.sort((a, b) => b.priority.compareTo(a.priority));
    passiveHandlers.sort((a, b) => b.priority.compareTo(a.priority));

    // Extract state type from superclass (BaseOrchestrator<StateType>)
    String stateType = 'dynamic';
    for (final supertype in classElement.allSupertypes) {
      final typeName = supertype.element.name;
      if (typeName == 'BaseOrchestrator') {
        final typeArgs = supertype.typeArguments;
        if (typeArgs.isNotEmpty) {
          stateType = typeArgs.first.getDisplayString(withNullability: true);
        }
        break;
      }
    }

    // Generate mixin with correct state type to avoid generic conflict
    buffer.writeln(
      'mixin _\$${className}EventRouting on BaseOrchestrator<$stateType> {',
    );

    // Declare abstract methods for handlers so mixin can call them
    for (final handler in eventHandlers) {
      buffer.writeln(
        '  void ${handler.methodName}(${handler.eventTypeName} event);',
      );
    }
    buffer.writeln();

    // Generate onActiveEvent override if there are active handlers
    if (activeHandlers.isNotEmpty) {
      buffer.writeln('  @override');
      buffer.writeln('  void onActiveEvent(BaseEvent event) {');
      buffer.writeln('    super.onActiveEvent(event);');
      for (final handler in activeHandlers) {
        buffer.writeln('    if (event is ${handler.eventTypeName}) {');
        buffer.writeln('      ${handler.methodName}(event);');
        buffer.writeln('      return;');
        buffer.writeln('    }');
      }
      buffer.writeln('  }');
    }

    // Generate onPassiveEvent override if there are passive handlers
    if (passiveHandlers.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('  @override');
      buffer.writeln('  void onPassiveEvent(BaseEvent event) {');
      buffer.writeln('    super.onPassiveEvent(event);');
      for (final handler in passiveHandlers) {
        buffer.writeln('    if (event is ${handler.eventTypeName}) {');
        buffer.writeln('      ${handler.methodName}(event);');
        buffer.writeln('      return;');
        buffer.writeln('    }');
      }
      buffer.writeln('  }');
    }

    buffer.writeln('}');

    return buffer.toString();
  }

  List<_EventHandler> _findEventHandlers(ClassElement classElement) {
    final handlers = <_EventHandler>[];
    final onEventChecker = TypeChecker.fromRuntime(OnEvent);

    for (final method in classElement.methods) {
      final annotation = onEventChecker.firstAnnotationOf(
        method,
        throwOnUnresolved: false,
      );
      if (annotation == null) continue;

      final reader = ConstantReader(annotation);

      // Get event type from annotation
      final eventTypeValue = reader.read('eventType');
      String eventTypeName;

      if (eventTypeValue.isType) {
        eventTypeName = eventTypeValue.typeValue.getDisplayString(
          withNullability: true,
        );
      } else {
        // Fallback: try to get from method parameter
        if (method.parameters.isNotEmpty) {
          eventTypeName = method.parameters.first.type.getDisplayString(
            withNullability: true,
          );
        } else {
          continue; // Skip invalid handler
        }
      }

      final isPassive = reader.read('passive').boolValue;
      final priority = reader.read('priority').intValue;

      handlers.add(
        _EventHandler(
          methodName: method.name,
          eventTypeName: eventTypeName,
          isPassive: isPassive,
          priority: priority,
        ),
      );
    }

    return handlers;
  }
}

class _EventHandler {
  final String methodName;
  final String eventTypeName;
  final bool isPassive;
  final int priority;

  _EventHandler({
    required this.methodName,
    required this.eventTypeName,
    required this.isPassive,
    required this.priority,
  });
}
