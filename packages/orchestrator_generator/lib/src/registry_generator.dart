import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:orchestrator_core/orchestrator_core.dart';

/// Generator for [NetworkRegistry] annotation.
///
/// This generates a `registerNetworkJobs()` function that registers
/// all annotated job types with the [NetworkJobRegistry] for offline
/// queue restoration.
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
      // Log warning to build output
      log.warning(
        'Empty @NetworkRegistry annotation on ${element.name}. '
        'Add job types to enable offline queue restoration.',
      );
      // Return a no-op function with a warning comment
      buffer.writeln('// WARNING: No jobs registered in @NetworkRegistry');
      buffer.writeln('// Add job types to the annotation: @NetworkRegistry([MyJob, OtherJob])');
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
      if (jobType == null) {
        log.warning('Could not resolve type for job in @NetworkRegistry');
        continue;
      }

      // Get the class name without generic parameters for cleaner output
      final typeElement = jobType.element;
      final className = typeElement?.name ?? jobType.getDisplayString();

      if (className.isNotEmpty) {
        jobClassNames.add(className);
        buffer.writeln('/// - `$className`');
      }
    }

    if (jobClassNames.isEmpty) {
      log.warning(
        'No valid job types found in @NetworkRegistry on ${element.name}. '
        'Make sure all types are properly imported.',
      );
      buffer.writeln('void registerNetworkJobs() {}');
      return buffer.toString();
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
