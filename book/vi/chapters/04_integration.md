# Chương 4: Các mẫu cốt lõi (Core Patterns)

> *"Một pattern (mẫu) là giải pháp cho một vấn đề trong một ngữ cảnh cụ thể."* — Christopher Alexander

Chương này mô tả các pattern nền tảng giúp kiến trúc hoạt động trơn tru.

---

## 4.1. Mẫu Job-Executor

**Vấn đề**: Làm thế nào để tách biệt "việc cần làm" khỏi "cách làm việc đó"?

**Giải pháp**: Tách yêu cầu (Job) khỏi bộ xử lý (Executor).

```mermaid
graph LR
    subgraph Pattern["Job-Executor Pattern"]
        Job["📋 Job<br/>(Cái gì)"] --> Executor["⚙️ Executor<br/>(Như thế nào)"]
        Executor --> Event["📨 Event<br/>(Kết quả)"]
    end
    
    style Job fill:#4c6ef5,color:#fff
    style Executor fill:#37b24d,color:#fff
    style Event fill:#f59f00,color:#fff
```

### Cấu trúc

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

### Lợi ích

| Lợi ích | Mô tả |
|---------|-------|
| **Testability** | Test Executor không cần UI |
| **Reusability** | Một Executor có thể được dùng bởi nhiều nơi |
| **Single Responsibility** | Mỗi Executor chỉ làm một việc |

---

## 4.2. Mẫu Định tuyến Sự kiện (Event Routing Pattern)

**Vấn đề**: Làm sao để đúng Orchestrator nhận được đúng Event?

**Giải pháp**: Sử dụng Correlation ID để khớp sự kiện với nguồn phát sinh.

```mermaid
sequenceDiagram
    participant OrcA as Orchestrator A
    participant OrcB as Orchestrator B
    participant Bus as Signal Bus
    
    Note over OrcA: activeJobs = [job-001]
    Note over OrcB: activeJobs = [job-002]
    
    Bus->>OrcA: Event(id=job-001)
    Bus->>OrcB: Event(id=job-001)
    
    Note over OrcA: ✅ job-001 khớp activeJobs<br/>→ Direct Mode
    Note over OrcB: ❌ job-001 không phải của tôi<br/>→ Observer Mode
```

### Thuật toán định tuyến

```mermaid
flowchart TD
    Start["Nhận Event"] --> Extract["Lấy correlationId"]
    Extract --> Lookup["Tìm trong activeJobIds"]
    Lookup --> Found{"Tìm thấy?"}
    
    Found -->|"YES"| Direct["Xử lý Direct Mode"]
    Found -->|"NO"| PassiveCheck{"Quan tâm loại event này?"}
    
    PassiveCheck -->|"YES"| Observer["Xử lý Observer Mode"]
    PassiveCheck -->|"NO"| Ignore["Bỏ qua Event"]
    
    Direct --> Remove["Xóa khỏi activeJobIds"]
    
    style Direct fill:#4c6ef5,color:#fff
    style Observer fill:#37b24d,color:#fff
    style Ignore fill:#868e96,color:#fff
```

---

## 4.3. Mẫu Chuyển đổi Trạng thái (State Transition Pattern)

**Vấn đề**: Làm thế nào để quản lý UI state nhất quán qua các tác vụ bất đồng bộ?

**Giải pháp**: Định nghĩa rõ ràng các trạng thái và chuyển đổi được kích hoạt bởi sự kiện.

```mermaid
stateDiagram-v2
    [*] --> Idle: Ban đầu
    
    Idle --> Loading: dispatch(Job)
    
    Loading --> Success: onActiveSuccess
    Loading --> Error: onActiveFailure
    Loading --> Loading: onProgress
    
    Success --> Idle: reset()
    Success --> Loading: refresh()
    
    Error --> Idle: dismiss()
    Error --> Loading: retry()
```

### Phân loại State

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
    
    Note["Control = Hành vi UI<br/>Data = Nội dung nghiệp vụ"]
