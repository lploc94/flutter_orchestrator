# Chapter 6: Case Studies

> *"In theory, there is no difference between theory and practice. In practice, there is."* — Yogi Berra

This chapter moves away from abstract patterns and dives into detailed, real-world scenarios. We will explore how to combine multiple patterns to solve complex business requirements.

---

## 6.1. Case Study: AI Chatbot

Building an AI Chatbot involves several complex challenges: the operations are long-running (LLM latency), the data comes in streams (token by token), and the process involves multiple distinct steps (retrieve context -> generate answer -> save history).

### System Overview

We model the system using three distinct Executors, orchestrated by a single `ChatOrchestrator`.

```mermaid
graph TB
    subgraph UI["🖥️ Chat UI"]
        Input["Message Input"]
        Messages["Message List"]
        Typing["Typing Indicator"]
    end
    
    subgraph Orchestrator["🎭 Chat Orchestrator"]
        State["Chat State"]
        ActiveJobs["Active Jobs"]
    end
    
    subgraph Executors["⚙️ Executors"]
        Context["Context Executor<br/>(RAG)"]
        AI["AI Executor<br/>(LLM)"]
        Save["Save Executor<br/>(Persistence)"]
    end
    
    UI --> Orchestrator
    Orchestrator --> Context
    Context -->|"Context Ready"| AI
    AI -->|"AI Response"| Save
    Save -->|"Saved"| Orchestrator
    Orchestrator --> UI
    
    style UI fill:#f1f5f9,stroke:#334155,color:#1e293b
    style Orchestrator fill:#e0f2f1,stroke:#334155,color:#1e293b
    style Executors fill:#fef3c7,stroke:#334155,color:#1e293b
    style Input fill:#f1f5f9,stroke:#334155,color:#1e293b
    style Messages fill:#f1f5f9,stroke:#334155,color:#1e293b
    style Typing fill:#f1f5f9,stroke:#334155,color:#1e293b
    style State fill:#e0f2f1,stroke:#334155,color:#1e293b
    style ActiveJobs fill:#e0f2f1,stroke:#334155,color:#1e293b
    style Context fill:#fef3c7,stroke:#334155,color:#1e293b
    style AI fill:#fef3c7,stroke:#334155,color:#1e293b
    style Save fill:#fef3c7,stroke:#334155,color:#1e293b
```

### The Flow

The message flow is broken down into three phases. Notice how the Orchestrator remains the central coordinator, dispatching new jobs as previous ones complete.

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'primaryTextColor': '#1e293b', 'noteTextColor': '#1e293b', 'actorTextColor': '#1e293b' }}}%%
sequenceDiagram
    participant User as 👤 User
    participant Chat as 🎭 ChatOrchestrator
    participant RAG as 📚 ContextExecutor
    participant LLM as 🤖 AIExecutor
    participant DB as 💾 SaveExecutor
    
    User->>Chat: sendMessage("What is...")
    
    rect rgb(241, 245, 249)
        Note over Chat: Phase 1: Context Retrieval
        Chat->>RAG: dispatch(GetContextJob)
        RAG-->>Chat: ContextReadyEvent
    end
    
    rect rgb(224, 242, 241)
        Note over Chat: Phase 2: AI Generation
        Chat->>LLM: dispatch(GenerateResponseJob)
        loop Streaming
            LLM-->>Chat: ProgressEvent(token)
            Note right of Chat: Update UI immediately
        end
        LLM-->>Chat: AIResponseEvent
    end
    
    rect rgb(254, 243, 199)
        Note over Chat: Phase 3: Persistence
        Chat->>DB: dispatch(SaveMessageJob)
        DB-->>Chat: SavedEvent
    end
    
    Chat-->>User: Final State Updated
```

### Chained Jobs Pattern

Instead of a monolithic function, we handle the workflow as a state machine. This allows us to handle errors specifically for each phase (e.g., if Saving fails, we don't lose the AI response, we just show a "Retry Save" button, because the AI response is already in memory).

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'primaryColor': '#e0f2f1', 'primaryTextColor': '#1e293b', 'primaryBorderColor': '#334155', 'lineColor': '#334155', 'secondaryColor': '#fef3c7', 'tertiaryColor': '#fee2e2' }}}%%
stateDiagram-v2
    [*] --> Idle
    
    Idle --> GettingContext: sendMessage()
    GettingContext --> Generating: onContextReady
    Generating --> Generating: onProgress (streaming)
    Generating --> Saving: onAIResponse
    Saving --> Idle: onSaved
    
    GettingContext --> Error: onFailure
    Generating --> Error: onFailure
    Saving --> Error: onFailure
```

### Key Decisions

