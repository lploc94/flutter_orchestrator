# Strict Flutter Orchestrator: Best Practices & Design Principles

Tài liệu này tổng hợp các nguyên tắc cốt lõi để duy trì kiến trúc Orchestrator "Strict", đảm bảo tính Clean, Scalable và Maintainable.

## 1. Phân Chia Trách Nhiệm (Separation of Concerns)

### Orchestrator (The Commander)
*   **Vai trò:** Là bộ não trung tâm, điều phối luồng công việc.
*   **Cross-Domain Logic:** Mọi logic liên quan đến nhiều domain (VD: Transfer tiền từ Chamber A sang B nhằm mục đích fulfill Hope C) **bắt buộc** phải nằm ở tầng Orchestrator.
*   **Extension Scripts:** Đối với các luồng nghiệp vụ dài, phức tạp hoặc Cross-Domain, KHÔNG viết trực tiếp trong class Orchestrator. Hãy tách ra thành các `extension` (Scripts).
    *   *Ví dụ:* `NestOrchestrator` quá lớn -> tách `executeForagePlan` ra `SystemScripts`, tách `executeTransfer` ra `AssetScripts`.
    *   *Lợi ích:* Giữ file Orchestrator chính cực gọn, chỉ chứa State definition và các Dispatcher cơ bản.

### Worker/Executor (The Worker)
*   **Vai trò:** Là thợ lành nghề, chỉ biết làm việc của mình.
*   **Domain Isolation:** Worker chỉ được phép xử lý logic trên Domain Entity mà nó quản lý.
    *   *Sai:* `ChamberExecutor` đi update `Asset`.
    *   *Đúng:* `ChamberExecutor` chỉ update `AntChamber`. Nếu cần update Asset, Orchestrator phải dispatch job cho `AssetExecutor`.
*   **Pure Execution:** Worker nhận Job -> Thực thi logic -> Emit Event -> Trả về kết quả. Không gọi ngược lên Orchestrator, không gọi UI.

---

## 2. Quản Lý State (State Management)

### DB-State Symmetry (Đối Xứng)
*   **Nguyên tắc Vàng:** State của Orchestrator nên là tấm gương phản chiếu (mirror) của DB Entity.
*   **No Magic Fields:** Không thêm các field tính toán lịch sử phức tạp (như `totalCollected` 10 năm) vào State nếu DB Entity không chứa nó.
*   **Lý do:** Giữ State nhẹ ("Lightweight"), đồng bộ dễ dàng, tránh việc State và DB bị lệch pha (State drift).

### Derived Metrics (Chỉ Số Dẫn Xuất)
*   **Internal Only:** Orchestrator chỉ được phép tính toán Metrics dựa trên những dữ liệu mà nó **đang nắm giữ trong tay** (State).
    *   *Ví dụ:* `ChamberState` nắm `List<Asset>`. Nó hoàn toàn có quyền tính `totalValue = sum(assets)`. Đây là metrics hợp lệ.
    *   *Ví dụ sai:* `ForageState` tính `totalCollected` bằng cách tự ý gọi Transaction Repository query lại 1000 record cũ. Đây là vi phạm quy tắc "Worker làm, Orchestrator chỉ giữ State".

### Event-Driven Updates (Observer Pattern)
*   **Passive Listening:** Orchestrator không được watch trực tiếp Stream của DB (trừ trường hợp đặc biệt). Nó phải update state thông qua việc lắng nghe **Events** được emit từ Worker.
*   *Luồng:* User Action -> Orchestrator -> Job -> Worker (Write DB) -> Emit Event -> Orchestrator (Listen & Update State).

---

## 3. Phân Cấp Orchestrator (Hierarchical Orchestration)

### Parent vs. Child Orchestrator
*   **Parent (NestOrchestrator):**
    *   Quản lý danh sách định danh (`List<ChamberId>`).
    *   Quản lý các thông số vĩ mô (Total Net Worth của cả tổ).
    *   Điều phối các hành động liên quan đến cấu trúc tổ (Create/Delete Chamber).
*   **Child (ChamberOrchestrator):**
    *   Quản lý chi tiết của từng Chamber (`AssetList`, `HopeList`, `Name`, `Description`).
    *   Thực hiện các hành động vi mô bên trong Chamber (Decoration, Local Forage).

### Quy Tắc "Ai Nắm Gì"
*   **Nest nắm ID, Chamber nắm Ruột:** Nest không cần load chi tiết toàn bộ assets của 1000 chamber. Nó chỉ cần biết ID các chamber. Khi user bấm vào một chamber, `ChamberOrchestrator(id)` mới được khởi tạo và load chi tiết "ruột" của chamber đó.
*   **Lazy & Granular:** Cách chia này giúp Performance tối ưu. Thay đổi ở Chamber A không làm rebuild UI của Chamber B hay làm lag Nest Parent.

---

## 4. Tóm Tắt "Do & Don't"

| Feature | DO (Nên) | DON'T (Không Nên) |
| :--- | :--- | :--- |
| **Cross-Domain** | Viết tại Orchestrator (Extension Scripts) | Viết lén trong Worker này gọi Worker kia |
| **Logic Dài** | Tách ra file `part of` hoặc `extension` | Viết hết trong 1 file Orchestrator 2000 dòng |
| **Metric** | Tính từ data có sẵn trong State | Query lén DB trong hàm Getter của State |
| **Update UI** | Lắng nghe Event để update State | Watch trực tiếp DB Stream |
| **Trách nhiệm** | Parent giữ Struct, Child giữ Detail | Parent ôm đồm load hết dữ liệu con cháu |

---

## 5. Transaction & Saga Pattern

