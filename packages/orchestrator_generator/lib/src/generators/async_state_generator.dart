import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:orchestrator_core/orchestrator_core.dart';

/// Generator for classes annotated with `@GenerateAsyncState`.
///
/// Generates copyWith, state transition methods, and pattern matching.
class AsyncStateGenerator extends GeneratorForAnnotation<GenerateAsyncState> {
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
    final generateEquality = annotation.read('generateEquality').boolValue;

    // Get all instance fields
    final fields = classElement.fields
        .where((f) => !f.isStatic && !f.isSynthetic)
        .toList();

    final buffer = StringBuffer();
    buffer.writeln('// ignore_for_file: unused_element');
    buffer.writeln();

    // Define sentinel constant
    buffer.writeln('const _\$${className}Sentinel = Object();');
    buffer.writeln();

    buffer.writeln('extension ${className}Generated on $className {');

    // Generate copyWith
    _generateCopyWith(buffer, className, fields);

    // Generate state transition methods
    _generateTransitionMethods(buffer, className, fields);

    // Generate when/maybeWhen
    _generatePatternMatching(buffer, className, fields);

    buffer.writeln('}');

    // Generate equality if requested
    if (generateEquality) {
      _generateEquality(buffer, className, fields);
    }

    return buffer.toString();
  }

  void _generateCopyWith(
    StringBuffer buffer,
    String className,
    List<FieldElement> fields,
  ) {
    // Build parameter list with Object? type and _sentinel default
    final params = fields.map((f) {
      return 'Object? ${f.name} = _\$${className}Sentinel';
    }).join(', ');

    buffer.writeln('  $className copyWith({$params}) {');
    buffer.writeln('    return $className(');
    for (final field in fields) {
      final fieldName = field.name;
      final fieldType = field.type.getDisplayString();
      // If type is explicitly Object? or dynamic, cast is unnecessary because param is Object?
      // Note: we check for specific strings. Might need more robust check for alias but this covers 99%
      final cast = (fieldType == 'Object?' || fieldType == 'dynamic')
          ? ''
          : ' as $fieldType';

      // If sentinel, use this.field; otherwise cast to proper type
      buffer.writeln(
          '      $fieldName: $fieldName == _\$${className}Sentinel ? this.$fieldName : $fieldName$cast,');
    }
    buffer.writeln('    );');
    buffer.writeln('  }');
    buffer.writeln();
  }

  void _generateTransitionMethods(
    StringBuffer buffer,
    String className,
    List<FieldElement> fields,
  ) {
    // Check if class has 'status' field of type AsyncStatus
    final hasStatusField = fields.any((f) =>
        f.name == 'status' &&
        f.type.getDisplayString().contains('AsyncStatus'));

    // Check for common data/error field patterns
    final hasDataField = fields.any((f) => f.name == 'data');
    final hasErrorField =
        fields.any((f) => f.name == 'error' || f.name == 'errorMessage');
    final errorFieldName =
        fields.any((f) => f.name == 'error') ? 'error' : 'errorMessage';

    if (hasStatusField) {
      // toLoading
      buffer.writeln(
          '  $className toLoading() => copyWith(status: AsyncStatus.loading);');
      buffer.writeln();

      // toRefreshing
      buffer.writeln(
          '  $className toRefreshing() => copyWith(status: AsyncStatus.refreshing);');
      buffer.writeln();

      // toSuccess (with optional data param if data field exists)
      if (hasDataField) {
        final dataField = fields.firstWhere((f) => f.name == 'data');
        final dataType = dataField.type.getDisplayString();
        buffer.writeln('  $className toSuccess($dataType data) => copyWith(');
        buffer.writeln('    status: AsyncStatus.success,');
        buffer.writeln('    data: data,');
        buffer.writeln('  );');
      } else {
        buffer.writeln(
            '  $className toSuccess() => copyWith(status: AsyncStatus.success);');
      }
      buffer.writeln();

      // toFailure
      if (hasErrorField) {
        buffer.writeln('  $className toFailure(Object error) => copyWith(');
        buffer.writeln('    status: AsyncStatus.failure,');
        buffer.writeln('    $errorFieldName: error,');
        buffer.writeln('  );');
      } else {
        buffer.writeln(
            '  $className toFailure() => copyWith(status: AsyncStatus.failure);');
      }
      buffer.writeln();
    }
  }

  void _generatePatternMatching(
    StringBuffer buffer,
    String className,
    List<FieldElement> fields,
  ) {
    final hasStatusField = fields.any((f) =>
        f.name == 'status' &&
        f.type.getDisplayString().contains('AsyncStatus'));

    if (!hasStatusField) return;

    final hasDataField = fields.any((f) => f.name == 'data');
    final hasErrorField =
        fields.any((f) => f.name == 'error' || f.name == 'errorMessage');
    final errorFieldName =
        fields.any((f) => f.name == 'error') ? 'error' : 'errorMessage';

    // Generate when
    buffer.writeln('  R when<R>({');
    buffer.writeln('    required R Function() initial,');
    buffer.writeln('    required R Function() loading,');
    if (hasDataField) {
      final dataField = fields.firstWhere((f) => f.name == 'data');
      final dataType = dataField.type.getDisplayString();
      buffer.writeln('    required R Function($dataType data) success,');
    } else {
      buffer.writeln('    required R Function() success,');
    }
    if (hasErrorField) {
      buffer.writeln('    required R Function(Object error) failure,');
    } else {
      buffer.writeln('    required R Function() failure,');
    }
    if (hasDataField) {
      final dataField = fields.firstWhere((f) => f.name == 'data');
      final dataType = dataField.type.getDisplayString();
      buffer.writeln('    R Function($dataType data)? refreshing,');
    } else {
      buffer.writeln('    R Function()? refreshing,');
    }
    buffer.writeln('  }) {');
    buffer.writeln('    return switch (status) {');
    buffer.writeln('      AsyncStatus.initial => initial(),');
    buffer.writeln('      AsyncStatus.loading => loading(),');
    if (hasDataField) {
      buffer.writeln('      AsyncStatus.success => success(data!),');
    } else {
      buffer.writeln('      AsyncStatus.success => success(),');
    }
    if (hasErrorField) {
      buffer.writeln('      AsyncStatus.failure => failure($errorFieldName!),');
    } else {
      buffer.writeln('      AsyncStatus.failure => failure(),');
    }
    if (hasDataField) {
      buffer.writeln(
          '      AsyncStatus.refreshing => refreshing?.call(data!) ?? loading(),');
    } else {
      buffer.writeln(
          '      AsyncStatus.refreshing => refreshing?.call() ?? loading(),');
    }
    buffer.writeln('    };');
    buffer.writeln('  }');
    buffer.writeln();

    // Generate maybeWhen (shorter version)
    buffer.writeln('  R maybeWhen<R>({');
    buffer.writeln('    R Function()? initial,');
    buffer.writeln('    R Function()? loading,');
    if (hasDataField) {
      final dataField = fields.firstWhere((f) => f.name == 'data');
      final dataType = dataField.type.getDisplayString();
      buffer.writeln('    R Function($dataType data)? success,');
    } else {
      buffer.writeln('    R Function()? success,');
    }
    if (hasErrorField) {
      buffer.writeln('    R Function(Object error)? failure,');
    } else {
      buffer.writeln('    R Function()? failure,');
    }
    buffer.writeln('    required R Function() orElse,');
    buffer.writeln('  }) {');
    buffer.writeln('    return switch (status) {');
    buffer.writeln('      AsyncStatus.initial => initial?.call() ?? orElse(),');
    buffer.writeln('      AsyncStatus.loading => loading?.call() ?? orElse(),');
    if (hasDataField) {
      buffer.writeln(
          '      AsyncStatus.success => success?.call(data!) ?? orElse(),');
    } else {
      buffer
          .writeln('      AsyncStatus.success => success?.call() ?? orElse(),');
    }
    if (hasErrorField) {
      buffer.writeln(
          '      AsyncStatus.failure => failure?.call($errorFieldName!) ?? orElse(),');
    } else {
      buffer
          .writeln('      AsyncStatus.failure => failure?.call() ?? orElse(),');
    }
    buffer.writeln(
        '      AsyncStatus.refreshing => loading?.call() ?? orElse(),');
    buffer.writeln('    };');
    buffer.writeln('  }');
    buffer.writeln();
  }

  void _generateEquality(
    StringBuffer buffer,
    String className,
    List<FieldElement> fields,
  ) {
    // This would generate == and hashCode
    // Skipped for simplicity in V1 - can add later
  }
}