| Decision | Rationale |
|----------|-----------|
| **Separate RAG Executor** | The context retrieval logic (vector DB lookup) is complex and might be used by other features (e.g., "Related Articles"). Separating it makes it reusable. |
| **Streaming via Progress** | We re-purpose the `ProgressEvent` to carry partial string data (tokens). This gives instant feedback to the user. |
| **Save after AI complete** | We only persist the message once the full response is available to ensure database consistency. |

---

## 6.2. Case Study: File Upload

File upload is a classic "long-running operation" that requires careful handling of network instability and user interaction (cancellation).

### The Flow

Here, we use a `CancellationToken` to allow the user to interrupt the process. The Executor checks this token before every chunk upload.

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'primaryTextColor': '#1e293b', 'noteTextColor': '#1e293b', 'actorTextColor': '#1e293b' }}}%%
sequenceDiagram
    participant User as 👤 User
    participant UI as 🖥️ Upload UI
    participant Orch as 🎭 Orchestrator
    participant Exec as ⚙️ UploadExecutor
    participant S3 as ☁️ Cloud Storage
    
    rect rgb(241, 245, 249)
        User->>UI: Select file
        UI->>Orch: startUpload(file)
        Orch->>Orch: token = new CancellationToken()
        Orch->>Exec: dispatch(UploadJob, token)
    end
    
    rect rgb(224, 242, 241)
        loop Chunks
            Exec->>S3: Upload chunk
            Exec-->>Orch: Progress(30%)
            Exec->>S3: Upload chunk
            Exec-->>Orch: Progress(60%)
            
            alt User cancels
                User->>Orch: cancel()
                Orch->>Token: cancel()
                Exec->>Exec: throw CancelledException
                Exec-->>Orch: CancelledEvent
            end
        end
    end
    
    rect rgb(254, 243, 199)
        Exec->>S3: Complete multipart
        Exec-->>Orch: SuccessEvent(url)
        Orch-->>UI: Upload complete
    end
```

### Chunked Upload State

The state object needs to track detailed progress, not just "loading".

```mermaid
graph LR
    subgraph UploadState["📤 Upload State"]
        File["file: File"]
        Progress["progress: 0.65"]
        Status["status: uploading"]
        URL["url: null"]
        ChunksDone["chunksComplete: 6/10"]
    end
    
    style UploadState fill:#e0f2f1,stroke:#334155,color:#1e293b
    style File fill:#f1f5f9,stroke:#334155,color:#1e293b
    style Progress fill:#f1f5f9,stroke:#334155,color:#1e293b
    style Status fill:#f1f5f9,stroke:#334155,color:#1e293b
    style URL fill:#f1f5f9,stroke:#334155,color:#1e293b
    style ChunksDone fill:#f1f5f9,stroke:#334155,color:#1e293b
```

### Retry Strategy

Not all errors are equal. We implement smart retry logic inside the Executor:
- **Transient Errors** (Network timeout, 502 Bad Gateway): Retry with exponential backoff.
- **Permanent Errors** (401 Unauthorized, 413 Payload Too Large): Fail immediately.

```mermaid
flowchart TD
    Upload["Upload Chunk"] --> Success{"Success?"}
    Success -->|"YES"| Next["Next Chunk"]
    Success -->|"NO"| Transient{"Transient Error?"}
    
    Transient -->|"YES (5xx, timeout)"| Retry["Retry with backoff"]
    Transient -->|"NO (4xx)"| Fail["Fail immediately"]
    
    Retry --> Attempts{"Attempts < 3?"}
    Attempts -->|"YES"| Upload
    Attempts -->|"NO"| Fail
    
    style Upload fill:#f1f5f9,stroke:#334155,color:#1e293b
    style Success fill:#e0f2f1,stroke:#334155,color:#1e293b
    style Next fill:#fef3c7,stroke:#334155,color:#1e293b
    style Transient fill:#e0f2f1,stroke:#334155,color:#1e293b
    style Retry fill:#e0f2f1,stroke:#334155,color:#1e293b
    style Attempts fill:#e0f2f1,stroke:#334155,color:#1e293b
    style Fail fill:#fee2e2,stroke:#334155,color:#1e293b
