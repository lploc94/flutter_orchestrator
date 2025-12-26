# Orchestrator CLI

CLI tool for scaffolding Flutter Orchestrator components with Mason templates.

## Features

- 🚀 Generate Job, Executor, State, Cubit, Notifier, and Feature classes
- 📦 Bundled Mason templates - no network required
- 🎨 Beautiful CLI output with spinners and colors
- 📁 Customizable output directories
- ⚙️ Configuration file support (`orchestrator.yaml`)
- 🧙 Interactive mode with prompts
- 🏗️ Project initialization with folder structure
- 🩺 **Doctor command** - Check project setup and identify issues
- 📋 **List command** - Show available templates and components
- 🎨 **Custom templates** - Override bundled templates with your own

## Installation

### From Source (Development)

```bash
# From the orchestrator_cli package directory
dart pub get

# Run directly
dart run bin/orchestrator.dart create job FetchUser
```

### Global Activation (After Publishing)

```bash
dart pub global activate orchestrator_cli

# Use globally
orchestrator create job FetchUser
```

## Commands

### Initialize Project

Initialize Orchestrator project structure with folders and configuration.

```bash
# Basic usage
orchestrator init

# With specific state management
orchestrator init -s riverpod
```

**Creates:**
```
lib/
├── features/       # Feature modules
├── core/
│   ├── jobs/       # Shared jobs
│   ├── executors/  # Shared executors
│   └── di/         # Dependency injection
└── shared/         # Shared utilities
orchestrator.yaml   # CLI configuration
```

### Create Feature (Full Scaffold)

Create a complete feature with job, executor, and state management.

```bash
# Basic usage (uses config defaults or cubit)
orchestrator create feature User

# With specific state management
orchestrator create feature User -s riverpod

# Interactive mode
orchestrator create feature -i

# Skip job or executor
orchestrator create feature User --no-job
orchestrator create feature User --no-executor

# Custom output directory
orchestrator create feature User -o lib/modules
```

**Generated structure:**
```
lib/features/user/
├── jobs/
│   └── user_job.dart
├── executors/
│   └── user_executor.dart
├── cubit/              # or notifier/ for provider/riverpod
│   ├── user_cubit.dart
│   └── user_state.dart
└── user.dart           # Barrel file
```

### Create Job

Create an Orchestrator Job class - a work request dispatched to executors.

```bash
# Basic usage
orchestrator create job FetchUser

# Custom output directory
orchestrator create job FetchUser -o lib/features/user/jobs
```

**Generated:** `lib/jobs/fetch_user_job.dart`

### Create Executor

Create an Orchestrator Executor class - handles business logic for jobs.

```bash
# Basic usage
orchestrator create executor FetchUser

# Custom output directory
orchestrator create executor FetchUser -o lib/features/user/executors
```

**Generated:** `lib/executors/fetch_user_executor.dart`

### Create State

Create an immutable State class with copyWith method.

```bash
# Basic usage
orchestrator create state User

# Custom output directory
orchestrator create state User -o lib/features/user
```

**Generated:** `lib/states/user_state.dart`

### Create Cubit (Bloc Integration)

Create an OrchestratorCubit with State for Bloc integration.

```bash
# Basic usage
orchestrator create cubit User

# Custom output directory
orchestrator create cubit User -o lib/features/user/cubit
```

**Generated:**
- `lib/cubits/user_cubit.dart`
- `lib/cubits/user_state.dart`

### Create Notifier (Provider Integration)

Create an OrchestratorNotifier with State for Provider integration.

```bash
# Basic usage
orchestrator create notifier User

# Custom output directory
orchestrator create notifier User -o lib/features/user/notifier
```

**Generated:**
- `lib/notifiers/user_notifier.dart`
- `lib/notifiers/user_state.dart`

### Create Riverpod Notifier

Create an OrchestratorNotifier with State for Riverpod integration.

```bash
# Basic usage
orchestrator create riverpod User

# Custom output directory
orchestrator create riverpod User -o lib/features/user/notifier
```

**Generated:**
- `lib/notifiers/user_notifier.dart`
- `lib/notifiers/user_state.dart`

## Configuration

Create an `orchestrator.yaml` file in your project root (or use `orchestrator init`):

