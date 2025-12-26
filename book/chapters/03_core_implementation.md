# Chapter 3: The Component Details

> *"Simplicity is the ultimate sophistication."* — Leonardo da Vinci

This chapter dives deeper into each component's internal structure and behavior, using diagrams to explain the mechanics.

---

## 3.1. The Job

A Job is a **request for work** — an immutable data object describing what needs to be done.

```mermaid
classDiagram
    class BaseJob {
        +String id
        +Map~String, dynamic~? metadata
        +CancellationToken? cancellationToken
        +Duration? timeout
        +RetryPolicy? retryPolicy
    }
    
    class FetchUserJob {
        +String userId
    }
    
    class UploadFileJob {
        +File file
        +String destination
    }
    
    BaseJob <|-- FetchUserJob
    BaseJob <|-- UploadFileJob
```

### Job Properties

| Property | Purpose |
|----------|---------|
| `id` | Correlation ID for tracking |
| `metadata` | Optional context data |
| `cancellationToken` | For explicit cancellation |
| `timeout` | Maximum execution time |
| `retryPolicy` | Retry configuration |

---

## 3.2. The Event

An Event is a **notification of what happened** — the result of job execution.

```mermaid
classDiagram
    class BaseEvent {
        +String correlationId
        +DateTime timestamp
    }
    
    class JobSuccessEvent~T~ {
        +T data
    }
    
    class JobFailureEvent {
        +Object error
        +StackTrace? stackTrace
    }
    
    class JobProgressEvent {
        +double progress
        +String? message
    }
    
    BaseEvent <|-- JobSuccessEvent
    BaseEvent <|-- JobFailureEvent
    BaseEvent <|-- JobProgressEvent
```

### Event Types

| Event Type | When Emitted |
|------------|--------------|
| `JobSuccessEvent` | Job completed successfully |
| `JobFailureEvent` | Job encountered an error |
| `JobProgressEvent` | Job is partially complete |
| `JobTimeoutEvent` | Job exceeded time limit |
| `JobRetryingEvent` | Job is being retried |

---

## 3.3. The Dispatcher (Routing)

The Dispatcher maintains a registry mapping Job types to Executors.

```mermaid
graph LR
    subgraph Registry["📮 Dispatcher Registry"]
        R1["FetchUserJob → UserExecutor"]
        R2["LoginJob → AuthExecutor"]
        R3["UploadJob → UploadExecutor"]
    end
    
    Job["Incoming Job"] --> Lookup{"Type Lookup<br/>O(1)"}
    Lookup --> Executor["Matched Executor"]
    
    style Registry fill:#f3f0ff
```

### Registration Flow

```mermaid
sequenceDiagram
    participant App as 🚀 App Startup
    participant Disp as 📮 Dispatcher
    participant Exec as ⚙️ Executor
    
    App->>Disp: register<FetchUserJob>(UserExecutor())
    App->>Disp: register<LoginJob>(AuthExecutor())
    
    Note over Disp: Registry populated
    
    App->>Disp: dispatch(FetchUserJob(...))
    Disp->>Exec: execute(job)
```

---

## 3.4. The Executor (Processing)

The Executor is a **stateless worker** with built-in error handling.

```mermaid
flowchart TB
    subgraph Executor["⚙️ Executor"]
        Start["execute(job)"] --> CheckCancel{"Cancelled?"}
        CheckCancel -->|"YES"| Cancelled["❌ CancelledException"]
        CheckCancel -->|"NO"| Process["process(job)"]
        Process --> Success{"Success?"}
        Success -->|"YES"| EmitSuccess["emit(SuccessEvent)"]
        Success -->|"ERROR"| CheckRetry{"Can Retry?"}
        CheckRetry -->|"YES"| Wait["Wait (backoff)"]
        Wait --> Process
        CheckRetry -->|"NO"| EmitFailure["emit(FailureEvent)"]
    end
    
    style EmitSuccess fill:#37b24d,color:#fff
    style EmitFailure fill:#f03e3e,color:#fff
```

