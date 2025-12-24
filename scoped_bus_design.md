# Scoped Bus Architecture Design

## 1. Vấn đề hiện tại: Global Bus ("Chợ Làng")

Hiện tại, `SignalBus` là một **Global Singleton**. Mọi Event (Loading, LoginSuccess, CartUpdated, MouseMoved...) đều đi qua "đường ống" duy nhất này.

```mermaid
graph TD
    subgraph "Global Signal Bus"
        Bus[SignalBus (Singleton)]
    end

    Auth[Auth Orchestrator] -->|Fire Event| Bus
    Cart[Cart Orchestrator] -->|Fire Event| Bus
    Chat[Chat Orchestrator] -->|Fire Event| Bus

    Bus -->|Broadcast ALL| Auth
    Bus -->|Broadcast ALL| Cart
    Bus -->|Broadcast ALL| Chat
```

**Nhược điểm:**
- **Bottleneck**: Khi app lớn, hàng nghìn event/giây đi qua 1 StreamController.
- **Wasteful**: `CartOrchestrator` không quan tâm `ChatNewMessageEvent`, nhưng vẫn phải nhận và lọc bỏ (`if (event is CartEvent)`).
- **Security**: Module này có thể vô tình lắng nghe Event nhạy cảm của Module khác.

---

## 2. Giải pháp: Scoped Bus ("Phòng Họp Riêng")

Chúng ta chia nhỏ hệ thống thành các **Scope (Module)**. Mỗi Scope có một `SignalBus` riêng.

```mermaid
graph TD
    subgraph "Global Scope (Shared)"
        GBus[Global Signal Bus]
    end

    subgraph "Auth Module"
        ABus[Auth Bus]
        Login[Login Job] --> ABus
        AuthOrc[Auth Orchestrator] -.->|Listen| ABus
        ABus -->|Success| GBus ==> "LoginSuccess (Public)"
    end

    subgraph "Cart Module"
        CBus[Cart Bus]
        AddCart[Add Item Job] --> CBus
        CartOrc[Cart Orchestrator] -.->|Listen| CBus
    end

    GBus -.->|Listen (Optional)| AuthOrc
    GBus -.->|Listen (Optional)| CartOrc
```

**Cơ chế:**
1.  **Internal Event**: Các sự kiện nội bộ (ví dụ: `ParsingData`, `Step1Completed`) chỉ đi trong **Local Bus** của Module. Các Module khác không biết và không bị spam.
2.  **Public Event**: Khi cần thông báo ra ngoài (ví dụ: `LoginSuccess`), Module bắn event đó lên **Global Bus**.

## 3. Implementation Plan (Opt-in)

Thay vì đập đi xây lại, ta hỗ trợ cả hai:

**Class `BaseOrchestrator`:**

```dart
abstract class BaseOrchestrator<S> {
  final SignalBus _bus;

  // Constructor hỗ trợ Dependency Injection bus
  BaseOrchestrator(this._state, {SignalBus? bus}) 
      : _bus = bus ?? SignalBus.instance; // Default to Global if null
}
```

**Cách dùng:**

- **Cách cũ (Simple App):**
```dart
class MyOrc extends BaseOrchestrator { ... } // Dùng Global Bus
```

- **Cách mới (Module App):**
```dart
// Trong Cart Module
final cartBus = SignalBus(); // Tạo bus riêng
final cartOrc = CartOrchestrator(bus: cartBus); 
```

### Lợi ích "Kép"
- **App nhỏ**: Code gọn nhẹ, không cần setup gì thêm.
- **App lớn**: Tối ưu hiệu năng, cô lập lỗi (isolation) cực tốt.
