# Chapter 3: The Component Details

> *"Simplicity is the ultimate sophistication."* — Leonardo da Vinci

This chapter dives deeper into each component's internal structure and behavior, using diagrams to explain the mechanics.

---

## 3.1. The Job

A Job is a **request for work** — an immutable data object describing what needs to be done.

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'primaryColor': '#e0f2f1', 'primaryTextColor': '#1e293b', 'primaryBorderColor': '#334155', 'lineColor': '#334155', 'secondaryColor': '#f1f5f9', 'tertiaryColor': '#fef3c7' }}}%%
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
%%{init: {'theme': 'base', 'themeVariables': { 'primaryColor': '#e0f2f1', 'primaryTextColor': '#1e293b', 'primaryBorderColor': '#334155', 'lineColor': '#334155', 'secondaryColor': '#fef3c7', 'tertiaryColor': '#fee2e2' }}}%%
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
    
    style Registry fill:#e0f2f1,stroke:#334155,color:#1e293b
    style R1 fill:#f1f5f9,stroke:#334155,color:#1e293b
    style R2 fill:#f1f5f9,stroke:#334155,color:#1e293b
    style R3 fill:#f1f5f9,stroke:#334155,color:#1e293b
    style Job fill:#f1f5f9,stroke:#334155,color:#1e293b
    style Lookup fill:#e0f2f1,stroke:#334155,color:#1e293b
    style Executor fill:#fef3c7,stroke:#334155,color:#1e293b
```

### Registration Flow

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'primaryTextColor': '#1e293b', 'noteTextColor': '#1e293b', 'actorTextColor': '#1e293b' }}}%%
sequenceDiagram
    participant App as 🚀 App Startup
    participant Disp as 📮 Dispatcher
    participant Exec as ⚙️ Executor
    
    rect rgb(241, 245, 249)
        Note over App,Disp: Registration Phase
        App->>Disp: register<FetchUserJob>(UserExecutor())
        App->>Disp: register<LoginJob>(AuthExecutor())
    end
    
    Note over Disp: Registry populated
    
    rect rgb(224, 242, 241)
        Note over App,Exec: Dispatch Phase
        App->>Disp: dispatch(FetchUserJob(...))
        Disp->>Exec: execute(job)
    end
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
    
    style Executor fill:#e0f2f1,stroke:#334155,color:#1e293b
    style Start fill:#f1f5f9,stroke:#334155,color:#1e293b
    style CheckCancel fill:#e0f2f1,stroke:#334155,color:#1e293b
    style Cancelled fill:#fee2e2,stroke:#334155,color:#1e293b
    style Process fill:#e0f2f1,stroke:#334155,color:#1e293b
    style Success fill:#e0f2f1,stroke:#334155,color:#1e293b
    style EmitSuccess fill:#fef3c7,stroke:#334155,color:#1e293b
    style CheckRetry fill:#e0f2f1,stroke:#334155,color:#1e293b
    style Wait fill:#f1f5f9,stroke:#334155,color:#1e293b
    style EmitFailure fill:#fee2e2,stroke:#334155,color:#1e293b
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
    
    style ErrorBoundary fill:#e0f2f1,stroke:#334155,color:#1e293b
    style Try fill:#f1f5f9,stroke:#334155,color:#1e293b
    style Catch fill:#fee2e2,stroke:#334155,color:#1e293b
    style Note fill:#fef3c7,stroke:#334155,color:#1e293b
```

---

## 3.5. The Orchestrator (State Machine)

The Orchestrator is a **stateful coordinator** managing UI state and job tracking.

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'primaryColor': '#e0f2f1', 'primaryTextColor': '#1e293b', 'primaryBorderColor': '#334155', 'lineColor': '#334155', 'secondaryColor': '#fef3c7', 'tertiaryColor': '#fee2e2' }}}%%
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
    
    style Orchestrator fill:#e0f2f1,stroke:#334155,color:#1e293b
    style State fill:#f1f5f9,stroke:#334155,color:#1e293b
    style ActiveJobs fill:#f1f5f9,stroke:#334155,color:#1e293b
    style Subscription fill:#f1f5f9,stroke:#334155,color:#1e293b
    style Handlers fill:#e0f2f1,stroke:#334155,color:#1e293b
    style OnSuccess fill:#fef3c7,stroke:#334155,color:#1e293b
    style OnFailure fill:#fee2e2,stroke:#334155,color:#1e293b
    style OnPassive fill:#fef3c7,stroke:#334155,color:#1e293b
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
    
    style Event fill:#f1f5f9,stroke:#334155,color:#1e293b
    style Extract fill:#e0f2f1,stroke:#334155,color:#1e293b
    style Check fill:#e0f2f1,stroke:#334155,color:#1e293b
    style Direct fill:#0d9488,stroke:#334155,color:#ffffff
    style Observer fill:#fef3c7,stroke:#334155,color:#1e293b
    style Remove fill:#e0f2f1,stroke:#334155,color:#1e293b
    style TypeCheck fill:#e0f2f1,stroke:#334155,color:#1e293b
    style OnSuccess fill:#fef3c7,stroke:#334155,color:#1e293b
    style OnFailure fill:#fee2e2,stroke:#334155,color:#1e293b
    style OnPassive fill:#fef3c7,stroke:#334155,color:#1e293b
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
    
    style Publishers fill:#f1f5f9,stroke:#334155,color:#1e293b
    style Bus fill:#0d9488,stroke:#334155,color:#ffffff
    style Subscribers fill:#fef3c7,stroke:#334155,color:#1e293b
    style Stream fill:#0d9488,stroke:#334155,color:#ffffff
    style E1 fill:#f1f5f9,stroke:#334155,color:#1e293b
    style E2 fill:#f1f5f9,stroke:#334155,color:#1e293b
    style E3 fill:#f1f5f9,stroke:#334155,color:#1e293b
    style O1 fill:#fef3c7,stroke:#334155,color:#1e293b
    style O2 fill:#fef3c7,stroke:#334155,color:#1e293b
    style O3 fill:#fef3c7,stroke:#334155,color:#1e293b
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
    
    style GlobalBus fill:#0d9488,stroke:#334155,color:#ffffff
    style ScopedBus fill:#e0f2f1,stroke:#334155,color:#1e293b
    style GB fill:#0d9488,stroke:#334155,color:#ffffff
    style SB1 fill:#f1f5f9,stroke:#334155,color:#1e293b
    style SB2 fill:#f1f5f9,stroke:#334155,color:#1e293b
    style SB3 fill:#f1f5f9,stroke:#334155,color:#1e293b
    style Public fill:#fef3c7,stroke:#334155,color:#1e293b
    style Private fill:#fef3c7,stroke:#334155,color:#1e293b
