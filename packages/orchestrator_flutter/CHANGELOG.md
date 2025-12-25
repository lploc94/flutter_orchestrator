# Changelog

All notable changes to this project will be documented in this file.

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
