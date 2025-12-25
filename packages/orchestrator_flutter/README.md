# orchestrator_flutter

Flutter platform implementations for orchestrator_core's offline support. Provides ready-to-use storage and connectivity providers.

## Features

- **FileNetworkQueueStorage**: File-based job persistence using app documents directory
- **FlutterFileSafetyDelegate**: Secure temporary file handling for offline jobs
- **FlutterConnectivityProvider**: Network connectivity detection using `connectivity_plus`

## Installation

```yaml
dependencies:
  orchestrator_flutter: ^0.2.0
```

## Usage

```dart
import 'package:orchestrator_core/orchestrator_core.dart';
import 'package:orchestrator_flutter/orchestrator_flutter.dart';

void main() {
  // Configure offline support with Flutter implementations
  OrchestratorConfig.setNetworkQueueManager(
    NetworkQueueManager(
      storage: FileNetworkQueueStorage(),
      fileDelegate: FlutterFileSafetyDelegate(),
    ),
  );
  
  OrchestratorConfig.setConnectivityProvider(
    FlutterConnectivityProvider(),
  );
  
  runApp(MyApp());
}
```

## Components

### FileNetworkQueueStorage

Persists offline jobs as JSON files in the app's documents directory.

```dart
final storage = FileNetworkQueueStorage();
await storage.saveJob('job-123', {'type': 'SendMessage', 'data': {...}});
```

### FlutterFileSafetyDelegate

Copies temporary files (like camera photos) to a safe location before the job is queued, preventing file-not-found errors when the job is later processed.

```dart
final delegate = FlutterFileSafetyDelegate();
final safeData = await delegate.secureFiles(jobData);
```

### FlutterConnectivityProvider

Monitors network connectivity using `connectivity_plus` package.

```dart
final provider = FlutterConnectivityProvider();
final isOnline = await provider.isConnected;
provider.onConnectivityChanged.listen((connected) {
  print('Connectivity: $connected');
});
```

## Requirements

- Flutter >= 3.0.0
- orchestrator_core ^0.2.0

## Documentation

See the full [documentation](https://github.com/lploc94/flutter_orchestrator/tree/main/book).

## License

MIT License