```

---

## 6.3. Case Study: Shopping Cart

The Shopping Cart feature introduces cross-module communication. When a user adds an item to the cart, the "Product Detail" screen (which might be active in the background) needs to know about it to update its stock level display.

### System Architecture

We use a **Global Bus** to broadcast events that interest multiple modules.

```mermaid
graph TB
    subgraph ProductModule["📦 Product Module"]
        ProductOrch["Product Orchestrator"]
        ProductExec["Product Executor"]
    end
    
    subgraph CartModule["🛒 Cart Module"]
        CartOrch["Cart Orchestrator"]
        CartExec["Cart Executor"]
    end
    
    subgraph GlobalBus["📡 Global Bus"]
        Events["CartUpdatedEvent<br/>StockChangedEvent"]
    end
    
    ProductExec --> GlobalBus
    CartExec --> GlobalBus
    GlobalBus --> ProductOrch
    GlobalBus --> CartOrch
    
    Note["💡 Both orchestrators observe<br/>each other's events"]
    
    style ProductModule fill:#e0f2f1,stroke:#334155,color:#1e293b
    style CartModule fill:#fef3c7,stroke:#334155,color:#1e293b
    style GlobalBus fill:#0d9488,stroke:#334155,color:#ffffff
    style ProductOrch fill:#e0f2f1,stroke:#334155,color:#1e293b
    style ProductExec fill:#e0f2f1,stroke:#334155,color:#1e293b
    style CartOrch fill:#fef3c7,stroke:#334155,color:#1e293b
    style CartExec fill:#fef3c7,stroke:#334155,color:#1e293b
    style Events fill:#0d9488,stroke:#334155,color:#ffffff
    style Note fill:#f1f5f9,stroke:#334155,color:#1e293b
```

### Observer Mode Example

This sequence shows how `ProductOrchestrator` passively updates itself based on an action triggered by `CartOrchestrator`.

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'primaryTextColor': '#1e293b', 'noteTextColor': '#1e293b', 'actorTextColor': '#1e293b' }}}%%
sequenceDiagram
    participant Cart as 🛒 CartOrchestrator
    participant Product as 📦 ProductOrchestrator
    participant Bus as 📡 Global Bus
    participant Exec as ⚙️ CartExecutor
    
    rect rgb(241, 245, 249)
        Note over Cart: User adds item
        Cart->>Exec: dispatch(AddToCartJob)
    end
    
    rect rgb(224, 242, 241)
        Exec->>Bus: CartUpdatedEvent
    end
    
    rect rgb(254, 243, 199)
        Bus->>Cart: event (Direct Mode)
        Note over Cart: Update cart state
        
        Bus->>Product: event (Observer Mode)
        Note over Product: Update product stock display
    end
```

### Optimistic Update Pattern

For a snappy feel, we assume success. We update the UI *before* the network request returns. If it fails, we rollback.

```mermaid
flowchart TD
    Start["User clicks Add to Cart"]
    
    Start --> Optimistic["Immediately update state<br/>(optimistic)"]
    Optimistic --> Dispatch["dispatch(AddToCartJob)"]
    
    Dispatch --> Result{"Result?"}
    
    Result -->|"Success"| Confirm["Keep optimistic state"]
    Result -->|"Failure"| Rollback["Revert to previous state<br/>Show error"]
    
    style Start fill:#f1f5f9,stroke:#334155,color:#1e293b
    style Optimistic fill:#fef3c7,stroke:#334155,color:#1e293b
    style Dispatch fill:#e0f2f1,stroke:#334155,color:#1e293b
    style Result fill:#e0f2f1,stroke:#334155,color:#1e293b
    style Confirm fill:#fef3c7,stroke:#334155,color:#1e293b
    style Rollback fill:#fee2e2,stroke:#334155,color:#1e293b
```

---

## 6.4. Case Study: Authentication

Authentication is special because it affects the entire app (Global State) but requires high security.

### Architecture

We use a **Scoped Bus** for internal auth logic (like token parsing) to prevent other modules from spying on sensitive events, but expose high-level `UserLoggedIn` events to the Global Bus.

```mermaid
graph TB
    subgraph AuthModule["🔐 Auth Module"]
        AuthBus["Scoped Bus"]
        AuthOrch["Auth Orchestrator"]
        AuthExec["Auth Executor"]
        
        AuthOrch <-.-> AuthBus
        AuthExec --> AuthBus
    end
    
    subgraph OtherModules["📱 Other Modules"]
        Home["Home Orchestrator"]
        Profile["Profile Orchestrator"]
        Settings["Settings Orchestrator"]
    end
    
    subgraph GlobalBus["🌍 Global Bus"]
        Public["UserLoggedInEvent<br/>UserLoggedOutEvent"]
    end
    
    AuthExec -->|"Public events"| GlobalBus
    GlobalBus --> OtherModules
    
    Note["🔒 Internal auth state (tokens) stays private<br/>Only login/logout status is public"]
    
    style AuthModule fill:#e0f2f1,stroke:#334155,color:#1e293b
    style OtherModules fill:#fef3c7,stroke:#334155,color:#1e293b
    style GlobalBus fill:#0d9488,stroke:#334155,color:#ffffff
    style AuthBus fill:#f1f5f9,stroke:#334155,color:#1e293b
    style AuthOrch fill:#e0f2f1,stroke:#334155,color:#1e293b
    style AuthExec fill:#e0f2f1,stroke:#334155,color:#1e293b
    style Home fill:#fef3c7,stroke:#334155,color:#1e293b
    style Profile fill:#fef3c7,stroke:#334155,color:#1e293b
    style Settings fill:#fef3c7,stroke:#334155,color:#1e293b
    style Public fill:#0d9488,stroke:#334155,color:#ffffff
    style Note fill:#f1f5f9,stroke:#334155,color:#1e293b
```

