# Chapter 4: Core Patterns

> *"A pattern is a solution to a problem in a context."* — Christopher Alexander

This chapter describes the fundamental patterns that make the architecture work.

---

## 4.1. The Job-Executor Pattern

**Problem**: How to decouple what needs to be done from how it's done?

**Solution**: Separate the request (Job) from the handler (Executor).

```mermaid
graph LR
    subgraph Pattern["Job-Executor Pattern"]
        Job["📋 Job<br/>(What)"] --> Executor["⚙️ Executor<br/>(How)"]
        Executor --> Event["📨 Event<br/>(Result)"]
    end
    
    style Pattern fill:#f1f5f9,stroke:#334155,color:#1e293b
    style Job fill:#f1f5f9,stroke:#334155,color:#1e293b
    style Executor fill:#e0f2f1,stroke:#334155,color:#1e293b
    style Event fill:#fef3c7,stroke:#334155,color:#1e293b
```

### Structure

```mermaid
classDiagram
    class Job {
        <<interface>>
        +id: String
        +metadata: Map?
    }
    
    class Executor~T~ {
        <<abstract>>
        +process(job: T): Future
        +execute(job: T): void
    }
    
    class Dispatcher {
        +register~T~(executor: Executor~T~)
        +dispatch(job: Job): String
    }
    
    Dispatcher --> Executor : routes to
    Executor ..> Job : processes
```

### Consequences

| Benefit | Description |
|---------|-------------|
| **Testability** | Test Executor without UI |
| **Reusability** | Same Executor for multiple callers |
| **Single Responsibility** | Each Executor does one thing |

---

## 4.2. The Event Routing Pattern

**Problem**: How does the right Orchestrator receive the right Event?

**Solution**: Use Correlation ID to match events to their originators.

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'primaryTextColor': '#1e293b', 'noteTextColor': '#1e293b', 'actorTextColor': '#1e293b' }}}%%
sequenceDiagram
    participant OrcA as Orchestrator A
    participant OrcB as Orchestrator B
    participant Bus as Signal Bus
    
    Note over OrcA: activeJobs = [job-001]
    Note over OrcB: activeJobs = [job-002]
    
    Bus->>OrcA: Event(id=job-001)
    Bus->>OrcB: Event(id=job-001)
    
    Note over OrcA: ✅ job-001 in activeJobs<br/>→ Direct Mode
    Note over OrcB: ❌ job-001 not mine<br/>→ Observer Mode
```

### The Routing Algorithm

```mermaid
flowchart TD
    Start["Event Received"] --> Extract["Extract correlationId"]
    Extract --> Lookup["Lookup in activeJobIds"]
    Lookup --> Found{"Found?"}
    
    Found -->|"YES"| Direct["Direct Mode Handler"]
    Found -->|"NO"| PassiveCheck{"Interested in this event type?"}
    
    PassiveCheck -->|"YES"| Observer["Observer Mode Handler"]
    PassiveCheck -->|"NO"| Ignore["Ignore Event"]
    
    Direct --> Remove["Remove from activeJobIds"]
    
    style Start fill:#f1f5f9,stroke:#334155,color:#1e293b
    style Extract fill:#e0f2f1,stroke:#334155,color:#1e293b
    style Lookup fill:#e0f2f1,stroke:#334155,color:#1e293b
    style Found fill:#e0f2f1,stroke:#334155,color:#1e293b
    style Direct fill:#0d9488,stroke:#334155,color:#ffffff
    style PassiveCheck fill:#e0f2f1,stroke:#334155,color:#1e293b
    style Observer fill:#fef3c7,stroke:#334155,color:#1e293b
    style Ignore fill:#f1f5f9,stroke:#334155,color:#1e293b
    style Remove fill:#e0f2f1,stroke:#334155,color:#1e293b
```

---

## 4.3. The State Transition Pattern

**Problem**: How to manage UI state consistently across async operations?

**Solution**: Define clear states and transitions triggered by events.

```mermaid
stateDiagram-v2
    [*] --> Idle: Initial
    
    Idle --> Loading: dispatch(Job)
    
    Loading --> Success: onActiveSuccess
    Loading --> Error: onActiveFailure
    Loading --> Loading: onProgress
    
    Success --> Idle: reset()
    Success --> Loading: refresh()
    
    Error --> Idle: dismiss()
    Error --> Loading: retry()
