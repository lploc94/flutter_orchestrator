# Chương 3: Chi tiết Thành phần (The Component Details)

> *"Đơn giản là đỉnh cao của sự tinh tế."* — Leonardo da Vinci

Chương này đi sâu vào cấu trúc bên trong và hành vi của từng thành phần, sử dụng biểu đồ để giải thích cơ chế hoạt động.

---

## 3.1. Job

Job là một **yêu cầu thực hiện công việc** — một data object bất biến mô tả những gì cần làm.

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

### Các thuộc tính của Job

| Thuộc tính | Mục đích |
|------------|----------|
| `id` | Correlation ID để theo dõi |
| `metadata` | Dữ liệu ngữ cảnh tùy chọn |
| `cancellationToken` | Hỗ trợ hủy chủ động |
| `timeout` | Thời gian thực thi tối đa |
| `retryPolicy` | Cấu hình tự động thử lại |

---

## 3.2. Event

Event là **thông báo về những gì đã xảy ra** — kết quả của việc thực thi job.

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

### Các loại Event

| Loại Event | Khi nào emit |
|------------|--------------|
| `JobSuccessEvent` | Job hoàn thành thành công |
| `JobFailureEvent` | Job gặp lỗi |
| `JobProgressEvent` | Job đang chạy và báo tiến độ |
| `JobTimeoutEvent` | Job vượt quá thời gian giới hạn |
| `JobRetryingEvent` | Job đang được thử lại |

---

## 3.3. Dispatcher (Routing)

Dispatcher duy trì một sổ đăng ký (registry) ánh xạ các loại Job tới các Executor.

```mermaid
graph LR
    subgraph Registry["📮 Dispatcher Registry"]
        R1["FetchUserJob → UserExecutor"]
        R2["LoginJob → AuthExecutor"]
        R3["UploadJob → UploadExecutor"]
    end
    
    Job["Incoming Job"] --> Lookup{"Type Lookup<br/>O(1)"}
    Lookup --> Executor["Executor phù hợp"]
    
    style Registry fill:#e0f2f1,stroke:#334155,color:#1e293b
    style R1 fill:#f1f5f9,stroke:#334155,color:#1e293b
    style R2 fill:#f1f5f9,stroke:#334155,color:#1e293b
    style R3 fill:#f1f5f9,stroke:#334155,color:#1e293b
    style Job fill:#f1f5f9,stroke:#334155,color:#1e293b
    style Lookup fill:#e0f2f1,stroke:#334155,color:#1e293b
    style Executor fill:#fef3c7,stroke:#334155,color:#1e293b
```

### Luồng đăng ký

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'primaryTextColor': '#1e293b', 'noteTextColor': '#1e293b', 'actorTextColor': '#1e293b' }}}%%
sequenceDiagram
    participant App as 🚀 App Startup
    participant Disp as 📮 Dispatcher
    participant Exec as ⚙️ Executor
    
    App->>Disp: register<FetchUserJob>(UserExecutor())
    App->>Disp: register<LoginJob>(AuthExecutor())
    
    Note over Disp: Registry đã sẵn sàng
    
    App->>Disp: dispatch(FetchUserJob(...))
    Disp->>Exec: execute(job)
```

---

## 3.4. Executor (Processing)

Executor là **công nhân không trạng thái (stateless worker)** được tích hợp sẵn xử lý lỗi.

```mermaid
flowchart TB
    subgraph Executor["⚙️ Executor"]
        Start["execute(job)"] --> CheckCancel{"Cancelled?"}
        CheckCancel -->|"YES"| Cancelled["❌ CancelledException"]
        CheckCancel -->|"NO"| Process["process(job)"]
        Process --> Success{"Thành công?"}
        Success -->|"YES"| EmitSuccess["emit(SuccessEvent)"]
        Success -->|"ERROR"| CheckRetry{"Retry được không?"}
        CheckRetry -->|"YES"| Wait["Chờ (backoff)"]
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

### Error Boundary (Rào chắn lỗi)

Mọi Executor đều có cơ chế bắt lỗi tự động:

