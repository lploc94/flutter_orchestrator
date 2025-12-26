# Chapter 7: Best Practices & Guidelines

> *"Rules are for the obedience of fools and the guidance of wise men."* — Douglas Bader

This chapter provides practical guidelines, golden rules, and structured advice to help your team implement the Flutter Orchestrator architecture successfully.

---

## 7.1. The Golden Rules

Every architecture has its non-negotiable rules. These are ours.

### ✅ DO

```mermaid
graph TB
    subgraph Do["✅ Best Practices"]
        D1["Separate Orchestration from Execution"]
        D2["Use immutable State with copyWith"]
        D3["Include correlationId in all events"]
        D4["Handle cancellation in long operations"]
        D5["Use Scoped Bus for module privacy"]
        D6["Test Executors in isolation"]
    end
```

1.  **Separate Orchestration from Execution**: This is the prime directive. Never mix them.
2.  **Immutable State**: Always return a *new* state object. Never mutate fields on an existing state object.
3.  **Correlation IDs**: Without them, you cannot safely distinguish between multiple concurrent requests.
4.  **Cancellation Service**: Respect the user's time and battery. If they leave a screen, kill the background work.

### ❌ DON'T

```mermaid
graph TB
    subgraph Dont["❌ Anti-Patterns"]
        X1["Call Repository in Orchestrator"]
        X2["Create 'God Events' (generic types)"]
        X3["Skip cancellation checkpoints"]
        X4["Mix control and data state"]
        X5["Use global bus for private events"]
        X6["Ignore error handling"]
    end
    
    style Dont fill:#fff5f5
```

1.  **No Repositories in Orchestrator**: The Orchestrator should not even import your repository classes.
2.  **No God Events**: Avoid `GenericSuccessEvent` or `DataLoadedEvent`. Be specific: `UserLoginSuccessEvent`, `ProductDetailsLoadedEvent`.
3.  **Check Cancellation**: An executor that runs for 5 seconds but never checks `isCancelled` is a battery drainer.

---

## 7.2. Folder Structure

A consistent folder structure helps onboard new developers and keeps the codebase scalable.

### Feature-First (Recommended)

We strongly recommend organizing code by **Cluster/Feature**, not by layer.

```mermaid
graph TB
    subgraph FeatureFirst["📁 Feature-First Structure"]
        Root["lib/"]
        Core["core/"]
        Features["features/"]
        
        Auth["auth/"]
        AuthJobs["jobs/"]
        AuthExec["executors/"]
        AuthOrch["orchestrator/"]
        AuthUI["ui/"]
        
        Root --> Core
        Root --> Features
        Features --> Auth
        Auth --> AuthJobs
        Auth --> AuthExec
        Auth --> AuthOrch
        Auth --> AuthUI
    end
```

The typical file structure looks like this:

```
lib/
├── core/
│   ├── base/           # Base classes (BaseJob, BaseExecutor)
│   └── di/             # Dependency injection setup
├── features/
│   ├── auth/
│   │   ├── jobs/       # LoginJob, LogoutJob
│   │   ├── executors/  # AuthExecutor
│   │   ├── orchestrator/ # AuthOrchestrator, AuthState
│   │   └── ui/         # LoginScreen, ProfileWidget
│   └── chat/
│       ├── jobs/
│       ├── executors/
│       ├── orchestrator/
│       └── ui/
└── main.dart
```

### Why Feature-First?

| Benefit | Description |
|---------|-------------|
| **Locality** | Everything related to "Auth" is in one place. You don't have to jump between 5 different top-level folders. |
| **Isolation** | Features can be developed, tested, and even extracted into packages independently. |
| **Scalability** | Adding a new feature doesn't clutter global folders. |
| **Deletion** | "Deleting a feature" means deleting one folder. No leftover zombie files. |

---

## 7.3. Naming Conventions

Consistency makes code readable.

