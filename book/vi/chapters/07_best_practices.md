# Chương 7: Best Practices & Hướng dẫn cho AI Agent

Chương cuối cùng này tổng hợp kinh nghiệm xây dựng các hệ thống lớn với kiến trúc Event-Driven Orchestrator. Nó cung cấp các quy tắc vàng, hướng dẫn cấu trúc thư mục, và đặc biệt là **Các Prompt Mẫu để hỗ trợ AI Agent** sinh code chuẩn xác.

---

## 7.1. Quy tắc Vàng (Nên & Không Nên)

### ✅ Do's (Nên làm)
1.  **Tách biệt tuyệt đối**: Luôn đặt logic nghiệp vụ trong `Executor` và logic trạng thái UI trong `Orchestrator`.
2.  **State Bất biến**: Luôn sử dụng pattern `copyWith` khi cập nhật state.
3.  **Ngữ cảnh rõ ràng**: Sử dụng `SignalBus.scoped()` cho các module độc lập để tránh rò rỉ event.
4.  **Correlation IDs**: Luôn truyền `job.id` khi emit event để Orchestrator biết nguồn gốc.

### ❌ Don'ts (Không nên làm)
1.  **Không gọi Repository trong Orchestrator**: Điều này phá vỡ nguyên tắc tách biệt "Execution".
2.  **Đừng phớt lờ Cancellation**: Luôn kiểm tra `cancellationToken?.throwIfCancelled()` trong các vòng lặp dài.
3.  **Tránh God-Events**: Đừng tạo một class `AppEvent` chung chung. Hãy dùng các event cụ thể như `UserLoggedInEvent`.

---

## 7.2. Cấu trúc Thư mục Đề xuất

Đối với các ứng dụng có khả năng mở rộng, chúng tôi khuyến nghị nhóm theo **Feature** thay vì Layer.

```text
lib/
├── core/                  # Core Architecture
│   ├── bus/
│   └── base/
├── features/
│   ├── auth/
│   │   ├── jobs/          # Định nghĩa Job
│   │   ├── events/        # Định nghĩa Event
│   │   ├── executors/     # Logic nghiệp vụ
│   │   ├── orchestrator/  # Quản lý State
│   │   └── ui/            # Flutter Widgets
│   └── chat/
│       └── ...
└── main.dart
```

---

## 7.3. AI System Prompts (Dành cho Agent)

Để đảm bảo các trợ lý code AI (như Cursor, GitHub Copilot, ChatGPT) sinh ra code tuân thủ kiến trúc này, hãy dán hướng dẫn sau vào **System Prompt** hoặc **Custom Instructions** của chúng.

### 📋 Prompt "Kiến trúc sư Orchestrator"

```markdown
Bạn là một Chuyên gia Lập trình Flutter chuyên về **Kiến trúc Event-Driven Orchestrator**.

**Nguyên tắc Cốt lõi:**
1.  **Phân chia Trách nhiệm**:
    - **Orchestrator**: CHỈ quản lý UI State (Bloc/Cubit). KHÔNG BAO GIỜ thực thi logic nghiệp vụ hoặc gọi API trực tiếp. Nhiệm vụ là dispatch `Jobs`.
    - **Executor**: CHỈ thực thi logic nghiệp vụ (API calls, DB access). Nhiệm vụ là emit `Events`.
    - **SignalBus**: Kênh giao tiếp kết nối giữa hai thành phần trên.

**Quy tắc Code:**
1.  **Jobs**: Phải kế thừa `BaseJob`. Luôn dùng `generateJobId()`.
2.  **Executors**: Phải kế thừa `BaseExecutor<T>`.
    - Dùng phương thức `process(job)` cho logic chính.
    - Dùng `emitResult` để trả về thành công và `emitFailure` cho lỗi.
    - Luôn xử lý `cancellationToken` trong các vòng lặp.
3.  **Orchestrators**: Phải kế thừa `BaseOrchestrator` (hoặc `OrchestratorCubit`).
    - Dispatch job bằng lệnh `dispatch(Job(...))`.
    - Xử lý kết quả trong `onActiveSuccess` (cho các job do chính nó gọi).
    - Xử lý sự kiện toàn cục trong `onPassiveEvent`.

**Phong cách Code**:
- Sử dụng kiểu dữ liệu cụ thể cho Event (ví dụ: `UserLoadedEvent`, không dùng `DataLoadedEvent` chung chung).
- Ưu tiên `SignalBus.scoped()` cho các module độc lập.
```

---

## 7.4. Xử lý sự cố (Troubleshooting)

| Triệu chứng | Nguyên nhân có thể | Giải pháp |
| :--- | :--- | :--- |
| **Orchestrator phớt lờ Event** | Sai `Correlation ID` | Đảm bảo Executor emit event sử dụng `job.id` làm correlationId. |
| **Vòng lặp Vô hạn** | Orchestrator dispatch Job trong `onActiveSuccess` không điều kiện | Thêm điều kiện kiểm tra state trước khi dispatch job tiếp theo. |
| **Rò rỉ Bộ nhớ** | Scoped Bus không được dispose | Đảm bảo gọi `bus.dispose()` khi Orchestrator/Module đóng lại. |

---

## 7.5. Lời kết

Kiến trúc **Event-Driven Orchestrator** không chỉ là một pattern; nó là một kỷ luật. Bằng cách tách biệt "Cái gì xảy ra" (UI) khỏi "Nó xảy ra như thế nào" (Execution), bạn đạt được:

- **Khả năng kiểm thử**: Executor có thể test độc lập không cần UI.
- **Khả năng mở rộng**: Các module phát triển song song nhờ Scoped Bus.
- **Sự bền bỉ**: Error boundaries và sự cô lập ngăn chặn crash toàn app.

Cảm ơn bạn đã lựa chọn kiến trúc này. Happy Coding! 🚀