```

### State Categories

```mermaid
graph TB
    subgraph ControlState["🎮 Control State"]
        Loading["isLoading"]
        Error["hasError"]
        Submitted["isSubmitted"]
    end
    
    subgraph DataState["📊 Data State"]
        User["user: User?"]
        Items["items: List"]
        Count["count: int"]
    end
    
    Note["Control = UI behavior<br/>Data = Business content"]
    
    style ControlState fill:#e0f2f1,stroke:#334155,color:#1e293b
    style DataState fill:#fef3c7,stroke:#334155,color:#1e293b
    style Loading fill:#f1f5f9,stroke:#334155,color:#1e293b
    style Error fill:#f1f5f9,stroke:#334155,color:#1e293b
    style Submitted fill:#f1f5f9,stroke:#334155,color:#1e293b
    style User fill:#f1f5f9,stroke:#334155,color:#1e293b
    style Items fill:#f1f5f9,stroke:#334155,color:#1e293b
    style Count fill:#f1f5f9,stroke:#334155,color:#1e293b
    style Note fill:#0d9488,stroke:#334155,color:#ffffff
```

### Rule

> **Control State** should only be modified by **Direct Mode** events.
> **Data State** can be modified by both Direct and Observer modes.

---

## 4.4. The Scoped Bus Pattern

**Problem**: How to prevent event leakage between modules?

**Solution**: Create isolated buses for independent modules.

```mermaid
graph TB
    subgraph AuthModule["🔐 Auth Module"]
        AuthBus["Scoped Bus A"]
        AuthOrch["Auth Orchestrator"]
        AuthExec["Auth Executor"]
        
        AuthOrch <-.-> AuthBus
        AuthExec --> AuthBus
    end
    
    subgraph ChatModule["💬 Chat Module"]
        ChatBus["Scoped Bus B"]
        ChatOrch["Chat Orchestrator"]
        ChatExec["Chat Executor"]
        
        ChatOrch <-.-> ChatBus
        ChatExec --> ChatBus
    end
    
    subgraph GlobalBus["🌍 Global Bus"]
        GB["Public Events"]
    end
    
    AuthModule -.->|"UserLoggedIn"| GlobalBus
    ChatModule -.->|"MessageSent"| GlobalBus
    
    style AuthModule fill:#e0f2f1,stroke:#334155,color:#1e293b
    style ChatModule fill:#e0f2f1,stroke:#334155,color:#1e293b
    style GlobalBus fill:#0d9488,stroke:#334155,color:#ffffff
    style AuthBus fill:#f1f5f9,stroke:#334155,color:#1e293b
    style ChatBus fill:#f1f5f9,stroke:#334155,color:#1e293b
    style GB fill:#0d9488,stroke:#334155,color:#ffffff
    style AuthOrch fill:#f1f5f9,stroke:#334155,color:#1e293b
    style AuthExec fill:#f1f5f9,stroke:#334155,color:#1e293b
    style ChatOrch fill:#f1f5f9,stroke:#334155,color:#1e293b
    style ChatExec fill:#f1f5f9,stroke:#334155,color:#1e293b
```

### When to Use Each

| Bus Type | Use Case | Example Events |
|----------|----------|----------------|
| **Scoped** | Internal module state | LoadingStarted, StepComplete |
| **Global** | Cross-module communication | UserLoggedIn, ThemeChanged |

---

## 4.5. The Registry Pattern

**Problem**: How to efficiently route Jobs to Executors?

**Solution**: Maintain a type-based registry with O(1) lookup.

```mermaid
graph TB
    subgraph Registry["📮 Registry"]
        Map["Map<Type, Executor>"]
        
        E1["FetchUserJob → UserExecutor"]
        E2["LoginJob → AuthExecutor"]
        E3["UploadJob → FileExecutor"]
    end
    
    Job["Job (Type: FetchUserJob)"] --> Lookup["registry[job.type]"]
    Lookup --> Match["UserExecutor"]
    
    style Registry fill:#e0f2f1,stroke:#334155,color:#1e293b
    style Map fill:#f1f5f9,stroke:#334155,color:#1e293b
    style E1 fill:#f1f5f9,stroke:#334155,color:#1e293b
    style E2 fill:#f1f5f9,stroke:#334155,color:#1e293b
    style E3 fill:#f1f5f9,stroke:#334155,color:#1e293b
    style Job fill:#f1f5f9,stroke:#334155,color:#1e293b
    style Lookup fill:#e0f2f1,stroke:#334155,color:#1e293b
    style Match fill:#fef3c7,stroke:#334155,color:#1e293b