### Error Boundary

Every Executor has an automatic error boundary:

```mermaid
graph TB
    subgraph ErrorBoundary["🛡️ Error Boundary"]
        Try["try { process(job) }"]
        Catch["catch (error) { emitFailure() }"]
    end
    
    Try -->|"Exception"| Catch
    
    Note["✅ Exceptions NEVER escape<br/>Always converted to Events"]
```

---

## 3.5. The Orchestrator (State Machine)

The Orchestrator is a **stateful coordinator** managing UI state and job tracking.

```mermaid
stateDiagram-v2
    [*] --> Idle
    
    Idle --> Loading: dispatch(Job)
    Loading --> Success: onActiveSuccess
    Loading --> Error: onActiveFailure
    
    Error --> Loading: retry()
    Success --> Loading: refresh()
    
    state Loading {
        [*] --> Waiting
        Waiting --> Progress: onProgress
        Progress --> Progress: more progress
    }
```

### Internal Structure

```mermaid
graph TB
    subgraph Orchestrator["🎭 Orchestrator"]
        State["📊 Current State"]
        ActiveJobs["🏃 Active Job IDs<br/>{abc123, xyz789}"]
        Subscription["📡 Bus Subscription"]
        
        Handlers["Event Handlers"]
        Handlers --> OnSuccess["onActiveSuccess()"]
        Handlers --> OnFailure["onActiveFailure()"]
        Handlers --> OnPassive["onPassiveEvent()"]
    end
```

### Event Routing Logic

```mermaid
flowchart TD
    Event["📨 Event Received"] --> Extract["Extract correlationId"]
    Extract --> Check{"correlationId ∈ activeJobIds?"}
    
    Check -->|"YES"| Direct["🎯 Direct Mode"]
    Check -->|"NO"| Observer["👀 Observer Mode"]
    
    Direct --> Remove["Remove from activeJobIds"]
    Remove --> TypeCheck{"Event Type?"}
    TypeCheck -->|"Success"| OnSuccess["onActiveSuccess()"]
    TypeCheck -->|"Failure"| OnFailure["onActiveFailure()"]
    
    Observer --> OnPassive["onPassiveEvent()"]
```

---

## 3.6. The Signal Bus (Broadcasting)

The Signal Bus is a **publish-subscribe** mechanism for event distribution.

```mermaid
graph TB
    subgraph Publishers["Publishers"]
        E1["Executor 1"]
        E2["Executor 2"]
        E3["Executor 3"]
    end
    
    subgraph Bus["📡 Signal Bus"]
        Stream["Broadcast Stream"]
    end
    
    subgraph Subscribers["Subscribers"]
        O1["Orchestrator A"]
        O2["Orchestrator B"]
        O3["Orchestrator C"]
    end
    
    E1 & E2 & E3 --> Stream
    Stream --> O1 & O2 & O3
    
    style Stream fill:#f59f00,color:#fff
```

### Global vs Scoped Bus

```mermaid
graph TB
    subgraph GlobalBus["🌍 Global Bus"]
        GB["All events visible<br/>to all orchestrators"]
    end
    
    subgraph ScopedBus["🔒 Scoped Bus"]
        SB1["Auth Module Bus"]
        SB2["Chat Module Bus"]
        SB3["Cart Module Bus"]
    end
    
    GlobalBus -.->|"Use for"| Public["Public Events<br/>(UserLoggedIn, ThemeChanged)"]
    ScopedBus -.->|"Use for"| Private["Private Events<br/>(Internal state changes)"]
```

---

## 3.7. Complete System Flow

