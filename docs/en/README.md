# Flutter Orchestrator Documentation

Welcome to the official technical documentation for **Flutter Orchestrator**. This guide details how to install, use, and integrate the framework into your projects.

If you are interested in design philosophy and architectural thinking, please read [The Book](../../book/README.md).

---

## 📚 Table of Contents

### 🚀 Getting Started
- [Installation & Initial Setup](guide/getting_started.md)
- [Cheat Sheet - Core Concepts Overview](guide/core_concepts.md)
- [Standard Project Structure](guide/project_structure.md)

### CLI Tool
- [Orchestrator CLI](guide/cli.md) - Scaffolding tool
- [CLI Cheatsheet](guide/cli_cheatsheet.md) - Quick reference

### 📖 Concepts
| Concept | Description |
|---------|-------------|
| [Job](concepts/job.md) | Action definition (data packet) |
| [Executor](concepts/executor.md) | Business Logic processing |
| [Orchestrator](concepts/orchestrator.md) | UI State management |
| [Dispatcher](concepts/dispatcher.md) | Coordination center |
| [SignalBus](concepts/signal_bus.md) | Event communication |
| [Event](concepts/event.md) | Event types |

### 🛠 Integration
| Package | Library |
|---------|---------|
| [orchestrator_bloc](guide/integration.md#bloc) | flutter_bloc |
| [orchestrator_provider](guide/integration.md#provider) | provider |
| [orchestrator_riverpod](guide/integration.md#riverpod) | riverpod |

### 🔥 Advanced Features
- [Offline Support & Network Action](advanced/offline_support.md)
- [Cache & Data Strategy](advanced/cache.md)
- [Error Handling & Logging](advanced/error_handling.md)
- [Testing](advanced/testing.md)
- [Code Generation](advanced/code_generation.md)

### 📦 Examples
- [Simple Counter](../../examples/simple_counter) - Hello World example

---
