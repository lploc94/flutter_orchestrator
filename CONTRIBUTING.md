# Contributing Guide

This document describes the development, versioning, and publishing process for the Flutter Orchestrator monorepo.

## Table of Contents

- [Project Structure](#project-structure)
- [Development Workflow](#development-workflow)
- [Versioning Strategy](#versioning-strategy)
- [Commit Workflow](#commit-workflow)
- [Changelog Management](#changelog-management)
- [Publishing Workflow](#publishing-workflow)
- [Testing Requirements](#testing-requirements)

---

## Project Structure

```
flutter_orchestrator/
├── packages/
│   ├── orchestrator_core/          # Core package (Pure Dart)
│   ├── orchestrator_bloc/          # BLoC integration
│   ├── orchestrator_provider/      # Provider integration
│   ├── orchestrator_riverpod/      # Riverpod integration
│   ├── orchestrator_flutter/       # Flutter platform impl
│   ├── orchestrator_generator/     # Code generation
│   ├── orchestrator_cli/           # CLI tool
│   └── orchestrator_devtools_extension/  # DevTools (not published)
├── examples/
│   └── simple_counter/
└── book/                           # Documentation
```

---

## Development Workflow

### 1. Fixing a Bug in a Sub-package

**Example: Fix bug in `orchestrator_core`**

#### Step 1: Create a Branch (If using Git Flow)
```bash
git checkout -b fix/job-timeout-error
```

#### Step 2: Edit Code
- Modify necessary files
- Add/update unit tests

#### Step 3: Run Tests
```bash
cd packages/orchestrator_core
dart test
```

#### Step 4: Update Version (Semantic Versioning)

**Bug Fix → Patch Version (0.3.0 → 0.3.1)**

Update `packages/orchestrator_core/pubspec.yaml`:
```yaml
version: 0.3.1
```

#### Step 5: Update CHANGELOG

Add to `packages/orchestrator_core/CHANGELOG.md`:
```markdown
## [0.3.1] - 2025-12-27

### Fixed
- Fixed timeout error in JobProgressEvent handling.
```

#### Step 6: Update Root CHANGELOG

Add to `CHANGELOG.md` (root):
```markdown
## [0.3.1] - 2025-12-27

### orchestrator_core
- **Fixed**: Timeout error in JobProgressEvent handling.
```

#### Step 7: Commit Changes
```bash
git add .
git commit -m "fix(core): resolve timeout error in JobProgressEvent

Fixes #123"
```

#### Step 8: Push and Create PR (for team collaboration)
```bash
git push origin fix/job-timeout-error
# Create Pull Request on GitHub
```

---

### 2. Adding a New Feature

**Example: Adding Cache Strategy to `orchestrator_core`**

#### Step 1: Create a Branch
```bash
git checkout -b feat/lru-cache-strategy
```

#### Step 2: Implement Feature
- Add new code
- Write unit tests
- Update documentation

#### Step 3: Bump Version

**New Feature → Minor Version (0.3.0 → 0.4.0)**

Update `packages/orchestrator_core/pubspec.yaml`:
```yaml
version: 0.4.0
```

#### Step 4: Update CHANGELOG

`packages/orchestrator_core/CHANGELOG.md`:
```markdown
## [0.4.0] - 2025-12-27

### Added
- **LRU Cache Strategy**: New `LRUCacheProvider` with configurable max entries.
- Added `maxCacheSize` configuration option.

### Changed
- `CacheProvider` interface now supports size limits.
```

Root `CHANGELOG.md`:
```markdown
## [0.4.0] - 2025-12-27

### orchestrator_core (New Feature)
- **Added**: LRU Cache Strategy with configurable max entries.
- **Changed**: CacheProvider interface now supports size limits.
```

#### Step 5: Update Dependent Packages

If this feature affects other packages (e.g., `orchestrator_flutter`):

1. Update dependency in `orchestrator_flutter/pubspec.yaml`:
   ```yaml
   dependencies:
     orchestrator_core: ^0.4.0
   ```

2. Bump version of `orchestrator_flutter`:
   ```yaml
   version: 0.4.0  # or 0.3.1 if it's just a minor update
   ```

3. Update CHANGELOG of `orchestrator_flutter`.

#### Step 6: Commit
```bash
git add .
git commit -m "feat(core): add LRU cache strategy

- Implements LRUCacheProvider with max size
- Updates CacheProvider interface
- Adds comprehensive unit tests

BREAKING CHANGE: CacheProvider interface signature changed"
```

---

### 3. Breaking Changes

**Breaking Change → Major Version (0.3.0 → 1.0.0)**

When making non-backward compatible API changes:

#### pubspec.yaml
```yaml
version: 1.0.0
```

#### CHANGELOG.md
```markdown
## [1.0.0] - 2025-12-27

### ⚠️ BREAKING CHANGES
- **CacheProvider**: Renamed `get()` to `fetch()` for consistency.
- **BaseExecutor**: `execute()` now requires `CancellationToken` parameter.

### Migration Guide
```dart
// Before
final data = await cache.get('key');

// After
final data = await cache.fetch('key');
```

### Added
- New `CancellationToken` API for cooperative cancellation.
```

#### Commit Message
```bash
git commit -m "feat(core)!: redesign cache API for better consistency

BREAKING CHANGE: 
- CacheProvider.get() renamed to fetch()
- BaseExecutor.execute() now requires CancellationToken

See MIGRATION.md for upgrade guide"
```

---

## Versioning Strategy

The project follows [Semantic Versioning 2.0.0](https://semver.org/):

```
MAJOR.MINOR.PATCH

1.2.3
│ │ └─── PATCH: Bug fixes, no API changes
│ └───── MINOR: New features, backward compatible
└─────── MAJOR: Breaking changes
```

### Versioning Rules

| Change Type | Version Bump | Example |
|----------------|--------------|--------|
| Bug fix | Patch | 0.3.0 → 0.3.1 |
| New feature (compatible) | Minor | 0.3.0 → 0.4.0 |
| Breaking change | Major | 0.3.0 → 1.0.0 |
| Deprecation warning | Minor | 0.3.0 → 0.4.0 |
| Documentation only | No bump | 0.3.0 (unchanged) |

### Dependency Versioning

When updating dependencies between packages:

```yaml
# orchestrator_bloc/pubspec.yaml
dependencies:
  orchestrator_core: ^0.4.0  # ✅ Use caret (^) for flexibility
```

**Rules:**
- Always use **`^`** (caret) for internal dependencies.
- Ensure dependency versions exist on pub.dev when publishing.
- In dev, use `dependency_overrides` with `path:` for local testing.

---

## Commit Workflow

### Conventional Commits

The project uses [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Commit Types

| Type | Description | Version Impact |
|------|-------|-------------------|
| `feat` | New feature | Minor |
| `fix` | Bug fix | Patch |
| `docs` | Documentation | - |
| `style` | Code formatting | - |
| `refactor` | Code refactoring | - |
| `perf` | Performance improvement | Patch |
| `test` | Add tests | - |
| `chore` | Maintenance tasks | - |
| `build` | Build system changes | - |
| `ci` | CI config changes | - |

### Scope Examples

- `core` - orchestrator_core
- `bloc` - orchestrator_bloc
- `flutter` - orchestrator_flutter
- `gen` - orchestrator_generator
- `cli` - orchestrator_cli
- `devtools` - orchestrator_devtools_extension

### Commit Examples

#### Feature
```bash
git commit -m "feat(core): add retry policy configuration

- Adds RetryPolicy.exponentialBackoff()
- Supports custom delay strategies
- Includes unit tests"
```

#### Bug Fix
```bash
git commit -m "fix(bloc): prevent memory leak in OrchestratorCubit

Fixes issue where event stream subscription was not cancelled
on dispose, causing memory leaks in long-running apps.

Fixes #42"
```

#### Breaking Change
```bash
git commit -m "feat(core)!: redesign job cancellation API

BREAKING CHANGE: Job.cancel() now returns Future<void> instead of void
to support async cleanup.

Migration:
  // Before
  job.cancel();

  // After
  await job.cancel();"
```

---

## Changelog Management

### Standard Format

```markdown
# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- New feature descriptions

### Changed
- Changes in existing functionality

### Deprecated
- Soon-to-be removed features

### Removed
- Removed features

### Fixed
- Bug fixes

### Security
- Security fixes

## [1.0.0] - 2025-12-27

### Added
- Initial public release
```

### Updating Changelogs

**Rules:**
1. **Package CHANGELOG** (`packages/<name>/CHANGELOG.md`): Technical details.
2. **Root CHANGELOG** (`CHANGELOG.md`): Summary, user-facing.

**Workflow:**
1. Edit code → Update package CHANGELOG.
2. Bump version → Update root CHANGELOG.
3. Commit both.

---

## Publishing Workflow

### Prepare for Publish

#### 1. Pre-publish Checklist

```bash
# Check version synchronization
cd packages/orchestrator_core
cat pubspec.yaml | grep version

# Run tests
dart test

# Check linting
dart analyze

# Dry run publish
dart pub publish --dry-run
```

#### 2. Verify Dependencies

Ensure all dependencies are published:

```yaml
# ✅ Correct
dependencies:
  orchestrator_core: ^0.4.0

# ❌ Wrong (path dependency)
dependencies:
  orchestrator_core:
    path: ../orchestrator_core
```

### Publishing Process

#### Step 1: Tag Version
```bash
git tag -a orchestrator_core-v0.4.0 -m "Release orchestrator_core v0.4.0"
git push origin orchestrator_core-v0.4.0
```

#### Step 2: Publish Package
```bash
cd packages/orchestrator_core
dart pub publish

# Confirm when asked
```

#### Step 3: Publish Dependent Packages (In Order)

**Publish Order:**
1. `orchestrator_core`
2. `orchestrator_generator` (depends on core)
3. `orchestrator_flutter` (depends on core)
4. `orchestrator_bloc` (depends on core)
5. `orchestrator_provider` (depends on core)
6. `orchestrator_riverpod` (depends on core)

```bash
# Wait for orchestrator_core availability on pub.dev (~5-10 mins)
# Then publish other packages
cd ../orchestrator_bloc
dart pub get  # Update dependencies
dart pub publish
```

#### Step 4: Create GitHub Release

1. Go to GitHub → Releases → New Release.
2. Tag: `v0.4.0` (or specific package tag).
3. Title: `v0.4.0 - Feature Name`.
4. Description: Copy from CHANGELOG.
5. Attach build artifacts (if any).

---

## Testing Requirements

### Minimum Coverage

| Package | Min Coverage | Focus |
|---------|--------------|-------|
| orchestrator_core | 80% | All logic |
| orchestrator_bloc | 70% | State management |
| orchestrator_provider | 70% | State management |
| orchestrator_riverpod | 70% | State management |
| orchestrator_generator | 60% | Code gen logic |
| orchestrator_flutter | 50% | Platform code |
| orchestrator_devtools_extension | 40% | UI logic |

### Test Commands

```bash
# Run all tests
dart test

# Run with coverage
dart test --coverage=coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### Pre-commit Checklist

```bash
# 1. Format code
dart format .

# 2. Analyze
dart analyze

# 3. Run tests
dart test

# 4. Verify pubspec
dart pub get
```

---

## Quick Reference

### Bug Fix Workflow
```bash
1. Fix code + tests
2. Bump PATCH version (0.3.0 → 0.3.1)
3. Update CHANGELOGs
4. Commit: "fix(scope): description"
5. Publish (if needed)
```

### Feature Workflow
```bash
1. Implement feature + tests
2. Bump MINOR version (0.3.0 → 0.4.0)
3. Update CHANGELOGs + docs
4. Commit: "feat(scope): description"
5. Update dependent packages
6. Publish in order
```

### Breaking Change Workflow
```bash
1. Implement change + migration guide
2. Bump MAJOR version (0.3.0 → 1.0.0)
3. Update CHANGELOGs with migration
4. Commit: "feat(scope)!: description"
5. Coordinate with all dependent packages
6. Publish with announcement
```

---

## Contact

- Issues: [GitHub Issues](https://github.com/lploc94/flutter_orchestrator/issues)
- Discussions: [GitHub Discussions](https://github.com/lploc94/flutter_orchestrator/discussions)
