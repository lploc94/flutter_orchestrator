# Template Sync Script

Script to automatically sync CLI templates from golden example files.

## Purpose

- **Single source of truth**: Edit code in `examples/cli_templates/`, templates auto-update
- **No more outdated templates**: Templates always match latest code patterns
- **Better DX**: edit real Dart code instead of Mustache templates

## Usage

```bash
# From project root
dart run scripts/sync_templates.dart
```

**Output**:
```
🔄 Syncing CLI templates from golden examples...

✅ counter_job.dart → bricks/job/__brick__/{{name.snakeCase()}}_job.dart
✅ counter_executor.dart → bricks/executor/__brick__/{{name.snakeCase()}}_executor.dart
✅ counter_state.dart → bricks/state/__brick__/{{name.snakeCase()}}_state.dart
✅ counter_cubit.dart → bricks/cubit/__brick__/{{name.snakeCase()}}_cubit.dart
✅ counter_notifier.dart → bricks/notifier/__brick__/{{name.snakeCase()}}_notifier.dart
✅ counter_riverpod.dart → bricks/riverpod/__brick__/{{name.snakeCase()}}_notifier.dart
✅ counter_state.dart → bricks/cubit/__brick__/{{name.snakeCase()}}_state.dart
✅ counter_state.dart → bricks/notifier/__brick__/{{name.snakeCase()}}_state.dart
✅ counter_state.dart → bricks/riverpod/__brick__/{{name.snakeCase()}}_state.dart

🎉 Synced 9 template files!
```

## Golden Files

| File | Template Output |
|------|-----------------|
| `counter_job.dart` | `bricks/job/__brick__/` |
| `counter_executor.dart` | `bricks/executor/__brick__/` |
| `counter_state.dart` | `bricks/state/__brick__/` (+ cubit, notifier, riverpod) |
| `counter_cubit.dart` | `bricks/cubit/__brick__/` |
| `counter_notifier.dart` | `bricks/notifier/__brick__/` |
| `counter_riverpod.dart` | `bricks/riverpod/__brick__/` |

## Transformation Rules

| Pattern | Replacement |
|---------|-------------|
| `Counter` | `{{name.pascalCase()}}` |
| `counter` | `{{name.camelCase()}}` |
| `'counter'` | `'{{name.snakeCase()}}'` |
| `'counter_state.dart'` | `'{{name.snakeCase()}}_state.dart'` |

## Workflow

1. Edit golden file in `examples/cli_templates/`
2. Run `dart run scripts/sync_templates.dart`
3. Commit both golden files and generated templates

## IDE Support

`examples/cli_templates/` has a `pubspec.yaml` with path dependencies so IDE can analyze the code. This helps developer:
- See syntax errors immediately
- Have autocomplete
- Navigate to base classes
