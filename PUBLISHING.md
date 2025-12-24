# Publishing Guide

This guide explains how to publish the orchestrator packages to [pub.dev](https://pub.dev).

## Prerequisites

1. **Google Account**: Required for pub.dev authentication
2. **Dart SDK**: Latest stable version installed

## Publishing Order

Packages must be published in this order due to dependencies:

1. `orchestrator_core` (no dependencies on other packages)
2. `orchestrator_bloc` (depends on core)
3. `orchestrator_provider` (depends on core)
4. `orchestrator_riverpod` (depends on core)

## Step-by-Step

### 1. Authenticate with pub.dev

```bash
dart pub login
```

This will open a browser to authenticate with your Google account.

### 2. Dry Run (Validate)

Test publishing without actually publishing:

```bash
cd packages/orchestrator_core
dart pub publish --dry-run
```

Fix any issues reported.

### 3. Publish orchestrator_core

```bash
cd packages/orchestrator_core
dart pub publish
```

### 4. Wait for pub.dev to index

After publishing core, wait 5-10 minutes for pub.dev to index it.

### 5. Publish remaining packages

```bash
cd packages/orchestrator_bloc
flutter pub publish

cd packages/orchestrator_provider  
flutter pub publish

cd packages/orchestrator_riverpod
flutter pub publish
```

## GitHub Actions (Automated)

For automated publishing via GitHub Actions:

1. Get your pub credentials:
   ```bash
   cat ~/.config/dart/pub-credentials.json
   ```

2. Add to GitHub Secrets as `PUB_CREDENTIALS`

3. Create a GitHub Release - the publish workflow will trigger automatically

## Updating Versions

When releasing new versions:

1. Update version in all `pubspec.yaml` files
2. Update `CHANGELOG.md`
3. Commit and push
4. Create GitHub Release with tag `v0.0.2` etc.

## Important Notes

- **Repository URL**: Update `https://github.com/example/flutter_orchestrator` with your actual repository URL before publishing
- **Version Consistency**: Keep all packages on same version for simplicity
- **Breaking Changes**: Follow semantic versioning