### Token Refresh Flow

This is a background process that happens transparently to the user. When any request fails with 401, the `AuthExecutor` intercepts, refreshes the token, and retries the original request.

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'primaryTextColor': '#1e293b', 'noteTextColor': '#1e293b', 'actorTextColor': '#1e293b' }}}%%
sequenceDiagram
    participant Any as 📱 Any Executor
    participant Auth as 🔐 AuthExecutor
    participant API as 🌐 API
    
    rect rgb(254, 226, 226)
        Any->>API: Request with token
        API-->>Any: 401 Unauthorized
    end
    
    rect rgb(224, 242, 241)
        Any->>Auth: dispatch(RefreshTokenJob)
        Auth->>API: POST /refresh
        API-->>Auth: New token
        Auth-->>Any: TokenRefreshedEvent
    end
    
    rect rgb(254, 243, 199)
        Any->>API: Retry request with new token
        API-->>Any: Success
    end
```

---

## 6.5. Lessons Learned

```mermaid
graph LR
    Root((Lessons))
    
    Root --> Sep["Separation"]
    Sep --> Sep1["Keep executors simple"]
    Sep --> Sep2["One job = one task"]
    Sep --> Sep3["Compose for complexity"]
    
    Root --> Com["Communication"]
    Com --> Com1["Use scoped bus for privacy"]
    Com --> Com2["Global bus for cross-module"]
    Com --> Com3["Always include correlationId"]
    
    Root --> Res["Resilience"]
    Res --> Res1["Always handle failures"]
    Res --> Res2["Implement retry for transient"]
    Res --> Res3["Give user cancel option"]
    
    Root --> Perf["Performance"]
    Perf --> Perf1["Deduplicate requests"]
    Perf --> Perf2["Cache where appropriate"]
    Perf --> Perf3["Stream for long tasks"]
    
    style Root fill:#0d9488,stroke:#334155,stroke-width:2px,color:#ffffff
    style Sep fill:#e0f2f1,stroke:#334155,color:#1e293b
    style Com fill:#fef3c7,stroke:#334155,color:#1e293b
    style Res fill:#fee2e2,stroke:#334155,color:#1e293b
    style Perf fill:#e0f2f1,stroke:#334155,color:#1e293b
    
    style Sep1 fill:#f1f5f9,stroke:#334155,color:#1e293b
    style Sep2 fill:#f1f5f9,stroke:#334155,color:#1e293b
    style Sep3 fill:#f1f5f9,stroke:#334155,color:#1e293b
    
    style Com1 fill:#f1f5f9,stroke:#334155,color:#1e293b
    style Com2 fill:#f1f5f9,stroke:#334155,color:#1e293b
    style Com3 fill:#f1f5f9,stroke:#334155,color:#1e293b
    
    style Res1 fill:#f1f5f9,stroke:#334155,color:#1e293b
    style Res2 fill:#f1f5f9,stroke:#334155,color:#1e293b
    style Res3 fill:#f1f5f9,stroke:#334155,color:#1e293b
    
    style Perf1 fill:#f1f5f9,stroke:#334155,color:#1e293b
    style Perf2 fill:#f1f5f9,stroke:#334155,color:#1e293b
    style Perf3 fill:#f1f5f9,stroke:#334155,color:#1e293b
```

---

## Summary

| Case Study | Key Patterns Used |
|------------|-------------------|
| **AI Chatbot** | **Chaining**: Linking tasks sequentially. **Streaming**: Real-time feedback. |
| **File Upload** | **Cancellation**: Putting user in control. **Retry**: Handling network bumps. |
| **Shopping Cart** | **Observer Mode**: Reacting to others. **Optimistic Update**: Instant feedback. |
| **Authentication** | **Scoped Bus**: Encapsulation. **Interceptor**: Transparent recovery. |

**Key Takeaway**: Real production applications are rarely simple linear flows. They require robust error handling, cross-module communication, and user-centric features like cancellation and optimistic updates. This architecture provides standard patterns for all of these.
