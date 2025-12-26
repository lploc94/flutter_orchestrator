# Chapter 6: Case Studies

> *"In theory, there is no difference between theory and practice. In practice, there is."* — Yogi Berra

This chapter applies the architecture to real-world scenarios.

---

## 6.1. Case Study: AI Chatbot

An AI chatbot demonstrates multiple patterns working together:
- Long-running execution
- Streaming responses
- Multi-step processing
- Cross-cutting concerns (analytics, logging)

### System Overview

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

```mermaid
sequenceDiagram
    participant User as 👤 User
    participant Chat as 🎭 ChatOrchestrator
    participant RAG as 📚 ContextExecutor
    participant LLM as 🤖 AIExecutor
    participant DB as 💾 SaveExecutor
    
    User->>Chat: sendMessage("What is...")
    
    rect rgb(240, 247, 255)
        Note over Chat: Phase 1: Context
        Chat->>RAG: dispatch(GetContextJob)
        RAG-->>Chat: ContextReadyEvent
    end
    
    rect rgb(240, 255, 240)
        Note over Chat: Phase 2: AI Response
        Chat->>LLM: dispatch(GenerateResponseJob)
        loop Streaming
            LLM-->>Chat: ProgressEvent(token)
        end
        LLM-->>Chat: AIResponseEvent
    end
    
    rect rgb(255, 250, 240)
        Note over Chat: Phase 3: Persist
        Chat->>DB: dispatch(SaveMessageJob)
        DB-->>Chat: SavedEvent
    end
    
    Chat-->>User: Updated State
```

### Chained Jobs Pattern

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
| **Separate RAG executor** | Can be reused, tested independently |
| **Streaming via Progress** | User sees tokens as they arrive |
| **Save after AI complete** | Ensures complete response is persisted |

---

## 6.2. Case Study: File Upload

File upload demonstrates:
- Progress reporting
- Cancellation
- Retry on failure
- Large file handling

### The Flow

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

Shopping cart demonstrates:
- Observer mode for cross-module updates
- Optimistic updates
- Conflict resolution

### System Architecture

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
```

### Observer Mode Example

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

Authentication demonstrates:
- Scoped bus for security
- Global events for cross-app notification
- Token refresh handling

### Architecture

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
    
    Note["🔒 Internal auth state stays private<br/>Only login/logout events are public"]
```

### Token Refresh Flow

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
| **AI Chatbot** | Chaining, Progress, Streaming |
| **File Upload** | Cancellation, Retry, Progress |
| **Shopping Cart** | Observer Mode, Optimistic Update |
| **Authentication** | Scoped Bus, Token Refresh |

**Key Takeaway**: Real applications combine multiple patterns. The architecture's strength is how patterns compose together cleanly.