```mermaid
sequenceDiagram
    participant UI as 🖥️ UI
    participant Orch as 🎭 Orchestrator
    participant Disp as 📮 Dispatcher
    participant Exec as ⚙️ Executor
    participant API as 🌐 API
    participant Bus as 📡 Bus
    
    rect rgb(240, 247, 255)
        Note over UI,Orch: 1. User Action
        UI->>+Orch: fetchUser()
        Orch->>Orch: emit(Loading)
    end
    
    rect rgb(240, 255, 240)
        Note over Orch,Exec: 2. Dispatch
        Orch->>+Disp: dispatch(FetchUserJob)
        Disp-->>Orch: correlationId
        Orch->>Orch: activeJobs.add(id)
        Disp->>+Exec: execute(job)
        Disp-->>-Orch: 
    end
    
    rect rgb(255, 250, 240)
        Note over Exec,API: 3. Execution
        Exec->>+API: GET /users/123
        API-->>-Exec: User data
    end
    
    rect rgb(255, 240, 240)
        Note over Exec,Orch: 4. Event Broadcast
        Exec->>-Bus: emit(SuccessEvent)
        Bus->>Orch: Event(correlationId=id)
    end
    
    rect rgb(240, 240, 255)
        Note over Orch,UI: 5. State Update
        Orch->>Orch: onActiveSuccess()
        Orch->>Orch: emit(Success)
        Orch-->>-UI: New State
    end
```

---

## Summary

```mermaid
graph LR
    Root((Architecture))
    
    Root --> Job["Job"]
    Job --> J1["Request for work"]
    Job --> J2["Immutable data"]
    Job --> J3["Carries correlationId"]
    
    Root --> Event["Event"]
    Event --> E1["Notification of result"]
    Event --> E2["Success/Failure/Progress"]
    Event --> E3["Broadcast to all"]
    
    Root --> Disp["Dispatcher"]
    Disp --> D1["Routes Jobs to Executors"]
    Disp --> D2["Registry pattern"]
    Disp --> D3["O(1) lookup"]
    
    Root --> Exec["Executor"]
    Exec --> Ex1["Stateless worker"]
    Exec --> Ex2["Error boundary"]
    Exec --> Ex3["Emits events"]
    
    Root --> Orch["Orchestrator"]
    Orch --> O1["Stateful coordinator"]
    Orch --> O2["Tracks active jobs"]
    Orch --> O3["Direct + Observer modes"]
    
    Root --> Bus["Signal Bus"]
    Bus --> B1["Pub/Sub mechanism"]
    Bus --> B2["Global or Scoped"]
    Bus --> B3["Decoupled communication"]
    
    style Root fill:#4c6ef5,stroke:#333,stroke-width:2px,color:#fff
    style Job fill:#37b24d,color:#fff
    style Event fill:#f59f00,color:#fff
    style Disp fill:#845ef7,color:#fff
    style Exec fill:#f03e3e,color:#fff
    style Orch fill:#4c6ef5,color:#fff
    style Bus fill:#fcc419,color:#000
    
    style J1 fill:#fff,stroke:#333,color:#000
    style J2 fill:#fff,stroke:#333,color:#000
    style J3 fill:#fff,stroke:#333,color:#000
    
    style E1 fill:#fff,stroke:#333,color:#000
    style E2 fill:#fff,stroke:#333,color:#000
    style E3 fill:#fff,stroke:#333,color:#000
    
    style D1 fill:#fff,stroke:#333,color:#000
    style D2 fill:#fff,stroke:#333,color:#000
    style D3 fill:#fff,stroke:#333,color:#000
    
    style Ex1 fill:#fff,stroke:#333,color:#000
    style Ex2 fill:#fff,stroke:#333,color:#000
    style Ex3 fill:#fff,stroke:#333,color:#000
    
    style O1 fill:#fff,stroke:#333,color:#000
    style O2 fill:#fff,stroke:#333,color:#000
    style O3 fill:#fff,stroke:#333,color:#000
    
    style B1 fill:#fff,stroke:#333,color:#000
    style B2 fill:#fff,stroke:#333,color:#000
    style B3 fill:#fff,stroke:#333,color:#000
```

**Key Takeaway**: Each component has a single responsibility, connected through well-defined interfaces. This makes the system testable, maintainable, and scalable.
