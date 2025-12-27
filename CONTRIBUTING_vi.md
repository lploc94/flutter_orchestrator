# Hướng Dẫn Đóng Góp (Contributing Guide)

Tài liệu này mô tả quy trình phát triển, versioning, và publishing cho dự án Flutter Orchestrator monorepo.

## Mục Lục

- [Cấu Trúc Dự Án](#cấu-trúc-dự-án)
- [Quy Trình Phát Triển](#quy-trình-phát-triển)
- [Versioning Strategy](#versioning-strategy)
- [Quy Trình Commit](#quy-trình-commit)
- [Changelog Management](#changelog-management)
- [Publishing Workflow](#publishing-workflow)
- [Testing Requirements](#testing-requirements)

---

## Cấu Trúc Dự Án

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

## Quy Trình Phát Triển

### 1. Khi Fix Bug Trong Package Con

**Ví dụ: Fix bug trong `orchestrator_core`**

#### Bước 1: Tạo Branch (Nếu dùng Git Flow)
```bash
git checkout -b fix/job-timeout-error
```

#### Bước 2: Sửa Code
- Sửa file cần thiết
- Thêm/cập nhật unit tests

#### Bước 3: Chạy Tests
```bash
cd packages/orchestrator_core
dart test
```

#### Bước 4: Cập Nhật Version (Semantic Versioning)

**Bug Fix → Patch Version (0.3.0 → 0.3.1)**

Sửa `packages/orchestrator_core/pubspec.yaml`:
```yaml
version: 0.3.1
```

#### Bước 5: Cập Nhật CHANGELOG

Thêm vào `packages/orchestrator_core/CHANGELOG.md`:
```markdown
## [0.3.1] - 2025-12-27

### Fixed
- Fixed timeout error in JobProgressEvent handling.
```

#### Bước 6: Cập Nhật Root CHANGELOG

Thêm vào `CHANGELOG.md` (root):
```markdown
## [0.3.1] - 2025-12-27

### orchestrator_core
- **Fixed**: Timeout error in JobProgressEvent handling.
```

#### Bước 7: Commit Changes
```bash
git add .
git commit -m "fix(core): resolve timeout error in JobProgressEvent

Fixes #123"
```

#### Bước 8: Push và Tạo PR (Nếu làm việc nhóm)
```bash
git push origin fix/job-timeout-error
# Tạo Pull Request trên GitHub
```

---

### 2. Khi Thêm Feature Mới

**Ví dụ: Thêm Cache Strategy vào `orchestrator_core`**

#### Bước 1: Tạo Branch
```bash
git checkout -b feat/lru-cache-strategy
```

#### Bước 2: Implement Feature
- Thêm code mới
- Viết unit tests
- Cập nhật documentation

#### Bước 3: Bump Version

**New Feature → Minor Version (0.3.0 → 0.4.0)**

Sửa `packages/orchestrator_core/pubspec.yaml`:
```yaml
version: 0.4.0
```

#### Bước 4: Cập Nhật CHANGELOG

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

#### Bước 5: Cập Nhật Dependent Packages

Nếu feature này ảnh hưởng đến packages khác (e.g., `orchestrator_flutter`):

1. Cập nhật dependency trong `orchestrator_flutter/pubspec.yaml`:
   ```yaml
   dependencies:
     orchestrator_core: ^0.4.0
   ```

2. Bump version của `orchestrator_flutter`:
   ```yaml
   version: 0.4.0  # hoặc 0.3.1 nếu chỉ là minor update
   ```

3. Cập nhật CHANGELOG của `orchestrator_flutter`.

#### Bước 6: Commit
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

Khi thay đổi API không tương thích ngược:

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

Dự án tuân theo [Semantic Versioning 2.0.0](https://semver.org/):

```
MAJOR.MINOR.PATCH

1.2.3
│ │ └─── PATCH: Bug fixes, no API changes
│ └───── MINOR: New features, backward compatible
└─────── MAJOR: Breaking changes
```

### Quy Tắc Versioning

| Loại Thay Đổi | Version Bump | Ví Dụ |
|----------------|--------------|--------|
| Bug fix | Patch | 0.3.0 → 0.3.1 |
| New feature (compatible) | Minor | 0.3.0 → 0.4.0 |
| Breaking change | Major | 0.3.0 → 1.0.0 |
| Deprecation warning | Minor | 0.3.0 → 0.4.0 |
| Documentation only | Không bump | 0.3.0 (unchanged) |

### Dependency Versioning

Khi update dependency giữa các packages:

```yaml
# orchestrator_bloc/pubspec.yaml
dependencies:
  orchestrator_core: ^0.4.0  # ✅ Dùng caret (^) cho flexibility
```

**Quy tắc:**
- Luôn dùng **`^`** (caret) cho dependencies nội bộ
- Khi publish, đảm bảo dependency version tồn tại trên pub.dev
- Trong dev, dùng `dependency_overrides` với `path:` để test local

---

## Quy Trình Commit

### Conventional Commits

Dự án sử dụng [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Commit Types

| Type | Mô Tả | Ảnh Hưởng Version |
|------|-------|-------------------|
| `feat` | Feature mới | Minor |
| `fix` | Bug fix | Patch |
| `docs` | Documentation | - |
| `style` | Code formatting | - |
| `refactor` | Code refactoring | - |
| `perf` | Performance improvement | Patch |
| `test` | Thêm tests | - |
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

### Ví Dụ Commits

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

### Format Chuẩn

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

### Cập Nhật Changelogs

**Quy tắc:**
1. **Package CHANGELOG** (`packages/<name>/CHANGELOG.md`): Chi tiết kỹ thuật
2. **Root CHANGELOG** (`CHANGELOG.md`): Tổng hợp, user-facing

**Workflow:**
1. Sửa code → Cập nhật package CHANGELOG
2. Bump version → Cập nhật root CHANGELOG
3. Commit cả hai

---

## Publishing Workflow

### Chuẩn Bị Publish

#### 1. Pre-publish Checklist

```bash
# Kiểm tra version đồng bộ
cd packages/orchestrator_core
cat pubspec.yaml | grep version

# Chạy tests
dart test

# Kiểm tra linting
dart analyze

# Dry run publish
dart pub publish --dry-run
```

#### 2. Xác Nhận Dependencies

Đảm bảo tất cả dependencies đã được publish:

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

#### Bước 1: Tag Version
```bash
git tag -a orchestrator_core-v0.4.0 -m "Release orchestrator_core v0.4.0"
git push origin orchestrator_core-v0.4.0
```

#### Bước 2: Publish Package
```bash
cd packages/orchestrator_core
dart pub publish

# Xác nhận khi được hỏi
```

#### Bước 3: Publish Dependent Packages (Theo Thứ Tự)

**Thứ tự publish:**
1. `orchestrator_core`
2. `orchestrator_generator` (depends on core)
3. `orchestrator_flutter` (depends on core)
4. `orchestrator_bloc` (depends on core)
5. `orchestrator_provider` (depends on core)
6. `orchestrator_riverpod` (depends on core)

```bash
# Đợi orchestrator_core available trên pub.dev (~5-10 phút)
# Sau đó publish packages khác
cd ../orchestrator_bloc
dart pub get  # Update dependencies
dart pub publish
```

#### Bước 4: Tạo GitHub Release

1. Vào GitHub → Releases → New Release
2. Tag: `v0.4.0` (hoặc specific package tag)
3. Title: `v0.4.0 - Feature Name`
4. Description: Copy từ CHANGELOG
5. Attach build artifacts (nếu có)

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
# Chạy tất cả tests
dart test

# Chạy với coverage
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

## Liên Hệ

- Issues: [GitHub Issues](https://github.com/lploc94/flutter_orchestrator/issues)
- Discussions: [GitHub Discussions](https://github.com/lploc94/flutter_orchestrator/discussions)
