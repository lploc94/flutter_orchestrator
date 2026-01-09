/// Orchestrator Core Library
///
/// A production-ready, event-driven orchestration framework for Dart/Flutter.
///
/// Key components:
/// - [EventJob]: The only job class - every job emits a domain event
/// - [BaseEvent]: Base class for all event signals
/// - [BaseExecutor]: Abstract worker that processes jobs
/// - [BaseOrchestrator]: Reactive state machine that coordinates everything
/// - [Dispatcher]: Routes jobs to appropriate executors
/// - [SignalBus]: Central event backbone (Pub/Sub)
/// - [JobHandle]: Track job progress and await results
library;

// Models
export 'src/models/event.dart';
export 'src/models/job.dart';
export 'src/models/job_handle.dart';
export 'src/models/data_source.dart';
export 'src/models/network_action.dart';
export 'src/models/data_strategy.dart';

// Annotations
export 'src/annotations/network_job.dart';
export 'src/annotations/executor_registry.dart';
export 'src/annotations/json_annotations.dart';
export 'src/annotations/network_registry.dart';
export 'src/annotations/orchestrator.dart';
export 'src/annotations/async_state.dart';
export 'src/annotations/generate_job_event.dart';
export 'src/annotations/typed_job.dart';
export 'src/annotations/orchestrator_provider.dart';

// Infrastructure
export 'src/infra/signal_bus.dart';
export 'src/infra/dispatcher.dart';
export 'src/infra/orchestrator_observer.dart';
export 'src/infra/offline/offline_manager.dart';
export 'src/infra/offline/connectivity_provider.dart';

// Cache
export 'src/infra/cache/cache_provider.dart';
export 'src/infra/cache/in_memory_cache_provider.dart';
export 'src/infra/cache/cache_job_executor.dart';
export 'src/jobs/invalidate_cache_job.dart';

// Cleanup
export 'src/infra/cleanup.dart';

// Base classes
export 'src/base/base_executor.dart';
export 'src/base/base_orchestrator.dart';
export 'src/base/typed_executor.dart';

// Utilities
export 'src/utils/cancellation_token.dart';
export 'src/utils/retry_policy.dart';
export 'src/utils/logger.dart';
export 'src/utils/job_result.dart';
export 'src/utils/state_patterns.dart';
export 'src/utils/orchestrator_helpers.dart';
export 'src/utils/saga_flow.dart';
