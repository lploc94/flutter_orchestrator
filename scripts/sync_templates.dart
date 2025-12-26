#!/usr/bin/env dart
// ignore_for_file: avoid_print

/// Script to sync CLI templates from golden example files.
///
/// Usage:
///   dart run scripts/sync_templates.dart
///
/// This script reads golden example files from `examples/cli_templates/`
/// and generates Mason brick templates in `packages/orchestrator_cli/lib/src/bricks/`.
///
/// The golden files use "Counter" as the example name, which is replaced with
/// Mason template variables like `{{name.pascalCase()}}`.

import 'dart:io';

/// Template mapping configuration
const templateMappings = {
  'counter_job.dart': ('job', '{{name.snakeCase()}}_job.dart'),
  'counter_executor.dart': ('executor', '{{name.snakeCase()}}_executor.dart'),
  'counter_state.dart': ('state', '{{name.snakeCase()}}_state.dart'),
  'counter_cubit.dart': ('cubit', '{{name.snakeCase()}}_cubit.dart'),
  'counter_notifier.dart': ('notifier', '{{name.snakeCase()}}_notifier.dart'),
  'counter_riverpod.dart': ('riverpod', '{{name.snakeCase()}}_notifier.dart'),
};

/// Additional state file for composite templates (cubit, notifier, riverpod)
const compositeTemplates = ['cubit', 'notifier', 'riverpod'];

void main() async {
  final projectRoot = Directory.current.path;
  final goldenDir = Directory('$projectRoot/examples/cli_templates');
  final bricksDir = Directory(
    '$projectRoot/packages/orchestrator_cli/lib/src/bricks',
  );

  print('🔄 Syncing CLI templates from golden examples...\n');

  if (!goldenDir.existsSync()) {
    print('❌ Golden directory not found: ${goldenDir.path}');
    exit(1);
  }

  var synced = 0;

  for (final entry in templateMappings.entries) {
    final sourceFile = File('${goldenDir.path}/${entry.key}');
    final (brickName, outputFileName) = entry.value;

    if (!sourceFile.existsSync()) {
      print('⚠️  Skipping ${entry.key}: file not found');
      continue;
    }

    final content = sourceFile.readAsStringSync();
    final transformed = transformToTemplate(content);

    final outputDir = Directory('${bricksDir.path}/$brickName/__brick__');
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    final outputFile = File('${outputDir.path}/$outputFileName');
    outputFile.writeAsStringSync(transformed);

    print('✅ ${entry.key} → bricks/$brickName/__brick__/$outputFileName');
    synced++;
  }

  // Sync state file to composite templates
  final stateSource = File('${goldenDir.path}/counter_state.dart');
  if (stateSource.existsSync()) {
    final stateContent = stateSource.readAsStringSync();
    final stateTransformed = transformToTemplate(stateContent);

    for (final brickName in compositeTemplates) {
      final outputDir = Directory('${bricksDir.path}/$brickName/__brick__');
      final outputFile = File(
        '${outputDir.path}/{{name.snakeCase()}}_state.dart',
      );
      outputFile.writeAsStringSync(stateTransformed);
      print(
        '✅ counter_state.dart → bricks/$brickName/__brick__/{{name.snakeCase()}}_state.dart',
      );
      synced++;
    }
  }

  print('\n🎉 Synced $synced template files!');
}

/// Transform golden example code to Mason template syntax
String transformToTemplate(String content) {
  var result = content;

  // Remove template marker comments
  result = result.replaceAll(RegExp(r'// @template-name:.*\n'), '');
  result = result.replaceAll(
    RegExp(r'// Golden example file for CLI template generation\n'),
    '',
  );
  result = result.replaceAll(
    RegExp(r'// Run: dart run scripts/sync_templates.dart\n'),
    '',
  );

  // Order matters! Replace longer patterns first to avoid partial replacements

  // Import statements with quotes
  result = result.replaceAll(
    "'counter_state.dart'",
    "'{{name.snakeCase()}}_state.dart'",
  );
  result = result.replaceAll(
    "'counter_job.dart'",
    "'{{name.snakeCase()}}_job.dart'",
  );

  // PascalCase patterns (class names, type names)
  result = result.replaceAll('CounterCubit', '{{name.pascalCase()}}Cubit');
  result = result.replaceAll('CounterState', '{{name.pascalCase()}}State');
  result = result.replaceAll('CounterJob', '{{name.pascalCase()}}Job');
  result = result.replaceAll(
    'CounterExecutor',
    '{{name.pascalCase()}}Executor',
  );
  result = result.replaceAll(
    'CounterNotifier',
    '{{name.pascalCase()}}Notifier',
  );
  result = result.replaceAll('Counter', '{{name.pascalCase()}}');

  // camelCase patterns (variables, provider names)
  result = result.replaceAll('counterProvider', '{{name.camelCase()}}Provider');

  // snake_case patterns (in generateJobId, file names)
  result = result.replaceAll("'counter'", "'{{name.snakeCase()}}'");

  // Clean up any leftover empty newlines at the start
  result = result.replaceFirst(RegExp(r'^\n+'), '');

  return result;
}
