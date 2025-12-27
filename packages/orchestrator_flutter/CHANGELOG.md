# Changelog

All notable changes to this project will be documented in this file.

## [0.3.0] - 2025-12-27

### Fixed
- Fixed `JobStartedEvent` serialization to correctly send `jobType` to DevTools (resolves "Unknown" job types).
- Fixed `pubspec.yaml` dependencies for publishing.
- Fixed timestamp display issues in DevTools Network Queue tab.

### Improved
- **DevTools**: Enhanced Metrics Dashboard with "Peak Throughput" analysis and improved Dark Mode UI.

## [0.2.0] - 2025-12-25

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
