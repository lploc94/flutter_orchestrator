# Chương 6: Case Studies (Thực hành)

> *"Về lý thuyết, không có sự khác biệt giữa lý thuyết và thực hành. Nhưng trong thực tế, có đấy."* — Yogi Berra

Chương này sẽ rời xa các pattern trừu tượng và đi sâu vào các kịch bản thực tế chi tiết. Chúng ta sẽ khám phá cách kết hợp nhiều pattern để giải quyết các yêu cầu nghiệp vụ phức tạp.

---

## 6.1. Case Study: AI Chatbot

Xây dựng một AI Chatbot bao gồm nhiều thử thách phức tạp: các tác vụ chạy rất lâu (độ trễ của LLM), dữ liệu đến dưới dạng dòng chảy (streaming từng token), và quy trình bao gồm nhiều bước riêng biệt (lấy ngữ cảnh -> sinh câu trả lời -> lưu lịch sử).

### Tổng quan hệ thống

Chúng ta mô hình hóa hệ thống bằng ba Executor riêng biệt, được điều phối bởi một `ChatOrchestrator` duy nhất.

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

### Luồng xử lý (The Flow)

Luồng tin nhắn được chia thành ba giai đoạn. Hãy chú ý cách Orchestrator giữ vai trò điều phối trung tâm, gửi đi (dispatch) các job mới khi job trước đó hoàn thành.

```mermaid
sequenceDiagram
    participant User as 👤 User
    participant Chat as 🎭 ChatOrchestrator
    participant RAG as 📚 ContextExecutor
    participant LLM as 🤖 AIExecutor
    participant DB as 💾 SaveExecutor
    
    User->>Chat: sendMessage("Cái gì là...")
    
    rect rgb(240, 247, 255)
        Note over Chat: Giai đoạn 1: Lấy ngữ cảnh (Context)
        Chat->>RAG: dispatch(GetContextJob)
        RAG-->>Chat: ContextReadyEvent
    end
    
    rect rgb(240, 255, 240)
        Note over Chat: Giai đoạn 2: Sinh câu trả lời (AI)
        Chat->>LLM: dispatch(GenerateResponseJob)
        loop Streaming
            LLM-->>Chat: ProgressEvent(token)
            Note right of Chat: Update UI ngay lập tức
        end
        LLM-->>Chat: AIResponseEvent
    end
    
    rect rgb(255, 250, 240)
        Note over Chat: Giai đoạn 3: Lưu trữ (Persistence)
        Chat->>DB: dispatch(SaveMessageJob)
        DB-->>Chat: SavedEvent
    end
    
    Chat-->>User: State cuối cùng được cập nhật
```

### Pattern Chuỗi công việc (Chained Jobs)

Thay vì viết một hàm khổng lồ, chúng ta xử lý quy trình làm việc như một máy trạng thái (state machine). Điều này cho phép chúng ta xử lý lỗi cụ thể cho từng giai đoạn (ví dụ: nếu Lưu thất bại, chúng ta không làm mất câu trả lời của AI, mà chỉ hiện nút "Thử lưu lại", vì câu trả lời AI đã có trong bộ nhớ).

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

### Các quyết định chính

| Quyết định | Lý do |
|------------|-------|
| **Tách riêng RAG Executor** | Logic lấy ngữ cảnh (vector DB lookup) rất phức tạp và có thể được dùng bởi tính năng khác (ví dụ: "Bài viết liên quan"). Tách ra giúp tái sử dụng. |
| **Streaming qua Progress** | Chúng ta tái sử dụng `ProgressEvent` để mang dữ liệu chuỗi một phần (tokens). Điều này mang lại phản hồi tức thì cho người dùng. |
| **Lưu sau khi AI xong** | Chúng ta chỉ lưu tin nhắn khi đã có đầy đủ câu trả lời để đảm bảo tính nhất quán của cơ sở dữ liệu. |

---

## 6.2. Case Study: File Upload