```mermaid
graph TB
    subgraph ErrorBoundary["🛡️ Error Boundary"]
        Try["try { process(job) }"]
        Catch["catch (error) { emitFailure() }"]
    end
    
    Try -->|"Exception"| Catch
    
    Note["✅ Exception KHÔNG BAO GIỜ lọt ra ngoài<br/>Luôn được chuyển thành Event"]
    
    style ErrorBoundary fill:#e0f2f1,stroke:#334155,color:#1e293b
    style Try fill:#f1f5f9,stroke:#334155,color:#1e293b
    style Catch fill:#fee2e2,stroke:#334155,color:#1e293b
    style Note fill:#fef3c7,stroke:#334155,color:#1e293b
```

---

## 3.5. Orchestrator (Máy trạng thái)

Orchestrator là **người điều phối có trạng thái (stateful coordinator)** quản lý UI state và theo dõi job.

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

### Cấu trúc bên trong

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

### Logic định tuyến Event

```mermaid
flowchart TD
    Event["📨 Event Received"] --> Extract["Lấy correlationId"]
    Extract --> Check{"correlationId ∈ activeJobIds?"}
    
    Check -->|"YES"| Direct["🎯 Direct Mode"]
    Check -->|"NO"| Observer["👀 Observer Mode"]
    
    Direct --> Remove["Xóa khỏi activeJobIds"]
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

## 3.6. Signal Bus (Broadcasting)

Signal Bus là cơ chế **publish-subscribe** để phân phối sự kiện.

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
        GB["Mọi sự kiện đều thấy được<br/>bởi mọi orchestrator"]
    end
    
    subgraph ScopedBus["🔒 Scoped Bus"]
        SB1["Auth Module Bus"]
        SB2["Chat Module Bus"]
        SB3["Cart Module Bus"]
    end
    
    GlobalBus -.->|"Dùng cho"| Public["Public Events<br/>(UserLoggedIn, ThemeChanged)"]
    ScopedBus -.->|"Dùng cho"| Private["Private Events<br/>(Thay đổi state nội bộ)"]
    
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

## 3.7. Luồng hệ thống hoàn chỉnh

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
        Note over UI,Orch: 1. Hành động người dùng
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
        Note over Exec,API: 3. Thực thi
        Exec->>+API: GET /users/123
        API-->>-Exec: User data
    end
    
    rect rgb(254, 243, 199)
        Note over Exec,Orch: 4. Broadcast Event
        Exec->>-Bus: emit(SuccessEvent)
        Bus->>Orch: Event(correlationId=id)
    end
    
    rect rgb(224, 242, 241)
        Note over Orch,UI: 5. Cập nhật State
        Orch->>Orch: onActiveSuccess()
        Orch->>Orch: emit(Success)
        Orch-->>-UI: State mới
    end
```

---

## Tổng kết

```mermaid
graph LR
    Root((Kiến trúc))
    
    Root --> Job["Job"]
    Job --> J1["Yêu cầu công việc"]
    Job --> J2["Dữ liệu bất biến"]
    Job --> J3["Mang correlationId"]
    
    Root --> Event["Event"]
    Event --> E1["Thông báo kết quả"]
    Event --> E2["Success/Failure/Progress"]
    Event --> E3["Broadcast cho tất cả"]
    
    Root --> Disp["Dispatcher"]
    Disp --> D1["Định tuyến Job đến Executor"]
    Disp --> D2["Registry pattern"]
    Disp --> D3["Tra cứu O(1)"]
    
    Root --> Exec["Executor"]
    Exec --> Ex1["Công nhân không trạng thái"]
    Exec --> Ex2["Error boundary"]
    Exec --> Ex3["Emits events"]
    
    Root --> Orch["Orchestrator"]
    Orch --> O1["Điều phối viên trạng thái"]
    Orch --> O2["Theo dõi active jobs"]
    Orch --> O3["Direct + Observer modes"]
    
    Root --> Bus["Signal Bus"]
    Bus --> B1["Cơ chế Pub/Sub"]
    Bus --> B2["Global hoặc Scoped"]
    Bus --> B3["Giao tiếp lỏng lẻo"]
    
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

**Bài học chính**: Mỗi thành phần có một trách nhiệm duy nhất, được kết nối thông qua các giao diện rõ ràng. Điều này làm cho hệ thống dễ kiểm thử, dễ bảo trì và dễ mở rộng.
