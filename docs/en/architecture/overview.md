# Orchestrator Core Architecture

> Complete technical documentation of orchestrator_core v1.0.0 with Domain Event Architecture v3

## Table of Contents

1. [High-Level Overview](#high-level-overview)
2. [Core Components](#core-components)
3. [Data Flow](#data-flow)
4. [Job Execution Lifecycle](#job-execution-lifecycle)
5. [Event System](#event-system)
6. [Advanced Features](#advanced-features)

---

## High-Level Overview

The Orchestrator Pattern separates **what** to do (Jobs) from **how** to do it (Executors), with a central **Dispatcher** routing jobs and a **SignalBus** for event-driven communication.


```mermaid
graph TB
    subgraph "UI Layer"
        UI[Flutter Widget]
    end

    subgraph "Orchestration Layer"
        O[Orchestrator<br/>State Manager]
        JH[JobHandle<T><br/>Future + Progress]
    end

    subgraph "Dispatch Layer"
        D[Dispatcher<br/>Job Router]
    end

    subgraph "Execution Layer"
        E1[Executor A]
        E2[Executor B]
        E3[Executor C]
    end

    subgraph "Infrastructure"
        SB[SignalBus<br/>Event Broadcast]
        OBS[OrchestratorObserver<br/>Global Logging]
    end

    UI -->|"ref.watch(state)"| O
    UI -->|"dispatch(Job)"| O
    O -->|"dispatch(Job)"| D
    O -.->|"returns"| JH
    D -->|"route by type"| E1
    D -->|"route by type"| E2
    D -->|"route by type"| E3
    E1 -->|"emit events"| SB
    E2 -->|"emit events"| SB
    E3 -->|"emit events"| SB
    SB -->|"broadcast"| O
    E1 -.->|"lifecycle hooks"| OBS
    E2 -.->|"lifecycle hooks"| OBS
    E3 -.->|"lifecycle hooks"| OBS

    style O fill:#4CAF50,color:#fff
    style D fill:#2196F3,color:#fff
    style SB fill:#FF9800,color:#fff
    style JH fill:#9C27B0,color:#fff
```


---

## Core Components

### 1. BaseJob

The immutable command object that describes **what** needs to be done.

```dart
// Simple Job
class LoadUsersJob extends BaseJob {
  LoadUsersJob() : super(id: generateJobId('load_users'));
}

// Job with parameters
class CreateUserJob extends BaseJob {
  final String name;
  final String email;
  
  CreateUserJob({required this.name, required this.email})
    : super(id: generateJobId('create_user'));
}
```

#### EventJob (v1.0.0+)

Jobs that automatically emit domain events upon completion:

```dart
class LoadUsersJob extends EventJob<List<User>, UsersLoadedEvent> {
  @override
  UsersLoadedEvent createEventTyped(List<User> result) {
    return UsersLoadedEvent(correlationId: id, users: result);
  }
  
  @override
  String? get cacheKey => 'users_list';
  
  @override
  Duration? get cacheTtl => Duration(minutes: 5);
}
```


### 2. BaseExecutor

Handles job execution with built-in support for timeout, retry, cancellation, and progress.

```dart
class LoadUsersExecutor extends BaseExecutor<LoadUsersJob> {
  final UserRepository _repo;
  
  LoadUsersExecutor(this._repo);
  
  @override
  Future<List<User>> process(LoadUsersJob job) async {
    // Progress reporting
    emitProgress(job.id, progress: 0.3, message: 'Fetching...');
    
    final users = await _repo.getAll();
    
    emitProgress(job.id, progress: 1.0, message: 'Done');
    return users;
  }
}
```

#### Executor Lifecycle

```mermaid
stateDiagram-v2
    [*] --> Received: Job dispatched
    Received --> Started: Begin execution
    Started --> Processing: process() called
    
    Processing --> Success: Return result
    Processing --> Failure: Throw exception
    Processing --> Cancelled: Token cancelled
    Processing --> Timeout: Exceeded duration
    
    Success --> [*]: Emit success event
    Failure --> Retrying: Has retry policy
    Failure --> [*]: Emit failure event
    Retrying --> Processing: Retry attempt
    Cancelled --> [*]: Emit cancelled event
    Timeout --> [*]: Emit timeout event
```


### 3. Dispatcher

Routes jobs to their registered executors. Singleton pattern ensures consistent routing.

```dart
// Registration (typically in app initialization)
final dispatcher = Dispatcher();
dispatcher.register<LoadUsersJob>(LoadUsersExecutor(repo));
dispatcher.register<CreateUserJob>(CreateUserExecutor(repo));

// Dispatch (internal - called by Orchestrator)
dispatcher.dispatch(job, handle: jobHandle);
```

```mermaid
flowchart LR
    subgraph "Dispatcher Registry"
        R["Map&lt;Type, Executor&gt;"]
    end
    
    J1[LoadUsersJob] --> R
    J2[CreateUserJob] --> R
    J3[DeleteUserJob] --> R
    
    R --> E1[LoadUsersExecutor]
    R --> E2[CreateUserExecutor]
    R --> E3[DeleteUserExecutor]
    
    style R fill:#2196F3,color:#fff
```


### 4. BaseOrchestrator

The "Reactive Brain" - manages state and reacts to domain events.

```dart
class UserOrchestrator extends BaseOrchestrator<UserState> {
  UserOrchestrator() : super(UserState.initial());
  
  // Dispatch jobs
  JobHandle<List<User>> loadUsers() {
    return dispatch<List<User>>(LoadUsersJob());
  }
  
  // React to ALL events via single handler
  @override
  void onEvent(BaseEvent event) {
    switch (event) {
      case UsersLoadedEvent e:
        emit(state.copyWith(users: e.users));
      case UserCreatedEvent e:
        emit(state.copyWith(users: [...state.users, e.user]));
      case UserDeletedEvent e:
        emit(state.copyWith(
          users: state.users.where((u) => u.id != e.userId).toList()
        ));
    }
  }
}
```


### 5. SignalBus

Broadcast event bus for decoupled communication. Supports both global and scoped instances.

```dart
// Global bus (default)
final globalBus = SignalBus.instance;

// Scoped bus (for testing or isolation)
final scopedBus = SignalBus.scoped();

// Listen to events
bus.listen((event) {
  print('Received: $event');
});

// Emit events
bus.emit(UserCreatedEvent(correlationId: jobId, user: newUser));
```

```mermaid
flowchart TB
    subgraph "Global Scope"
        GB[SignalBus.instance]
        O1[Orchestrator 1]
        O2[Orchestrator 2]
        E1[Executor 1]
        E2[Executor 2]
    end
    
    subgraph "Scoped (Test)"
        SB[SignalBus.scoped]
        TO[Test Orchestrator]
        TE[Test Executor]
    end
    
    E1 -->|emit| GB
    E2 -->|emit| GB
    GB -->|broadcast| O1
    GB -->|broadcast| O2
    
    TE -->|emit| SB
    SB -->|broadcast| TO
    
    GB x--x SB
    
    style GB fill:#FF9800,color:#fff
    style SB fill:#9C27B0,color:#fff
```


### 6. JobHandle

Represents a running job with future result and progress tracking.

```dart
// Fire and forget
orchestrator.loadUsers();

// Await result
final handle = orchestrator.loadUsers();
final result = await handle.future;
print(result.data);        // List<User>
print(result.source);      // DataSource.fresh | cached | optimistic

// Track progress
handle.progress.listen((p) {
  print('${p.value * 100}% - ${p.message}');
});
```

```mermaid
classDiagram
    class JobHandle~T~ {
        +String jobId
        +Future~JobHandleResult~T~~ future
        +Stream~JobProgress~ progress
        +bool isCompleted
        +complete(T data, DataSource source)
        +completeError(Object error)
        +reportProgress(double value, String? message)
    }
    
    class JobHandleResult~T~ {
        +T data
        +DataSource source
        +bool isCached
        +bool isFresh
        +bool isOptimistic
    }
    
    class JobProgress {
        +double value
        +String? message
        +int? currentStep
        +int? totalSteps
    }
    
    class DataSource {
        <<enumeration>>
        fresh
        cached
        optimistic
    }
    
    JobHandle --> JobHandleResult : completes with
    JobHandle --> JobProgress : emits
    JobHandleResult --> DataSource : has
```


---

## Data Flow

### Complete Job Execution Flow

```mermaid
sequenceDiagram
    autonumber
    participant UI as Flutter UI
    participant O as Orchestrator
    participant D as Dispatcher
    participant E as Executor
    participant SB as SignalBus
    participant OBS as Observer
    
    UI->>O: dispatch(LoadUsersJob)
    activate O
    O->>O: Create JobHandle<T>
    O->>O: Track job ID
    O->>D: dispatch(job, handle)
    deactivate O
    O-->>UI: return JobHandle
    
    activate D
    D->>D: Find executor by job type
    D->>E: execute(job, handle)
    deactivate D
    
    activate E
    E->>OBS: onJobStart(job)
    E->>E: Check cancellation token
    E->>E: process(job)
    
    alt Success
        E->>OBS: onJobSuccess(job, result, source)
        E->>SB: emit(JobSuccessEvent)
        E->>E: handle.complete(result, source)
    else Failure
        E->>OBS: onJobError(job, error, stack)
        E->>SB: emit(JobFailureEvent)
        E->>E: handle.completeError(error)
    end
    deactivate E
    
    activate SB
    SB->>O: broadcast event
    deactivate SB
    
    activate O
    O->>O: onEvent(event)
    O->>O: emit(newState)
    O->>O: Cleanup job tracking
    deactivate O
    
    UI->>UI: Rebuild with new state
```


### EventJob Flow (Domain Events)

```mermaid
sequenceDiagram
    autonumber
    participant O as Orchestrator
    participant E as Executor
    participant SB as SignalBus
    
    O->>E: execute(EventJob)
    activate E
    
    Note over E: Check cache
    alt Cache Hit
        E->>SB: emit(job.createEvent(cachedData))
        E->>E: handle.complete(cachedData, DataSource.cached)
        
        opt Revalidate enabled
            E->>E: Continue processing...
            E->>SB: emit(job.createEvent(freshData))
        end
    else Cache Miss
        E->>E: process(job)
        E->>E: Write to cache
        E->>SB: emit(job.createEvent(result))
        E->>E: handle.complete(result, DataSource.fresh)
    end
    deactivate E
    
    SB->>O: UsersLoadedEvent
    activate O
    O->>O: onEvent(UsersLoadedEvent)
    O->>O: emit(state.copyWith(users: e.users))
    deactivate O
```


---

## Event System

### Event Hierarchy

```mermaid
classDiagram
    class BaseEvent {
        <<abstract>>
        +String correlationId
        +DateTime timestamp
        +String? jobType
        +isFromJobType~T~() bool
    }
    
    class JobSuccessEvent~T~ {
        +T? data
        +DataSource source
    }
    
    class JobFailureEvent {
        +Object error
        +StackTrace? stackTrace
        +bool wasRetried
    }
    
    class JobCancelledEvent {
        +String? reason
    }
    
    class JobTimeoutEvent {
        +Duration timeout
    }
    
    class JobProgressEvent {
        +double progress
        +String? message
    }
    
    class UsersLoadedEvent {
        +List~User~ users
    }
    
    class UserCreatedEvent {
        +User user
    }
    
    BaseEvent <|-- JobSuccessEvent : deprecated
    BaseEvent <|-- JobFailureEvent : deprecated
    BaseEvent <|-- JobCancelledEvent : deprecated
    BaseEvent <|-- JobTimeoutEvent : deprecated
    BaseEvent <|-- JobProgressEvent : deprecated
    BaseEvent <|-- UsersLoadedEvent : domain event
    BaseEvent <|-- UserCreatedEvent : domain event
    
    note for JobSuccessEvent "Framework events are deprecated.\nUse domain events with EventJob instead."
```


### Active vs Passive Events

```mermaid
flowchart TB
    subgraph "Orchestrator A"
        OA[UserOrchestrator]
        JA[LoadUsersJob]
    end
    
    subgraph "Orchestrator B"
        OB[DashboardOrchestrator]
    end
    
    subgraph "SignalBus"
        SB[Broadcast]
    end
    
    OA -->|"dispatch"| JA
    JA -->|"success"| SB
    SB -->|"Active Event"| OA
    SB -->|"Passive Event"| OB
    
    OA -->|"isJobRunning(id) = true"| OA
    OB -->|"isJobRunning(id) = false"| OB
    
    style OA fill:#4CAF50,color:#fff
    style OB fill:#9C27B0,color:#fff
```

**Active Event**: The orchestrator that dispatched the job receives the completion event.
- `isJobRunning(event.correlationId)` returns `true`

**Passive Event**: Other orchestrators receive the same event as observers.
- `isJobRunning(event.correlationId)` returns `false`
- Useful for cross-feature state synchronization


---

## Advanced Features

### 1. Timeout & Cancellation

```mermaid
flowchart LR
    subgraph "Job Configuration"
        J[BaseJob]
        TO[timeout: Duration]
        CT[cancellationToken]
    end
    
    subgraph "Executor"
        E[process]
        TC[Token Check]
        TM[Timeout Monitor]
    end
    
    subgraph "Results"
        R1[JobTimeoutEvent]
        R2[JobCancelledEvent]
    end
    
    J --> TO
    J --> CT
    TO --> TM
    CT --> TC
    TM -->|"exceeded"| R1
    TC -->|"cancelled"| R2
```

```dart
// With timeout
final job = LoadUsersJob()..timeout = Duration(seconds: 30);

// With cancellation
final token = CancellationToken();
final job = LoadUsersJob()..cancellationToken = token;

// Cancel later
token.cancel();
```


### 2. Retry Policy

```mermaid
flowchart TB
    E[Execute] --> F{Failed?}
    F -->|No| S[Success]
    F -->|Yes| R{Retry Policy?}
    R -->|No| FE[Failure Event]
    R -->|Yes| A{Attempts < Max?}
    A -->|No| FE
    A -->|Yes| D[Delay]
    D --> RE[Retry Event]
    RE --> E
    
    style S fill:#4CAF50,color:#fff
    style FE fill:#f44336,color:#fff
    style RE fill:#FF9800,color:#fff
```

```dart
final job = LoadUsersJob()
  ..retryPolicy = RetryPolicy(
    maxRetries: 3,
    delay: Duration(seconds: 1),
    backoffMultiplier: 2.0,  // 1s, 2s, 4s
  );
```


### 3. Circuit Breaker (Loop Protection)

The orchestrator has built-in protection against infinite event loops.

```mermaid
flowchart TB
    E[Event Received] --> C{Count events<br/>per type per second}
    C --> L{Over limit?}
    L -->|No| P[Process Event]
    L -->|Yes| B[Block Event Type]
    B --> LOG[Log Warning]
    
    P --> H[onEvent handler]
    
    style B fill:#f44336,color:#fff
    style LOG fill:#FF9800,color:#fff
```

```dart
// Configure limits per event type
OrchestratorConfig.setLimit(JobProgressEvent, 100);  // Allow 100/sec
OrchestratorConfig.setLimit(JobSuccessEvent, 50);    // Allow 50/sec
```


### 4. OrchestratorObserver (Global Logging)

```mermaid
flowchart TB
    subgraph "Executors"
        E1[Executor 1]
        E2[Executor 2]
        E3[Executor 3]
    end
    
    subgraph "Observer"
        OBS[OrchestratorObserver.instance]
        START[onJobStart]
        SUCCESS[onJobSuccess]
        ERROR[onJobError]
        EVENT[onEvent]
    end
    
    subgraph "Logging"
        LOG[Logger / Analytics]
    end
    
    E1 --> OBS
    E2 --> OBS
    E3 --> OBS
    
    OBS --> START
    OBS --> SUCCESS
    OBS --> ERROR
    OBS --> EVENT
    
    START --> LOG
    SUCCESS --> LOG
    ERROR --> LOG
    EVENT --> LOG
    
    style OBS fill:#9C27B0,color:#fff
```

```dart
class MyObserver extends OrchestratorObserver {
  @override
  void onJobStart(BaseJob job) {
    analytics.track('job_started', {'type': job.runtimeType.toString()});
  }
  
  @override
  void onJobError(BaseJob job, Object error, StackTrace stack) {
    crashlytics.recordError(error, stack);
  }
}

// Set globally
OrchestratorObserver.instance = MyObserver();
```


---

## File Structure

```
packages/orchestrator_core/lib/
├── orchestrator_core.dart          # Public exports
└── src/
    ├── base/
    │   ├── base_executor.dart      # Job execution with lifecycle
    │   └── base_orchestrator.dart  # State management + event routing
    ├── infra/
    │   ├── dispatcher.dart         # Job → Executor routing
    │   ├── signal_bus.dart         # Event broadcast
    │   └── orchestrator_observer.dart  # Global logging
    ├── models/
    │   ├── job.dart                # BaseJob + EventJob
    │   ├── event.dart              # BaseEvent + framework events
    │   ├── job_handle.dart         # JobHandle + Result + Progress
    │   └── data_source.dart        # DataSource enum
    └── utils/
        ├── cancellation.dart       # CancellationToken
        ├── retry_policy.dart       # RetryPolicy
        └── logger.dart             # OrchestratorConfig
```


---

## Quick Reference

### Usage Patterns

| Pattern | Code | Use Case |
|---------|------|----------|
| Fire & Forget | `orchestrator.loadUsers()` | Update state via events |
| Await Result | `await handle.future` | Need immediate result |
| Track Progress | `handle.progress.listen(...)` | Show progress UI |
| Active Check | `isJobRunning(id)` | Distinguish own vs other jobs |

### Event Types

| Event | When Emitted | Deprecated? |
|-------|--------------|-------------|
| `JobSuccessEvent` | Job completed successfully | Yes - use domain events |
| `JobFailureEvent` | Job threw exception | Yes - use domain events |
| `JobCancelledEvent` | CancellationToken cancelled | Yes - use domain events |
| `JobTimeoutEvent` | Exceeded timeout duration | Yes - use domain events |
| `JobProgressEvent` | `emitProgress()` called | Yes - use JobHandle.progress |
| Custom domain events | EventJob completion | No - recommended |

### DataSource Values

| Value | Meaning |
|-------|---------|
| `DataSource.fresh` | Just fetched from source |
| `DataSource.cached` | Returned from cache |
| `DataSource.optimistic` | Optimistic update (pending confirmation) |

---

*Generated for orchestrator_core v1.0.0 - Domain Event Architecture v3*
