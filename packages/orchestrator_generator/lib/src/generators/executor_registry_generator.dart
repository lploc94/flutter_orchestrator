import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:orchestrator_core/orchestrator_core.dart';

class ExecutorRegistryGenerator
    extends GeneratorForAnnotation<ExecutorRegistry> {
  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    // Expected usage on a top-level function or class?
    // RFC says: @ExecutorRegistry(...) void setupExecutors(...)

    // We generate a separate function `registerExecutors`?
    // Or we extend the function?

    // RFC generated code:
    // void registerExecutors(ApiService api) { ... }

    // If the annotation is on a function, we can copy its parameters?
    // Or we just generate a standard function name?

    // Let's parse the entries.
    final entries = annotation.read('entries').listValue;

    if (entries.isEmpty) return '// No executors registered';

    final buffer = StringBuffer();

    // We need to know what the input function looks like to match signature if we want to be smart.
    // For now, let's assume we generate a standalone `registerExecutors` function that takes a Dispatcher
    // and maybe the dependencies?
    // Dependency injection is hard to guess.

    // Alternative: The user registers the mapping, but how do we construct the Executors?
    // The Executors might need params.
    // RFC example: `(FetchUserJob, FetchUserExecutor)`
    // And generated: `dispatcher.register<FetchUserJob>(FetchUserExecutor(api))`

    // How do we know to pass `api`? We don't.
    // The previous code snippet `setupExecutors(ApiService api)` suggests the user provides the scope.

    // If we can't infer dependencies, we can't instantiate Executors automatically unless:
    // 1. They have no-arg constructors.
    // 2. We use a service locator.

    // If the RFC assumes `FetchUserExecutor(api)`, it means the generator sees that `FetchUserExecutor` needs `api`.
    // But where does `api` come from? From `registerExecutors` arguments.
    // So `setupExecutors(ApiService api)` has the arg.

    // Strategy:
    // 1. Inspect the annotated element (function).
    // 2. Copy its parameters to the generated function.
    // 3. Inside generated function, instantiate Executors.
    // 4. Match function parameters to Executor constructor parameters by type or name?
    // This is complex "Wiring".

    // SIMPLIFICATION for V1:
    // Just generate the body lines that can be copy-pasted or used effectively? No.
    // May be we can assume the user passes a `Resolver` or `Locator`.

    // Let's re-read RFC.
    // "void registerExecutors(ApiService api) { ... }"
    // It seems it copies the signature.

    String params = '';
    if (element is ExecutableElement) {
      // Copy parameters
      params = element.parameters.map((p) => '${p.type} ${p.name}').join(', ');
    }

    buffer.writeln('void registerExecutors($params) {');
    buffer.writeln('  final dispatcher = Dispatcher();');

    for (final entry in entries) {
      // Try to read record fields $1 (Job) and $2 (Executor)
      final jobType = entry.getField(r'$1')?.toTypeValue();
      final executorType = entry.getField(r'$2')?.toTypeValue();

      if (jobType != null && executorType != null) {
        // ignore: deprecated_member_use
        final jobName = jobType.getDisplayString(withNullability: false);
        // ignore: deprecated_member_use
        final execName = executorType.getDisplayString(withNullability: false);

        // Helper to guess constructor call.
        // If we collected params like `api`, we pass them.
        // A more robust way would be to check the Executor's constructor requirements.
        // For now, we pass `api` if the generator sees it in params, or empty default.

        // Heuristic: If function param has `ApiService api` and Executor needs it.
        // Too complex.

        // V1 Assumption: All executors follow `Executor(api)` or `Executor()` pattern
        // and we just pass `api` if present in function args.
        // Let's just blindly pass `api` if `api` param exists, or nothing.

        String constructorArgs = '';
        if (params.contains('api')) {
          constructorArgs = 'api';
        }

        buffer.writeln(
            "  dispatcher.register<$jobName>($execName($constructorArgs));");
      } else {
        buffer
            .writeln("  // Warning: Could not parse entry in ExecutorRegistry");
      }
    }

    buffer.writeln('}');

    return buffer.toString();
  }
}
