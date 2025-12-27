# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 0.1.0 - 2025-12-26

### Added

#### Phase 1 - MVP (Create Commands)
- `create job` command - Generate Job classes (work requests)
- `create executor` command - Generate Executor classes (business logic)
- `create state` command - Generate State classes with copyWith
- `create cubit` command - Generate OrchestratorCubit with State (Bloc integration)
- `create notifier` command - Generate OrchestratorNotifier with State (Provider integration)
- `create riverpod` command - Generate OrchestratorNotifier with State (Riverpod integration)
- Mason brick templates bundled with the package
- Beautiful CLI output with mason_logger
- Customizable output directories with `-o` flag

#### Phase 2 - Enhanced Features
- `create feature` command - Generate full feature scaffolds with all components
- `init` command - Initialize project structure with recommended directories
- Interactive mode with `-i` flag for guided component creation
- Configuration file support via `orchestrator.yaml`

#### Phase 3 - Advanced Features
- `doctor` command - Check project setup and identify issues with auto-fix
- `list` command - Show available templates and project components
- `template init` command - Initialize custom templates directory
- `template list` command - List all custom templates
- Custom template override support
- Verbose mode (`-v`) for detailed output
- Version flag (`--version`)

### Technical Details
- 127 comprehensive unit tests
- Bundled Mason bricks for offline usage
- Cross-platform support (Windows, macOS, Linux)
- Follows Flutter/Dart conventions