```

### Quy tắc

> **Control State** chỉ nên được sửa đổi bởi các sự kiện **Direct Mode**.
> **Data State** có thể được sửa đổi bởi cả Direct và Observer mode.

---

## 4.4. Mẫu Scoped Bus

**Vấn đề**: Làm sao để tránh rò rỉ sự kiện giữa các module?

**Giải pháp**: Tạo các bus cô lập cho các module độc lập.

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
    
    style AuthBus fill:#4c6ef5,color:#fff
    style ChatBus fill:#37b24d,color:#fff
    style GB fill:#f59f00,color:#fff
```

### Khi nào dùng loại nào

| Loại Bus | Use Case | Ví dụ |
|----------|----------|-------|
| **Scoped** | State nội bộ module | LoadingStarted, StepComplete |
| **Global** | Giao tiếp liên module | UserLoggedIn, ThemeChanged |

---

## 4.5. Mẫu Registry

**Vấn đề**: Làm sao định tuyến Job tới Executor hiệu quả?

**Giải pháp**: Duy trì một registry dựa theo Type với tốc độ tra cứu O(1).

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
    
    style Map fill:#f3f0ff
```

### Chiến lược đăng ký

```mermaid
flowchart LR
    subgraph Strategies["Thời điểm đăng ký"]
        Startup["🚀 Lúc khởi động App"]
        Lazy["⏳ Lazy Registration"]
        DI["💉 Dependency Injection"]
    end
    
    Startup --> Pro1["✅ Đơn giản, dễ đoán"]
    Lazy --> Pro2["✅ Tải ban đầu nhanh hơn"]
    DI --> Pro3["✅ Dễ test, mockable"]
```

---

## 4.6. Mẫu Error Boundary (Rào chắn lỗi)

**Vấn đề**: Làm sao để ngăn lỗi của executor làm crash app?

**Giải pháp**: Bọc toàn bộ logic executor trong try-catch và chuyển đổi thành sự kiện.

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
        Process -->|"Thành công"| EmitSuccess["emitSuccess(result)"]
        Process -->|"Exception"| TryCatch
        TryCatch --> EmitFail
    end
    
    Note["❌ Exception KHÔNG BAO GIỜ lọt ra ngoài executor"]
    
    style EmitSuccess fill:#37b24d,color:#fff
    style EmitFail fill:#f03e3e,color:#fff
```

### Sự đảm bảo

> **Mỗi lần dispatch job luôn trả về đúng một event kết quả**: Success HOẶC Failure.
> Orchestrator luôn có thể tin tưởng rằng sẽ nhận được phản hồi.

---

## 4.7. Mối quan hệ giữa các mẫu

```mermaid
graph TB
    subgraph Patterns["🧩 Các mẫu cốt lõi"]
        JE["Job-Executor"]
        ER["Event Routing"]
        ST["State Transition"]
        SB["Scoped Bus"]
        RG["Registry"]
        EB["Error Boundary"]
    end
    
    JE -->|"cho phép"| ER
    ER -->|"kích hoạt"| ST
    SB -->|"cô lập"| ER
    RG -->|"tối ưu hóa"| JE
    EB -->|"bảo vệ"| JE
    
    style JE fill:#4c6ef5,color:#fff
    style ER fill:#37b24d,color:#fff
    style ST fill:#f59f00,color:#fff
```

---

## Tổng kết

| Mẫu (Pattern) | Giải quyết vấn đề gì | Cơ chế chính |
|---------------|----------------------|--------------|
| **Job-Executor** | Tách yêu cầu khỏi xử lý | Định tuyến theo Type |
| **Event Routing** | Khớp sự kiện với nguồn | Correlation ID |
| **State Transition** | UI state nhất quán | State machine |
| **Scoped Bus** | Ngăn rò rỉ sự kiện | Kênh cô lập |
| **Registry** | Định tuyến hiệu quả | O(1) lookup map |
| **Error Boundary** | Ngăn crash app | Tự động try-catch |

**Bài học chính**: Các mẫu này kết hợp với nhau tạo nên một kiến trúc mạnh mẽ, dễ kiểm thử và có khả năng mở rộng.
