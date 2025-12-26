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
```

### The Flow

The message flow is broken down into three phases. Notice how the Orchestrator remains the central coordinator, dispatching new jobs as previous ones complete.

```mermaid
sequenceDiagram
    participant User as 👤 User
    participant Chat as 🎭 ChatOrchestrator
    participant RAG as 📚 ContextExecutor
    participant LLM as 🤖 AIExecutor
    participant DB as 💾 SaveExecutor
    
    User->>Chat: sendMessage("What is...")
    
    rect rgb(240, 247, 255)
        Note over Chat: Phase 1: Context Retrieval
        Chat->>RAG: dispatch(GetContextJob)
        RAG-->>Chat: ContextReadyEvent
    end
    
    rect rgb(240, 255, 240)
        Note over Chat: Phase 2: AI Generation
        Chat->>LLM: dispatch(GenerateResponseJob)
        loop Streaming
            LLM-->>Chat: ProgressEvent(token)
            Note right of Chat: Update UI immediately
        end
        LLM-->>Chat: AIResponseEvent
    end
    
    rect rgb(255, 250, 240)
        Note over Chat: Phase 3: Persistence
        Chat->>DB: dispatch(SaveMessageJob)
        DB-->>Chat: SavedEvent
    end
    
    Chat-->>User: Final State Updated
```

### Chained Jobs Pattern

Instead of a monolithic function, we handle the workflow as a state machine. This allows us to handle errors specifically for each phase (e.g., if Saving fails, we don't lose the AI response, we just show a "Retry Save" button, because the AI response is already in memory).

```mermaid
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
sequenceDiagram
    participant User as 👤 User
    participant UI as 🖥️ Upload UI
    participant Orch as 🎭 Orchestrator
    participant Exec as ⚙️ UploadExecutor
    participant S3 as ☁️ Cloud Storage
    
    User->>UI: Select file
    UI->>Orch: startUpload(file)
    Orch->>Orch: token = new CancellationToken()
    Orch->>Exec: dispatch(UploadJob, token)
    
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
    
    Exec->>S3: Complete multipart
    Exec-->>Orch: SuccessEvent(url)
    Orch-->>UI: Upload complete
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
    
    Note["💡 Cả hai orchestrator quan sát<br/>sự kiện của nhau"]
```

### Observer Mode Example

This sequence shows how `ProductOrchestrator` passively updates itself based on an action triggered by `CartOrchestrator`.

```mermaid
sequenceDiagram
    participant Cart as 🛒 CartOrchestrator
    participant Product as 📦 ProductOrchestrator
    participant Bus as 📡 Global Bus
    participant Exec as ⚙️ CartExecutor
    
    Note over Cart: User adds item
    Cart->>Exec: dispatch(AddToCartJob)
    Exec->>Bus: CartUpdatedEvent
    
    Bus->>Cart: event (Direct Mode)
    Note over Cart: Update cart state
    
    Bus->>Product: event (Observer Mode)
    Note over Product: Update product stock display
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
    
    style Optimistic fill:#37b24d,color:#fff
    style Rollback fill:#f03e3e,color:#fff
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
```

### Token Refresh Flow

This is a background process that happens transparently to the user. When any request fails with 401, the `AuthExecutor` intercepts, refreshes the token, and retries the original request.

```mermaid
sequenceDiagram
    participant Any as 📱 Any Executor
    participant Auth as 🔐 AuthExecutor
    participant API as 🌐 API
    
    Any->>API: Request with token
    API-->>Any: 401 Unauthorized
    
    Any->>Auth: dispatch(RefreshTokenJob)
    Auth->>API: POST /refresh
    API-->>Auth: New token
    Auth-->>Any: TokenRefreshedEvent
    
    Any->>API: Retry request with new token
    API-->>Any: Success
```

---

## 6.5. Lessons Learned

```mermaid
mindmap
  root((Lessons))
    Separation
      Keep executors simple
      One job = one task
      Compose for complexity
    Communication
      Use scoped bus for privacy
      Global bus for cross-module
      Always include correlationId
    Resilience
      Always handle failures
      Implement retry for transient
      Give user cancel option
    Performance
      Deduplicate requests
      Cache where appropriate
      Stream for long tasks
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
