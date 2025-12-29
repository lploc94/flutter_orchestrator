## 0.4.0 - 2025-12-29

### Changed
- Updated dependency to `orchestrator_core: ^0.4.0`.

## 0.3.3 - 2025-12-27

### Fixed
- Bumped `orchestrator_core` dependency to `^0.3.3` to fix undefined getters in DevTools integration.
- Fixes pub.dev analysis issues related to missing API symbols.

## 0.3.2 - 2025-12-27

### Fixed
- Improved pub.dev scoring: added documentation field, formatted code.
- Updated connectivity_plus dependency range for wider compatibility.

# Changelog

All notable changes to this project will be documented in this file.

## 0.3.1 - 2025-12-27

### Added
- **Resource Cleanup**: Added `FlutterCleanupService` with auto-cleanup support.
- **Initialization**: Added `OrchestratorFlutter.initialize()` for simplified "All-in-One" setup.
- **Config**: Smart Sync mechanism between Cleanup Policy and LRU Cache.
- **File Safety**: Enhanced `FlutterFileSafety` with `cleanupOldFiles()` and usage stats.

## 0.3.0 - 2025-12-27

### Fixed
- Fixed `JobStartedEvent` serialization to correctly send `jobType` to DevTools (resolves "Unknown" job types).
- Fixed `pubspec.yaml` dependencies for publishing.
- Fixed timestamp display issues in DevTools Network Queue tab.

### Improved
- **DevTools**: Enhanced Metrics Dashboard with "Peak Throughput" analysis and improved Dark Mode UI.

## 0.2.0 - 2025-12-25

### Added
- Initial public release
- `FileNetworkQueueStorage` - File-based offline job persistence
- `FlutterFileSafetyDelegate` - Secure temporary file handling
- `FlutterConnectivityProvider` - Network connectivity detection

### Features
- Base64 encoding for safe filenames (prevents ID collisions)
- Deep copy of job data to prevent mutation issues
- Broadcast stream support for multiple connectivity listeners
- Proper cleanup and dispose methods