### Khi nào dùng Saga?
*   **Complex Flows:** Khi một hành động của User kích hoạt chuỗi thay đổi trên nhiều Entity khác nhau (VD: "Xóa Chamber" -> Phải sơ tán Assets về Deep Storage -> Phải xóa Hopes liên quan -> Mới xóa Chamber).
*   **Fail-Safe:** Nếu bước 3 thất bại, hệ thống phải Rollback trạng thái về như cũ (trả lại Assets, khôi phục Hopes).

### Triển khai ở đâu?
Chúng ta có 2 cấp độ Saga:

**1. Macro-Saga (Orchestrator Level):**
*   **Phạm vi:** Cross-Domain (liên quan nhiều Worker).
*   **Logic:** Nằm ở Orchestrator Scripts.
*   **Ví dụ:** Xóa Chamber (Asset Worker sơ tán -> Hope Worker clean -> Chamber Worker xóa). Nếu lỗi, Orchestrator ra lệnh cho Assets quay về chỗ cũ.

**2. Micro-Saga (Worker Level):**
*   **Phạm vi:** Single-Domain (nhiều bước trong cùng 1 Entity).
*   **Logic:** Nằm trong hàm xử lý của Executor.
*   **Ví dụ:** "Tạo Chamber Template" (Tạo Chamber Record -> Tạo Default Config -> Tạo Sample Data). Nếu tạo Sample lỗi, Worker phải tự xóa Chamber Record vừa tạo (DB Transaction rollback).

### Quy tắc Idempotency (Tính Lũy Đẳng)
*   Trong môi trường Saga, các Job dispatch xuống Worker nên có tính Idempotency (làm lại lần 2 kết quả không đổi) để an toàn khi retry.

---

## 6. Ownership & Lifecycle Rules (Quy Tắc Sở Hữu)

### Parent Manages Lifecycle (Cha quản lý vòng đời)
*   **No Suicide:** Child Orchestrator **KHÔNG NÊN** có method tự xóa chính mình (`delete()`). Nếu Asset muốn bị xóa, nó phải thông qua Chamber.
*   **Lý do:** Parent đang giữ danh sách ID của con. Nếu con tự xóa, Parent không biết để cập nhật danh sách -> Lỗi data không đồng bộ.

### Child Manages State (Con quản lý trạng thái)
*   **Update:** Child Orchestrator chịu trách nhiệm update các field nội tại của nó.
    *   `AssetOrchestrator` -> `update()`, `calculatePnL()`.
*   **Self-Aware:** Child chỉ biết về bản thân nó, không biết về anh em của nó (không có method `listOthers()`).

### Parent Manages Query (Cha quản lý danh sách)
*   **Listing:** Parent chịu trách nhiệm list danh sách các ID của con.
    *   `Nest` -> `loadChambers()` (List IDs).
    *   `Chamber` -> `loadAssets()` (List IDs hoặc List Entities).

---

## 7. Worker vs. Orchestrator Capabilities (Quyền Hạn)

### Worker (Executor) - The Toolset
*   **Full Capabilities:** Worker (VD: `AssetExecutor`) cần hỗ trợ đầy đủ các thao tác CRUD và List để phục vụ mọi nhu cầu của hệ thống.
    *   `process(Job.create)` -> OK.
    *   `process(Job.list)` -> OK (Trả về List<Asset>).
    *   `process(Job.delete)` -> OK.
*   **No Logic Constraints:** Worker không quan tâm ai gọi nó, nó chỉ thực thi lệnh và return data/event.

### Orchestrator - The User
*   **Role-Based Usage:** Orchestrator bị giới hạn quyền gọi Worker tùy theo vai trò của nó (Parent hay Child).
    *   `AssetOrchestrator` (Child): CHỈ được gọi `Job.get`, `Job.update`. KHÔNG ĐƯỢC gọi `Job.list`, `Job.delete` (tự sát).
    *   `ChamberOrchestrator` (Parent): ĐƯỢC gọi `Job.list` (để lấy danh sách asset), `Job.delete` (để xóa asset con).

---> *Quy tắc: "Thợ (Worker) thì phải biết làm đủ thứ, nhưng Người chỉ huy (Orchestrator) chỉ dùng những công cụ phù hợp với cấp bậc của mình."*

---

## 8. Event Payload Strategy (Chiến lược dữ liệu sự kiện)

### Nguyên tắc: Smart Events
Event không chỉ là một tín hiệu báo hiệu thay đổi ("Hey, có gì đó đổi nè"), mà nó phải mang theo **Dữ liệu thay đổi** đó ("Hey, Object A vừa đổi thành thế này nè").

### Tại sao?
*   **Tránh Round-Trip:** Nếu Event chỉ mang ID, Orchestrator phải dispatch thêm một Job `fetch(id)` để lấy dữ liệu mới -> Tốn 2 bước, UI bị delay.
*   **Performance:** Giảm tải cho DB (tránh read thừa).

### Standard Payloads
1.  **CreatedEvent:** Mang theo **Full Object** vừa tạo.
    *   `AssetCreatedEvent(id, Asset object)`
2.  **UpdatedEvent:** Mang theo **Full Object** sau khi update.
    *   `AssetUpdatedEvent(id, Asset newObject)`
3.  **DeletedEvent:** Mang theo **ID** (vì object đã mất, không cần data).
    *   `AssetDeletedEvent(id)`
4.  **TransactionEvent:** Mang theo Delta amount và Context (Source/Target).
    *   `AssetTransferredEvent(fromId, toId, amount, hopeId)`

---
*Tài liệu này được biên soạn bởi Antigravity Team.*