File upload là một tác vụ "chạy lâu" (long-running) điển hình, đòi hỏi sự xử lý cẩn thận đối với mạng không ổn định và tương tác người dùng (hủy bỏ).

### Luồng xử lý

Ở đây, chúng ta sử dụng `CancellationToken` để cho phép người dùng ngắt quy trình. Executor kiểm tra token này trước khi upload mỗi chunk (phần nhỏ của file).

```mermaid
sequenceDiagram
    participant User as 👤 User
    participant UI as 🖥️ Upload UI
    participant Orch as 🎭 Orchestrator
    participant Exec as ⚙️ UploadExecutor
    participant S3 as ☁️ Cloud Storage
    
    User->>UI: Chọn file
    UI->>Orch: startUpload(file)
    Orch->>Orch: token = new CancellationToken()
    Orch->>Exec: dispatch(UploadJob, token)
    
    loop Chunks
        Exec->>S3: Upload chunk
        Exec-->>Orch: Progress(30%)
        Exec->>S3: Upload chunk
        Exec-->>Orch: Progress(60%)
        
        alt User hủy
            User->>Orch: cancel()
            Orch->>Token: cancel()
            Exec->>Exec: throw CancelledException
            Exec-->>Orch: CancelledEvent
        end
    end
    
    Exec->>S3: Complete multipart
    Exec-->>Orch: SuccessEvent(url)
    Orch-->>UI: Upload hoàn tất
```

### Trạng thái Upload Chunk

Đối tượng state cần theo dõi tiến độ chi tiết, chứ không chỉ đơn giản là "đang tải".

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

### Chiến lược Retry (Thử lại)

Không phải lỗi nào cũng giống nhau. Chúng ta triển khai logic retry thông minh bên trong Executor:
- **Lỗi tạm thời (Transient Errors)** (Network timeout, 502 Bad Gateway): Thử lại với thời gian chờ tăng dần (exponential backoff).
- **Lỗi vĩnh viễn (Permanent Errors)** (401 Unauthorized, 413 Payload Too Large): Báo lỗi ngay lập tức.

```mermaid
flowchart TD
    Upload["Upload Chunk"] --> Success{"Thành công?"}
    Success -->|"YES"| Next["Chunk kế tiếp"]
    Success -->|"NO"| Transient{"Lỗi tạm thời?"}
    
    Transient -->|"YES (5xx, timeout)"| Retry["Retry có backoff"]
    Transient -->|"NO (4xx)"| Fail["Fail ngay lập tức"]
    
    Retry --> Attempts{"Số lần < 3?"}
    Attempts -->|"YES"| Upload
    Attempts -->|"NO"| Fail
```

---

## 6.3. Case Study: Giỏ hàng (Shopping Cart)

Tính năng Giỏ hàng giới thiệu giao tiếp liên module (cross-module). Khi người dùng thêm một món vào giỏ, màn hình "Chi tiết sản phẩm" (có thể đang active ở background) cần biết về điều đó để cập nhật hiển thị số lượng tồn kho.

### Kiến trúc hệ thống

Chúng ta sử dụng **Global Bus** để phát (broadcast) các sự kiện mà nhiều module cùng quan tâm.

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

### Ví dụ Observer Mode

Sequence này cho thấy cách `ProductOrchestrator` cập nhật thụ động dựa trên một hành động được kích hoạt bởi `CartOrchestrator`.

```mermaid
sequenceDiagram
    participant Cart as 🛒 CartOrchestrator
    participant Product as 📦 ProductOrchestrator
    participant Bus as 📡 Global Bus
    participant Exec as ⚙️ CartExecutor
    
    Note over Cart: User thêm sản phẩm
    Cart->>Exec: dispatch(AddToCartJob)
    Exec->>Bus: CartUpdatedEvent
    
    Bus->>Cart: event (Direct Mode)
    Note over Cart: Cập nhật cart state
    
    Bus->>Product: event (Observer Mode)
    Note over Product: Cập nhật hiển thị tồn kho
```

### Mẫu Cập nhật Lạc quan (Optimistic Update)

