import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:orchestrator_core/orchestrator_core.dart';

/// Generator for classes annotated with `@OrchestratorProvider`.
///
/// Generates a Riverpod NotifierProvider for the annotated orchestrator class.
class OrchestratorProviderGenerator
    extends GeneratorForAnnotation<OrchestratorProvider> {
  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        '@OrchestratorProvider can only be applied to classes.',
        element: element,
      );
    }

    final classElement = element;
    final className = classElement.name;
    if (className.isEmpty) {
      throw InvalidGenerationSourceError(
        'Generator cannot target unnamed class.',
        element: element,
      );
    }

    // Find the state type from the superclass
    // Expecting: class MyOrchestrator extends OrchestratorNotifier<MyState>
    String? stateType;
    for (final supertype in classElement.allSupertypes) {
      final superName = supertype.element.name;
      if (superName == 'OrchestratorNotifier' ||
          superName == 'BaseOrchestrator') {
        final typeArgs = supertype.typeArguments;
        if (typeArgs.isNotEmpty) {
          stateType = typeArgs.first.getDisplayString();
        }
        break;
      }
    }

    if (stateType == null) {
      throw InvalidGenerationSourceError(
        '@OrchestratorProvider class must extend OrchestratorNotifier<State> or BaseOrchestrator<State>.',
        element: element,
      );
    }

    // Read annotation values
    final autoDisposeReader = annotation.read('autoDispose');
    final nameReader = annotation.read('name');

    final autoDispose =
        autoDisposeReader.isNull ? false : autoDisposeReader.boolValue;

    String providerName;
    if (!nameReader.isNull) {
      providerName = nameReader.stringValue;
    } else {
      // Convert ClassName to classNameProvider
      providerName = '${_toCamelCase(className)}Provider';
    }

    final buffer = StringBuffer();
    buffer.writeln('// ignore_for_file: type=lint');
    buffer.writeln();

    // Generate the provider
    buffer.writeln('/// Provider for [$className].');
    buffer.writeln('///');
    buffer.writeln('/// Generated from @OrchestratorProvider annotation.');

    if (autoDispose) {
      buffer.writeln(
        'final $providerName = NotifierProvider.autoDispose<$className, $stateType>(',
      );
    } else {
      buffer.writeln(
        'final $providerName = NotifierProvider<$className, $stateType>(',
      );
    }
    buffer.writeln('  $className.new,');
    buffer.writeln(');');

    return buffer.toString();
  }

  String _toCamelCase(String input) {
    if (input.isEmpty) return input;
    return input[0].toLowerCase() + input.substring(1);
  }
}