```

---

## 3.7. Complete System Flow

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'primaryTextColor': '#1e293b', 'noteTextColor': '#1e293b', 'actorTextColor': '#1e293b' }}}%%
sequenceDiagram
    participant UI as 🖥️ UI
    participant Orch as 🎭 Orchestrator
    participant Disp as 📮 Dispatcher
    participant Exec as ⚙️ Executor
    participant API as 🌐 API
    participant Bus as 📡 Bus
    
    rect rgb(241, 245, 249)
        Note over UI,Orch: 1. User Action
        UI->>+Orch: fetchUser()
        Orch->>Orch: emit(Loading)
    end
    
    rect rgb(224, 242, 241)
        Note over Orch,Exec: 2. Dispatch
        Orch->>+Disp: dispatch(FetchUserJob)
        Disp-->>Orch: correlationId
        Orch->>Orch: activeJobs.add(id)
        Disp->>+Exec: execute(job)
        Disp-->>-Orch: 
    end
    
    rect rgb(254, 243, 199)
        Note over Exec,API: 3. Execution
        Exec->>+API: GET /users/123
        API-->>-Exec: User data
    end
    
    rect rgb(254, 243, 199)
        Note over Exec,Orch: 4. Event Broadcast
        Exec->>-Bus: emit(SuccessEvent)
        Bus->>Orch: Event(correlationId=id)
    end
    
    rect rgb(224, 242, 241)
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
    
    style Root fill:#0d9488,stroke:#334155,stroke-width:2px,color:#ffffff
    style Job fill:#e0f2f1,stroke:#334155,color:#1e293b
    style Event fill:#fef3c7,stroke:#334155,color:#1e293b
    style Disp fill:#e0f2f1,stroke:#334155,color:#1e293b
    style Exec fill:#fef3c7,stroke:#334155,color:#1e293b
    style Orch fill:#e0f2f1,stroke:#334155,color:#1e293b
    style Bus fill:#0d9488,stroke:#334155,color:#ffffff
    
    style J1 fill:#f1f5f9,stroke:#334155,color:#1e293b
    style J2 fill:#f1f5f9,stroke:#334155,color:#1e293b
    style J3 fill:#f1f5f9,stroke:#334155,color:#1e293b
    
    style E1 fill:#f1f5f9,stroke:#334155,color:#1e293b
    style E2 fill:#f1f5f9,stroke:#334155,color:#1e293b
    style E3 fill:#f1f5f9,stroke:#334155,color:#1e293b
    
    style D1 fill:#f1f5f9,stroke:#334155,color:#1e293b
    style D2 fill:#f1f5f9,stroke:#334155,color:#1e293b
    style D3 fill:#f1f5f9,stroke:#334155,color:#1e293b
    
    style Ex1 fill:#f1f5f9,stroke:#334155,color:#1e293b
    style Ex2 fill:#f1f5f9,stroke:#334155,color:#1e293b
    style Ex3 fill:#f1f5f9,stroke:#334155,color:#1e293b
    
    style O1 fill:#f1f5f9,stroke:#334155,color:#1e293b
    style O2 fill:#f1f5f9,stroke:#334155,color:#1e293b
    style O3 fill:#f1f5f9,stroke:#334155,color:#1e293b
    
    style B1 fill:#f1f5f9,stroke:#334155,color:#1e293b
    style B2 fill:#f1f5f9,stroke:#334155,color:#1e293b
    style B3 fill:#f1f5f9,stroke:#334155,color:#1e293b
```

**Key Takeaway**: Each component has a single responsibility, connected through well-defined interfaces. This makes the system testable, maintainable, and scalable.
