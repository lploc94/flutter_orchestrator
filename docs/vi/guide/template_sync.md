# Template Sync Script

Script tự động đồng bộ CLI templates từ golden example files.

## Mục đích

- **Single source of truth**: Chỉ cần sửa code ở `examples/cli_templates/`, templates tự động cập nhật
- **Không bị outdated**: Templates luôn match với code patterns mới nhất
- **DX tốt hơn**: Developer có thể sửa real Dart code thay vì Mustache templates

## Cách sử dụng

```bash
# Từ root của project
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

1. Sửa golden file trong `examples/cli_templates/`
2. Chạy `dart run scripts/sync_templates.dart`
3. Commit cả golden files và generated templates

## IDE Support

`examples/cli_templates/` có `pubspec.yaml` với path dependencies để IDE phân tích được code. Điều này giúp developer:
- Thấy lỗi syntax ngay
- Có autocomplete
- Navigate đến base classes
