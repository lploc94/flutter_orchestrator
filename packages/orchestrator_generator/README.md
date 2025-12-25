# orchestrator_generator

Code generator for orchestrator_core's offline support. Automatically generates `NetworkJobRegistry` registration code.

## Features

- **NetworkRegistryGenerator**: Generates `registerNetworkJobs()` function from `@NetworkRegistry` annotation
- Eliminates boilerplate for offline job registration
- Type-safe job factory generation

## Installation

```yaml
dependencies:
  orchestrator_core: ^0.2.0
  
dev_dependencies:
  orchestrator_generator: ^0.2.0
  build_runner: ^2.4.0
```

## Usage

### 1. Annotate your configuration

```dart
import 'package:orchestrator_core/orchestrator_core.dart';

// List all NetworkAction jobs that need offline support
@NetworkRegistry([
  SendMessageJob,
  UploadFileJob,
  SyncDataJob,
])
class AppConfig {}
```

### 2. Run the generator

```bash
dart run build_runner build
```

### 3. Use the generated function

```dart
// In your app initialization
import 'app_config.g.dart';

void main() {
  registerNetworkJobs(); // Generated function
  runApp(MyApp());
}
```

### Generated output

```dart
// app_config.g.dart
/// Auto-generated function to register all network jobs.
/// Call this during app initialization before processing offline queue.
///
/// Registered jobs:
/// - `SendMessageJob`
/// - `UploadFileJob`
/// - `SyncDataJob`
void registerNetworkJobs() {
  NetworkJobRegistry.register('SendMessageJob', SendMessageJob.fromJson);
  NetworkJobRegistry.register('UploadFileJob', UploadFileJob.fromJson);
  NetworkJobRegistry.register('SyncDataJob', SyncDataJob.fromJson);
}
```

## Job Requirements

Each job in the registry must have a `fromJson` factory constructor:

```dart
class SendMessageJob extends BaseJob implements NetworkAction {
  final String message;
  
  SendMessageJob(this.message) : super(id: generateJobId('msg'));
  
  // Required for offline restoration
  factory SendMessageJob.fromJson(Map<String, dynamic> json) {
    return SendMessageJob(json['message'] as String);
  }
  
  @override
  Map<String, dynamic> toJson() => {'message': message};
}
```

## Documentation

See the full [documentation](https://github.com/lploc94/flutter_orchestrator/tree/main/book).

## License

MIT License