Để tạo cảm giác mượt mà, chúng ta giả định là sẽ thành công. Chúng ta cập nhật UI *trước khi* network request trả về. Nếu thất bại, chúng ta sẽ hoàn tác (rollback).

```mermaid
flowchart TD
    Start["User click Thêm vào Giỏ"]
    
    Start --> Optimistic["Cập nhật state ngay lập tức<br/>(lạc quan)"]
    Optimistic --> Dispatch["dispatch(AddToCartJob)"]
    
    Dispatch --> Result{"Kết quả?"}
    
    Result -->|"Thành công"| Confirm["Giữ nguyên state lạc quan"]
    Result -->|"Thất bại"| Rollback["Hoàn tác về state cũ<br/>Hiển thị lỗi"]
    
    style Optimistic fill:#37b24d,color:#fff
    style Rollback fill:#f03e3e,color:#fff
```

---

## 6.4. Case Study: Xác thực (Authentication)

Authentication (Xác thực) là trường hợp đặc biệt vì nó ảnh hưởng đến toàn bộ app (Global State) nhưng lại yêu cầu bảo mật cao.

### Kiến trúc

Chúng ta dùng **Scoped Bus** cho các logic auth nội bộ (như parse token) để ngăn các module khác "nghe lén" các sự kiện nhạy cảm, nhưng lại public các sự kiện cấp cao như `UserLoggedIn` ra Global Bus.

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
    
    Note["🔒 Auth state nội bộ (tokens) được giữ kín<br/>Chỉ public events login/logout"]
```

### Luồng Token Refresh

Đây là một quy trình chạy ngầm trong suốt với người dùng. Khi bất kỳ request nào thất bại với lỗi 401, `AuthExecutor` sẽ chặn lại (intercept), làm mới token, và thử lại request gốc.

```mermaid
sequenceDiagram
    participant Any as 📱 Any Executor
    participant Auth as 🔐 AuthExecutor
    participant API as 🌐 API
    
    Any->>API: Request kèm token
    API-->>Any: 401 Unauthorized
    
    Any->>Auth: dispatch(RefreshTokenJob)
    Auth->>API: POST /refresh
    API-->>Auth: Token mới
    Auth-->>Any: TokenRefreshedEvent
    
    Any->>API: Retry request với token mới
    API-->>Any: Success
```

---

## 6.5. Bài học rút ra

```mermaid
mindmap
  root((Bài học))
    Sự phân tách (Separation)
      Giữ executor đơn giản
      Một job = một việc
      Kết hợp lại để xử lý phức tạp
    Giao tiếp (Communication)
      Dùng scoped bus cho riêng tư
      Dùng global bus cho liên module
      Luôn kèm correlationId
    Sự kiên cường (Resilience)
      Luôn xử lý failures
      Retry cho lỗi tạm thời
      Cho user quyền Hủy
    Hiệu năng (Performance)
      Deduplicate requests (chống trùng)
      Cache khi phù hợp
      Stream cho tác vụ dài
```

---

## Tổng kết

| Case Study | Các Pattern chính |
|------------|-------------------|
| **AI Chatbot** | **Chaining**: Nối các tác vụ tuần tự. **Streaming**: Phản hồi thời gian thực. |
| **File Upload** | **Cancellation**: Trao quyền cho user. **Retry**: Xử lý biến động mạng. |
| **Shopping Cart** | **Observer Mode**: Phản ứng với người khác. **Optimistic Update**: Phản hồi tức thì. |
| **Authentication** | **Scoped Bus**: Đóng gói (Encapsulation). **Interceptor**: Phục hồi trong suốt. |

**Bài học chính**: Các ứng dụng production thực tế hiếm khi là các luồng tuyến tính đơn giản. Chúng đòi hỏi xử lý lỗi mạnh mẽ, giao tiếp liên module, và các tính năng lấy người dùng làm trung tâm như hủy bỏ và cập nhật lạc quan. Kiến trúc này cung cấp các pattern chuẩn cho tất cả những điều đó.
