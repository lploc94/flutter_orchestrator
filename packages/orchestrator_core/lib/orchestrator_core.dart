/// Orchestrator Core Library
///
/// A production-ready, event-driven orchestration framework for Dart/Flutter.
///
/// Key components:
/// - [BaseJob]: Base class for all work requests
/// - [BaseEvent]: Base class for all event signals
/// - [BaseExecutor]: Abstract worker that processes jobs
/// - [BaseOrchestrator]: Reactive state machine that coordinates everything
/// - [Dispatcher]: Routes jobs to appropriate executors
/// - [SignalBus]: Central event backbone (Pub/Sub)
library;

// Models
export 'src/models/event.dart';
export 'src/models/job.dart';

// Infrastructure
export 'src/infra/signal_bus.dart';
export 'src/infra/dispatcher.dart';

// Base classes
export 'src/base/base_executor.dart';
export 'src/base/base_orchestrator.dart';

// Utilities
export 'src/utils/cancellation_token.dart';
export 'src/utils/retry_policy.dart';
export 'src/utils/logger.dart';
