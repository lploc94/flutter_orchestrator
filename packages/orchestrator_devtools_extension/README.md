# Orchestrator DevTools Extension

A custom DevTools extension for the `orchestrator` package ecosystem. It provides deep visibility into the state, performance, and behavior of your Event-Driven Orchestrator architecture.

## Features

- **Events Timeline**: Visualize the flow of events (Jobs, Tasks, Errors) in real-time.
- **Job Inspector**: Filter and examine specific jobs, viewing their lifecycle and payload.
- **Metrics Dashboard**: Track system health, throughput (Context switching), success rates, and performance anomalies.
- **Network Queue**: Monitor offline jobs, their status (Pending/Retrying), and payload data.
- **Executors Registry**: View active registered executors and their configurations.

## Development

This project is a Flutter Web application that runs inside the Dart DevTools environment.

### 1. Build and Deploy

To build the extension and deploy it to the `orchestrator_flutter` package (where it is consumed):

```bash
# 1. Build the web application (CanvasKit disabled for better DevTools compatibility)
flutter build web --pwa-strategy=none --no-tree-shake-icons

# 2. Copy the build artifacts to the parent package
# Make sure to run this from the 'packages/orchestrator_devtools_extension' directory
rm -rf ../orchestrator_flutter/extension/devtools/build
mkdir -p ../orchestrator_flutter/extension/devtools/build
cp -r build/web/* ../orchestrator_flutter/extension/devtools/build/
```

### 2. Testing Locally

To test the extension with an example app:

1.  Run the example app (e.g., `examples/simple_counter`):
    ```bash
    cd examples/simple_counter
    flutter run -d chrome
    ```
2.  Open DevTools.
3.  You should see a new tab called **"Orchestrator"**.

## Architecture

- Uses `vm_service` to communicate with the connected app.
- Listens to custom streams broadcasted by `OrchestratorObserver` in `orchestrator_flutter`.
