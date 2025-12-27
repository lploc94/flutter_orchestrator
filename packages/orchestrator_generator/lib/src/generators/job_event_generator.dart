import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:orchestrator_core/orchestrator_core.dart';

/// Generator for classes annotated with `@GenerateJob`.
///
/// Generates an abstract class that extends BaseJob with auto-generated ID,
/// timeout, and retry policy based on annotation configuration.
class JobGenerator extends GeneratorForAnnotation<GenerateJob> {
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
    // ignore: unnecessary_null_comparison
    if (className == null || className.isEmpty) {
      throw InvalidGenerationSourceError(
        'Generator cannot target unnamed class.',
        element: element,
      );
    }

    // Read annotation values
    final timeoutReader = annotation.read('timeout');
    final maxRetriesReader = annotation.read('maxRetries');
    final retryDelayReader = annotation.read('retryDelay');
    final idPrefixReader = annotation.read('idPrefix');

    String? timeoutCode;
    if (!timeoutReader.isNull) {
      final microseconds = timeoutReader.read('_duration').intValue;
      timeoutCode = 'Duration(microseconds: $microseconds)';
    }

    String? retryPolicyCode;
    if (!maxRetriesReader.isNull) {
      final maxRetries = maxRetriesReader.intValue;
      String delayCode = 'Duration(seconds: 1)';
      if (!retryDelayReader.isNull) {
        final delayMicroseconds = retryDelayReader.read('_duration').intValue;
        delayCode = 'Duration(microseconds: $delayMicroseconds)';
      }
      retryPolicyCode =
          'RetryPolicy(maxRetries: $maxRetries, initialDelay: $delayCode)';
    }

    String idPrefix = _toSnakeCase(className);
    if (!idPrefixReader.isNull) {
      idPrefix = idPrefixReader.stringValue;
    }

    // Fields reserved for future use (e.g., copyWith generation)
    // final fields = classElement.fields
    //     .where((f) => !f.isStatic && !f.isSynthetic)
    //     .toList();

    final buffer = StringBuffer();
    buffer.writeln('// ignore_for_file: unused_element');

    // Generate abstract class that extends BaseJob
    buffer.writeln('abstract class _\$${className} extends BaseJob {');

    // Constructor
    buffer.writeln('  _\$${className}({');
    buffer.writeln('    super.cancellationToken,');
    buffer.writeln('    super.metadata,');
    buffer.writeln('    super.strategy,');
    buffer.writeln('  }) : super(');

    // Pass ID
    buffer.writeln("          id: generateJobId('$idPrefix'),");

    // Pass timeout if configured
    if (timeoutCode != null) {
      buffer.writeln('          timeout: $timeoutCode,');
    }

    // Pass retry policy if configured
    if (retryPolicyCode != null) {
      buffer.writeln('          retryPolicy: $retryPolicyCode,');
    }

    buffer.writeln('        );');
    buffer.writeln('}');

    return buffer.toString();
  }

  String _toSnakeCase(String input) {
    return input
        .replaceAllMapped(
          RegExp(r'[A-Z]'),
          (match) => '_${match.group(0)!.toLowerCase()}',
        )
        .substring(1); // Remove leading underscore
  }
}

/// Generator for classes annotated with `@GenerateEvent`.
///
/// Generates a wrapper class that extends BaseEvent.
class EventGenerator extends GeneratorForAnnotation<GenerateEvent> {
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
    if (className == null || className.isEmpty) {
      throw InvalidGenerationSourceError(
        'Generator cannot target unnamed class.',
        element: element,
      );
    }

    // Fields reserved for future use
    // final fields = classElement.fields
    //     .where((f) => !f.isStatic && !f.isSynthetic)
    //     .toList();

    final buffer = StringBuffer();
    buffer.writeln('// ignore_for_file: unused_element');

    // Generate extension with factory
    buffer.writeln('extension _\$${className}Event on $className {');

    // Generate a method to create BaseEvent wrapper
    buffer.writeln('  BaseEvent toEvent(String correlationId) {');
    buffer
        .writeln('    return _${className}EventWrapper(correlationId, this);');
    buffer.writeln('  }');
    buffer.writeln('}');
    buffer.writeln();

    // Generate wrapper class
    buffer.writeln('class _${className}EventWrapper extends BaseEvent {');
    buffer.writeln('  final $className payload;');
    buffer.writeln(
        '  _${className}EventWrapper(super.correlationId, this.payload);');
    buffer.writeln('}');

    return buffer.toString();
  }
}
