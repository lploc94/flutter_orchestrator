import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:orchestrator_core/orchestrator_core.dart';

/// Generator for classes annotated with `@TypedJob`.
///
/// Generates a sealed job hierarchy from an abstract interface class.
/// Each method in the interface becomes a concrete job class.
class TypedJobGenerator extends GeneratorForAnnotation<TypedJob> {
  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        '@TypedJob can only be applied to abstract classes.',
        element: element,
      );
    }

    final classElement = element;
    if (!classElement.isAbstract) {
      throw InvalidGenerationSourceError(
        '@TypedJob can only be applied to abstract classes.',
        element: element,
      );
    }

    final interfaceName = classElement.name;
    if (interfaceName.isEmpty) {
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
    final interfaceSuffixReader = annotation.read('interfaceSuffix');

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
          'RetryPolicy(maxRetries: $maxRetries, baseDelay: $delayCode)';
    }

    // Derive sealed class name from interface name
    final interfaceSuffix = interfaceSuffixReader.isNull
        ? 'Interface'
        : interfaceSuffixReader.stringValue;

    String sealedClassName;
    if (interfaceName.endsWith(interfaceSuffix)) {
      sealedClassName =
          interfaceName.substring(0, interfaceName.length - interfaceSuffix.length);
    } else {
      sealedClassName = interfaceName;
    }

    // Ensure it ends with 'Job'
    if (!sealedClassName.endsWith('Job')) {
      sealedClassName = '${sealedClassName}Job';
    }

    final idPrefix = idPrefixReader.isNull
        ? _toSnakeCase(sealedClassName)
        : idPrefixReader.stringValue;

    // Get all abstract methods
    final methods = classElement.methods.where((m) => m.isAbstract).toList();

    if (methods.isEmpty) {
      throw InvalidGenerationSourceError(
        '@TypedJob interface must have at least one abstract method.',
        element: element,
      );
    }

    final buffer = StringBuffer();
    buffer.writeln(
      '// ignore_for_file: type=lint, unused_element',
    );
    buffer.writeln();

    // Generate sealed base class
    buffer.writeln('/// Sealed base class for ${interfaceName} jobs.');
    buffer.writeln('sealed class $sealedClassName extends BaseJob {');
    buffer.writeln('  $sealedClassName({');
    buffer.writeln('    required super.id,');
    if (timeoutCode != null) {
      buffer.writeln('    super.timeout = $timeoutCode,');
    } else {
      buffer.writeln('    super.timeout,');
    }
    if (retryPolicyCode != null) {
      buffer.writeln('    super.retryPolicy = $retryPolicyCode,');
    } else {
      buffer.writeln('    super.retryPolicy,');
    }
    buffer.writeln('    super.cancellationToken,');
    buffer.writeln('    super.metadata,');
    buffer.writeln('    super.strategy,');
    buffer.writeln('  });');
    buffer.writeln('}');
    buffer.writeln();

    // Generate concrete job class for each method
    for (final method in methods) {
      _generateJobClass(
        buffer,
        method,
        sealedClassName,
        idPrefix,
        timeoutCode,
        retryPolicyCode,
      );
    }

    return buffer.toString();
  }

  void _generateJobClass(
    StringBuffer buffer,
    MethodElement method,
    String sealedClassName,
    String idPrefix,
    String? timeoutCode,
    String? retryPolicyCode,
  ) {
    final methodName = method.name;
    final jobClassName = '${_toPascalCase(methodName)}Job';
    final jobIdPrefix = '${idPrefix}_${_toSnakeCase(methodName)}';

    // Get parameters
    final params = method.parameters;
    final hasParams = params.isNotEmpty;

    // Check if all params are named
    final allNamed = params.every((p) => p.isNamed);
    final allPositional = params.every((p) => p.isPositional);

    buffer.writeln('/// Job generated from `$methodName` method.');
    buffer.writeln('class $jobClassName extends $sealedClassName {');

    // Generate fields
    for (final param in params) {
      final typeName = param.type.getDisplayString();
      buffer.writeln('  final $typeName ${param.name};');
    }

    if (hasParams) {
      buffer.writeln();
    }

    // Generate constructor
    if (!hasParams) {
      // No params constructor
      buffer.writeln('  $jobClassName({');
      buffer.writeln('    super.timeout,');
      buffer.writeln('    super.retryPolicy,');
      buffer.writeln('    super.cancellationToken,');
      buffer.writeln('    super.metadata,');
      buffer.writeln('    super.strategy,');
      buffer.writeln("  }) : super(id: generateJobId('$jobIdPrefix'));");
    } else if (allNamed) {
      // Named params constructor
      buffer.writeln('  $jobClassName({');
      for (final param in params) {
        final required = param.isRequired ? 'required ' : '';
        final defaultValue =
            param.hasDefaultValue ? ' = ${param.defaultValueCode}' : '';
        buffer.writeln('    ${required}this.${param.name}$defaultValue,');
      }
      buffer.writeln('    super.timeout,');
      buffer.writeln('    super.retryPolicy,');
      buffer.writeln('    super.cancellationToken,');
      buffer.writeln('    super.metadata,');
      buffer.writeln('    super.strategy,');
      buffer.writeln("  }) : super(id: generateJobId('$jobIdPrefix'));");
    } else if (allPositional) {
      // Positional params constructor
      buffer.write('  $jobClassName(');
      buffer.write(params.map((p) => 'this.${p.name}').join(', '));
      buffer.writeln(', {');
      buffer.writeln('    super.timeout,');
      buffer.writeln('    super.retryPolicy,');
      buffer.writeln('    super.cancellationToken,');
      buffer.writeln('    super.metadata,');
      buffer.writeln('    super.strategy,');
      buffer.writeln("  }) : super(id: generateJobId('$jobIdPrefix'));");
    } else {
      // Mixed - use all named for safety
      buffer.writeln('  $jobClassName({');
      for (final param in params) {
        final required =
            param.isRequired || (param.isPositional && !param.isOptional)
                ? 'required '
                : '';
        final defaultValue =
            param.hasDefaultValue ? ' = ${param.defaultValueCode}' : '';
        buffer.writeln('    ${required}this.${param.name}$defaultValue,');
      }
      buffer.writeln('    super.timeout,');
      buffer.writeln('    super.retryPolicy,');
      buffer.writeln('    super.cancellationToken,');
      buffer.writeln('    super.metadata,');
      buffer.writeln('    super.strategy,');
      buffer.writeln("  }) : super(id: generateJobId('$jobIdPrefix'));");
    }

    buffer.writeln('}');
    buffer.writeln();
  }

  String _toSnakeCase(String input) {
    if (input.isEmpty) return input;
    return input
        .replaceAllMapped(
          RegExp(r'[A-Z]'),
          (match) => '_${match.group(0)!.toLowerCase()}',
        )
        .replaceFirst(RegExp(r'^_'), ''); // Remove leading underscore
  }

  String _toPascalCase(String input) {
    if (input.isEmpty) return input;
    return input[0].toUpperCase() + input.substring(1);
  }
}
