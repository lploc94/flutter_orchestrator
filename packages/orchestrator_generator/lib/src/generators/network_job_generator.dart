import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:orchestrator_core/orchestrator_core.dart';

class NetworkJobGenerator extends GeneratorForAnnotation<NetworkJob> {
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

    final generateSerialization =
        annotation.read('generateSerialization').boolValue;

    if (!generateSerialization) {
      return '';
    }

    final className = element.name;
    // ignore: unnecessary_null_comparison
    if (className == null) {
      throw InvalidGenerationSourceError(
        'Generator cannot target unnamed class.',
        element: element,
      );
    }
    final buffer = StringBuffer();

    buffer.writeln('// ignore_for_file: unused_element');
    // Generate extension
    buffer.writeln('extension _\$${className}Serialization on $className {');

    // Generate toJson
    buffer.writeln('  Map<String, dynamic> toJson() => {');
    // Always include 'id' as it is in BaseJob
    buffer.writeln("    'id': id,");

    final fields = _getFields(element);
    for (final field in fields) {
      final jsonKey = _getJsonKey(field);
      final jsonIgnore = _hasJsonIgnore(field);

      if (jsonIgnore) continue;

      final keyName = jsonKey?.peek('name')?.stringValue ?? field.name;

      // Basic serialization - could be improved for nested objects
      buffer.writeln("    '$keyName': ${field.name},");
    }
    buffer.writeln('  };'); // End toJson

    // Generate fromJson
    buffer.writeln();
    buffer.writeln('  static $className fromJson(Map<String, dynamic> json) {');
    buffer.writeln('    return $className(');

    // Check if constructor has named parameters (assumed for now based on style)
    // In a robust generator we would inspect the constructor.
    // For now, we assume standard named constructor parameters matching fields,
    // plus 'id' which might be handled differently or passed to super.
    // BUT the RFC example shows a private constructor `_restore` or `_withId`.
    // Let's check constructor.
    final constructor = element.unnamedConstructor;
    if (constructor == null) {
      // Fallback or error
    }

    // Heuristic: If there is a constructor named `_restore`, use it.
    // Otherwise try to usage named parameters on default constructor.
    // RFC Example used `_restore`. Let's assume pattern or try to match.
    // For simplicity V1, we will generate code that expects the class to have
    // a constructor compatible with the fields.

    // We will use named arguments for all fields.
    // 'id' is special, usually BaseJob takes it.
    // If the class has an 'id' field in constructor, pass it.

    // To support `id` injection, the user usually needs a constructor that accepts `id`.
    // RFC: `SendMessageJob._restore(...)`

    // Generated code:
    // static SendMessageJob fromJson(...) => SendMessageJob(
    //   id: json['id'], ...
    // );

    // We'll iterate fields again.
    // This is brittle without inspecting constructor.
    // Let's assume the user has a constructor that accepts these fields as named params.

    // Special handling for ID: BaseJob has `id`.
    // If the constructor has a parameter named `id`, we pass it.

    // We won't inspect constructor deeply in this step to keep it simple,
    // just writing out named params matching fields.

    // If 'id' is not in fields list (it's in BaseJob), we need to manually add it
    // IF the constructor expects it.

    // Better strategy for V1:
    // Assume factory/constructor accepts named params for all serialized fields.
    // Checks for `id` param specifically.

    // Let's check if `id` is a parameter in the default constructor.
    bool hasIdParam =
        constructor?.parameters.any((p) => p.name == 'id') ?? false;

    if (hasIdParam) {
      buffer.writeln("      id: json['id'] as String,");
    }

    for (final field in fields) {
      if (_hasJsonIgnore(field)) continue;
      final jsonKey = _getJsonKey(field);
      final keyName = jsonKey?.peek('name')?.stringValue ?? field.name;
      final defaultValue = jsonKey?.peek('defaultValue');

      String valueExpression = "json['$keyName']";

      // Handle types
      if (field.type.isDartCoreString) {
        valueExpression += " as String";
      } else if (field.type.isDartCoreInt) {
        valueExpression += " as int";
      } else if (field.type.isDartCoreDouble) {
        valueExpression += " as double";
      } else if (field.type.isDartCoreBool) {
        valueExpression += " as bool";
      }
      // Add more type support or dynamic cast

      if (defaultValue != null) {
        // If default value provided, handle null
        // valueExpression = "json['$keyName'] ...";
        // Defaults in annotation are tricky to convert to code string unless literal.
      }

      // Force cast for now, naive implementation
      if (field.type is! DynamicType) {
        // valueExpression += " as ${field.type.getDisplayString(withNullability: true)}";
      }

      buffer.writeln("      ${field.name}: $valueExpression,");
    }

    buffer.writeln('    );');
    buffer.writeln('  }'); // End fromJson

    // Generate fromJsonToBase
    buffer.writeln();
    buffer.writeln('  // ignore: unused_element');
    buffer.writeln(
        '  static BaseJob fromJsonToBase(Map<String, dynamic> json) => fromJson(json);');

    buffer.writeln('}'); // End extension

    return buffer.toString();
  }

  List<FieldElement> _getFields(ClassElement element) {
    return element.fields.where((f) => !f.isStatic && !f.isSynthetic).toList();
  }

  ConstantReader? _getJsonKey(FieldElement field) {
    final annotation = TypeChecker.fromRuntime(JsonKey)
        .firstAnnotationOf(field, throwOnUnresolved: false);
    if (annotation != null) return ConstantReader(annotation);
    return null;
  }

  bool _hasJsonIgnore(FieldElement field) {
    return TypeChecker.fromRuntime(JsonIgnore)
        .hasAnnotationOf(field, throwOnUnresolved: false);
  }
}
