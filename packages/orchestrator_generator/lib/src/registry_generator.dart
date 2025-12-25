import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:orchestrator_core/orchestrator_core.dart';

class NetworkRegistryGenerator extends GeneratorForAnnotation<NetworkRegistry> {
  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    final buffer = StringBuffer();

    // Read the list of jobs from the annotation
    // Usage: @NetworkRegistry([JobA, JobB])
    final jobs = annotation.read('jobs').listValue;

    if (jobs.isEmpty) {
      // Return a no-op function with a warning comment
      buffer.writeln('// WARNING: No jobs registered in @NetworkRegistry');
      buffer.writeln('void registerNetworkJobs() {}');
      return buffer.toString();
    }

    // Generate documentation
    buffer.writeln('/// Auto-generated function to register all network jobs.');
    buffer.writeln('/// Call this during app initialization before processing offline queue.');
    buffer.writeln('///');
    buffer.writeln('/// Registered jobs:');
    
    final jobClassNames = <String>[];
    
    for (final jobObject in jobs) {
      final jobType = jobObject.toTypeValue();
      if (jobType == null) continue;

      // Get the class name without generic parameters for cleaner output
      final element = jobType.element;
      final className = element?.name ?? jobType.getDisplayString();
      
      if (className.isNotEmpty) {
        jobClassNames.add(className);
        buffer.writeln('/// - `$className`');
      }
    }

    buffer.writeln('void registerNetworkJobs() {');

    for (final className in jobClassNames) {
      // Generate registration call
      // Assumes each Job class has a static/factory `fromJson` method
      buffer.writeln(
        "  NetworkJobRegistry.register('$className', $className.fromJson);",
      );
    }

    buffer.writeln('}');
    return buffer.toString();
  }
}