```yaml
# Orchestrator CLI Configuration

# Default state management solution
# Options: cubit, provider, riverpod
state_management: cubit

# Output paths for generated files
output:
  features: lib/features
  jobs: lib/core/jobs
  executors: lib/core/executors

# Feature structure
feature:
  # Include job in feature scaffold
  include_job: true
  # Include executor in feature scaffold
  include_executor: true
  # Generate barrel file for feature
  generate_barrel: true
```

## Default Output Directories

| Component | Default Path |
|-----------|--------------|
| Feature | `lib/features/<name>/` |
| Job | `lib/jobs/` |
| Executor | `lib/executors/` |
| State | `lib/states/` |
| Cubit | `lib/cubits/` |
| Notifier | `lib/notifiers/` |
| Riverpod | `lib/notifiers/` |

## Example Workflow

```bash
# 1. Initialize project structure
orchestrator init -s cubit

# 2. Create a complete feature
orchestrator create feature User

# 3. Or create components individually
orchestrator create job FetchProducts
orchestrator create executor FetchProducts
orchestrator create cubit Products

# 4. Implement your business logic and connect everything!
```

## Options

### Global Options

- `-h, --help` - Show help information

### Create Feature Options

- `-o, --output <path>` - Output directory for the feature
- `-s, --state-management <type>` - State management (cubit, provider, riverpod)
- `--no-job` - Skip generating job file
- `--no-executor` - Skip generating executor file
- `-i, --interactive` - Run in interactive mode with prompts

### Init Options

- `-s, --state-management <type>` - Default state management
- `-f, --force` - Overwrite existing configuration

## Help

```bash
# Show all commands
orchestrator --help

# Show help for a specific command
orchestrator create --help
orchestrator create feature --help
orchestrator init --help
orchestrator doctor --help
orchestrator list --help
orchestrator template --help
```

## Doctor Command

Check your project setup and identify potential issues.

```bash
# Run diagnostic checks
orchestrator doctor

# Show detailed information
orchestrator doctor -v

# Automatically fix issues where possible
orchestrator doctor --fix
```

**Checks performed:**
- ✓ pubspec.yaml exists and has required dependencies
- ✓ orchestrator.yaml configuration file
- ✓ Project structure (recommended directories)
- ✓ Dispatcher setup
- ✓ Executor registration
- ✓ State management integration
- ✓ Import consistency
- ✓ Job-Executor matching (Jobs without Executors)
- ✓ State copyWith methods
- ✓ Orchestrator handlers (onActiveSuccess/onActiveFailure)

**Example output:**
```
🩺 Running Orchestrator Doctor...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 Diagnostic Results
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✓ Orchestrator dependencies
✓ orchestrator.yaml config
✓ Project structure
✗ Dispatcher setup
  └─ No Dispatcher instance found in project
  └─ Fix: Create a Dispatcher instance in your DI setup
✓ State management integration

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 Results: 5 passed, 1 failed
```

## List Command

Show available templates and project components.

```bash
# List all templates
orchestrator list

# Short alias
orchestrator ls

# Detailed information
orchestrator list -v

# Only show custom templates
orchestrator list -c
```

## Custom Templates

Override bundled templates with your own customizations.

```bash
# Initialize custom templates
orchestrator template init

# Initialize specific template only
orchestrator template init -t job

# Force overwrite existing custom templates
orchestrator template init -f

# List your custom templates
orchestrator template list
```

**Custom templates location:** `.orchestrator/templates/`

**Template variables available:**
- `{{name}}` - Raw name as provided
- `{{name.pascalCase()}}` - PascalCase (e.g., FetchUser)
- `{{name.camelCase()}}` - camelCase (e.g., fetchUser)
- `{{name.snakeCase()}}` - snake_case (e.g., fetch_user)
- `{{name.constantCase()}}` - CONSTANT_CASE (e.g., FETCH_USER)

## Dependencies

This CLI uses:
- [args](https://pub.dev/packages/args) - Command line argument parsing
- [mason](https://pub.dev/packages/mason) - Code generation with templates
- [mason_logger](https://pub.dev/packages/mason_logger) - Beautiful CLI logging
- [path](https://pub.dev/packages/path) - Cross-platform path manipulation
- [yaml](https://pub.dev/packages/yaml) - YAML configuration parsing

## License

MIT License - see [LICENSE](LICENSE) for details.