```

### Registration Strategies

```mermaid
flowchart LR
    subgraph Strategies["Registration Timing"]
        Startup["🚀 At App Startup"]
        Lazy["⏳ Lazy Registration"]
        DI["💉 Dependency Injection"]
    end
    
    Startup --> Pro1["✅ Simple, predictable"]
    Lazy --> Pro2["✅ Smaller initial load"]
    DI --> Pro3["✅ Testable, mockable"]
    
    style Strategies fill:#e0f2f1,stroke:#334155,color:#1e293b
    style Startup fill:#f1f5f9,stroke:#334155,color:#1e293b
    style Lazy fill:#f1f5f9,stroke:#334155,color:#1e293b
    style DI fill:#f1f5f9,stroke:#334155,color:#1e293b
    style Pro1 fill:#fef3c7,stroke:#334155,color:#1e293b
    style Pro2 fill:#fef3c7,stroke:#334155,color:#1e293b
    style Pro3 fill:#fef3c7,stroke:#334155,color:#1e293b
```

---

## 4.6. The Error Boundary Pattern

**Problem**: How to prevent executor errors from crashing the app?

**Solution**: Wrap all executor logic in try-catch and convert to events.

```mermaid
flowchart TD
    subgraph Executor["⚙️ Executor"]
        Start["execute(job)"]
        Try["try {"]
        Process["process(job)"]
        TryCatch["} catch (e) {"]
        EmitFail["emitFailure(e)"]
        End["}"]
        
        Start --> Try
        Try --> Process
        Process -->|"Success"| EmitSuccess["emitSuccess(result)"]
        Process -->|"Exception"| TryCatch
        TryCatch --> EmitFail
    end
    
    Note["❌ Exceptions NEVER escape executor"]
    
    style Executor fill:#e0f2f1,stroke:#334155,color:#1e293b
    style Start fill:#f1f5f9,stroke:#334155,color:#1e293b
    style Try fill:#f1f5f9,stroke:#334155,color:#1e293b
    style Process fill:#e0f2f1,stroke:#334155,color:#1e293b
    style TryCatch fill:#f1f5f9,stroke:#334155,color:#1e293b
    style End fill:#f1f5f9,stroke:#334155,color:#1e293b
    style EmitSuccess fill:#fef3c7,stroke:#334155,color:#1e293b
    style EmitFail fill:#fee2e2,stroke:#334155,color:#1e293b
    style Note fill:#0d9488,stroke:#334155,color:#ffffff
```

### Guarantee

> **Every job dispatch results in exactly one event**: Success OR Failure.
> The Orchestrator can always rely on receiving a response.

---

## 4.7. Pattern Relationships

```mermaid
graph TB
    subgraph Patterns["🧩 Core Patterns"]
        JE["Job-Executor"]
        ER["Event Routing"]
        ST["State Transition"]
        SB["Scoped Bus"]
        RG["Registry"]
        EB["Error Boundary"]
    end
    
    JE -->|"enables"| ER
    ER -->|"triggers"| ST
    SB -->|"isolates"| ER
    RG -->|"optimizes"| JE
    EB -->|"protects"| JE
    
    style Patterns fill:#f1f5f9,stroke:#334155,color:#1e293b
    style JE fill:#e0f2f1,stroke:#334155,color:#1e293b
    style ER fill:#fef3c7,stroke:#334155,color:#1e293b
    style ST fill:#0d9488,stroke:#334155,color:#ffffff
    style SB fill:#e0f2f1,stroke:#334155,color:#1e293b
    style RG fill:#f1f5f9,stroke:#334155,color:#1e293b
    style EB fill:#f1f5f9,stroke:#334155,color:#1e293b
```

---

## Summary

| Pattern | Problem Solved | Key Mechanism |
|---------|----------------|---------------|
| **Job-Executor** | Decouple request from handler | Type-based routing |
| **Event Routing** | Match events to originators | Correlation ID |
| **State Transition** | Consistent UI state | State machine |
| **Scoped Bus** | Prevent event leakage | Isolated channels |
| **Registry** | Efficient routing | O(1) lookup map |
| **Error Boundary** | Prevent crashes | Automatic try-catch |

**Key Takeaway**: These patterns work together to create a robust, testable, and scalable architecture.