```mermaid
graph LR
    subgraph Naming["📝 Naming Patterns"]
        Jobs["*Job<br/>FetchUserJob, LoginJob"]
        Executors["*Executor<br/>UserExecutor, AuthExecutor"]
        Events["*Event<br/>UserLoadedEvent, LoginSuccessEvent"]
        Orchestrators["*Orchestrator / *Cubit<br/>AuthOrchestrator, ChatCubit"]
    end
```

| Component | Pattern | Example |
|-----------|---------|---------|
| **Job** | `{Action}{Resource}Job` | `FetchUserJob`, `UploadFileJob` |
| **Executor** | `{Resource}Executor` | `UserExecutor` (handles all user-related jobs), `FileExecutor` |
| **Event** | `{Resource}{Action}{Result}Event` | `UserLoadedEvent`, `FileSavedEvent`, `LoginFailureEvent` |
| **State** | `{Feature}State` | `AuthState`, `ChatState` |

---

## 7.4. Testing Strategy

The architecture is designed to make testing easier. Use the Test Pyramid as your guide.

```mermaid
graph TB
    subgraph TestPyramid["🔺 Test Pyramid"]
        Unit["⬢ Unit Tests<br/>(Executors)"]
        Integration["⬡ Integration Tests<br/>(Orchestrators)"]
        E2E["△ E2E Tests<br/>(Full flows)"]
    end
    
    Unit --> Fast["Fast, Many"]
    Integration --> Medium["Medium, Moderate"]
    E2E --> Slow["Slow, Few"]
```

### Testing an Executor (Unit Test)

Executors are pure Dart classes. They take a Job input and emit Events. They are the easiest to test.

```mermaid
flowchart LR
    subgraph ExecutorTest["Testing Executor"]
        Input["Mock Input"]
        Exec["Executor"]
        Output["Verify Output"]
    end
    
    Input --> Exec
    Exec --> Output
    
    Note["✅ No UI, No State, No BuildContext<br/>Pure function: input → output"]
```

### Testing an Orchestrator (Integration Test)

Orchestrators need a simulated environment (BlocTest) to verify state changes given specific events.

```mermaid
flowchart LR
    subgraph OrchestratorTest["Testing Orchestrator"]
        MockBus["Mock Bus"]
        Orch["Orchestrator"]
        States["Verify State Transitions"]
    end
    
    MockBus --> Orch
    Orch --> States
    
    Note["✅ Inject mock events via the Bus<br/>Verify correct state emission"]
```

---

## 7.5. Dependency Injection

We rely on DI to wire everything up.

```mermaid
graph TB
    subgraph DI["💉 Dependency Injection"]
        GetIt["get_it / Injectable"]
        Riverpod["riverpod"]
        Manual["Manual Factory"]
    end
    
    subgraph Registration["Registration"]
        Exec["Executors (Singleton)"]
        Disp["Dispatcher (Singleton)"]
        Bus["SignalBus (Singleton/Scoped)"]
        Orch["Orchestrators (Factory/Provider)"]
    end
    
    DI --> Registration
```

### Registration Order

Order matters. You can't register an Orchestrator before the Dispatcher it depends on.

```mermaid
sequenceDiagram
    participant App as 🚀 App Start
    participant DI as 💉 DI Container
    participant Disp as 📮 Dispatcher
    
    App->>DI: 1. Register SignalBus
    App->>DI: 2. Register Executors
    App->>DI: 3. Register Dispatcher
    
    DI->>Disp: dispatcher.register<FetchUserJob>(UserExecutor())
    DI->>Disp: dispatcher.register<LoginJob>(AuthExecutor())
    
    Note over App: 4. Register Orchestrators<br/>(Factory/Provider)
```

---

## 7.6. Error Handling Strategy

Errors happen. Your app should handle them gracefully.

```mermaid
flowchart TD
    Error["Error Occurs"] --> Type{"Error Type?"}
    
    Type -->|"Transient (Network)"| Retry["Retry with backoff"]
    Type -->|"Business (Logic)"| UserMessage["Show user message"]
    Type -->|"System (Crash)"| Log["Log & Report"]
    
    Retry --> Success{"Success?"}
    Success -->|"YES"| Continue["Continue"]
    Success -->|"NO"| Escalate["Escalate to user"]
    
    UserMessage --> Dismiss["User dismisses"]
    Log --> Monitor["Monitor alerts"]
```

| Category | Examples | Handling Strategy |
|----------|----------|-------------------|
| **Transient** | Connection timeout, 503 Service Unavailable | **Auto-retry** silently. Do not bother the user yet. |
| **Business** | Invalid email, 401 Unauthorized, Insufficient funds | **Show User**. Display a friendly error message or redirect (e.g., to login). |
| **System** | NullPointerException, FormatException on parse | **Log & Report**. These are bugs. Send to Sentry/Firebase. |

---

## 7.7. Performance Guidelines

```mermaid
graph LR
    subgraph Performance["⚡ Performance Tips"]
        Dedup["Deduplicate requests"]
        Cache["Cache responses"]
        Stream["Stream large data"]
        Lazy["Lazy load executors"]
    end
```

### Common Optimizations

| Optimization | Use Case | Mechanism |
|--------------|----------|-----------|
| **Deduplication** | User mashes the "Refresh" button. | Check `activeJobs` before dispatching. If running, ignore. |
| **Caching** | Static data (e.g., Countries list). | Check local DB/Memory before dispatching network job. |
| **Streaming** | Large lists or files. | Emit `ProgressEvent` or partial `DataEvent` instead of waiting for everything. |
| **Lazy Registration** | startup time is slow. | Use `GetIt` lazy singletons for Executors so they instantiate only when used. |

---

## 7.8. AI Agent Integration

This architecture is **AI-friendly**. Because rules are strict, AI agents (Cursor, Copilot) can generate very high-quality code if you give them the right prompt.

```mermaid
graph TB
    subgraph AIPrompt["🤖 AI Agent Prompt"]
        Context["Describe Architecture"]
        Rules["List Coding Rules"]
        Examples["Provide Examples"]
    end
```

### Sample System Prompt

Copy this into your AI assistant:

```
You are an expert Flutter Developer using the Event-Driven Orchestrator Architecture.

CORE RULES:
1. Orchestrator ONLY manages state, NEVER calls APIs directly.
2. Executor ONLY executes logic (API/DB), emits events to SignalBus.
3. Jobs are immutable commands, ALWAYS have a correlationId.
4. Use copyWith for all state updates. Do not mutate state.

PATTERNS:
- dispatch(Job) → fire-and-forget, never await.
- onActiveSuccess → handle results of jobs initiated by this orchestrator.
- onPassiveEvent → react to global system events.
```

---

## 7.9. Troubleshooting

Common issues and how to fix them.

```mermaid
flowchart TD
    Problem["🔍 Problem"] --> Symptom{"Symptom?"}
    
    Symptom -->|"Event not received"| Check1["Check correlationId match"]
    Symptom -->|"State not updating"| Check2["Check emit() called"]
    Symptom -->|"Memory leak"| Check3["Check dispose() called"]
    Symptom -->|"Infinite loop"| Check4["Check dispatch in handler"]
    
    Check1 --> Fix1["Ensure executor includes job.id in event"]
    Check2 --> Fix2["Ensure copyWith creates NEW object"]
    Check3 --> Fix3["Call orchestrator.dispose()/close()"]
    Check4 --> Fix4["Add state check before dispatching"]
```

---

## Summary

```mermaid
mindmap
  root((Guidelines))
    Structure
      Feature-first folders
      Consistent naming
      Clear separation
    Testing
      Unit test executors
      Integration test orchestrators
      Minimize E2E tests
    Operations
      Handle all errors
      Log appropriately
      Monitor circuit breakers
    Performance
      Deduplicate
      Cache
      Stream
```

**Final Takeaway**: The Flutter Orchestrator architecture provides the guardrails (rules, patterns, structure). But the safety and speed of the car depend on the driver (you) following the road signs (best practices).
