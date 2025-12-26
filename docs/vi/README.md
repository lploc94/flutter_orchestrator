# Tài liệu Flutter Orchestrator

Chào mừng bạn đến với tài liệu kỹ thuật chính thức của **Flutter Orchestrator**. Đây là nơi hướng dẫn chi tiết cách cài đặt, sử dụng và tích hợp framework vào dự án của bạn.

Nếu bạn muốn tìm hiểu về triết lý thiết kế và tư duy kiến trúc, vui lòng đọc [Sách (The Book)](../../book/vi/README.md).

---

## 📚 Mục lục

### 🚀 Bắt đầu (Getting Started)
- [Cài đặt & Thiết lập ban đầu](guide/getting_started.md) ✅
- [Cheat Sheet - Tổng quan các khái niệm](guide/core_concepts.md) ✅
- [Cấu trúc thư mục chuẩn](guide/project_structure.md) ✅

### �️ CLI Tool
- [Orchestrator CLI](guide/cli.md) ✅ - Công cụ scaffolding
- [CLI Cheatsheet](guide/cli_cheatsheet.md) ✅ - Tham khảo nhanh

### �📖 Khái niệm chi tiết (Concepts)
| Concept | Mô tả | Status |
|---------|-------|--------|
| [Job](concepts/job.md) | Định nghĩa hành động (gói dữ liệu) | ✅ |
| [Executor](concepts/executor.md) | Xử lý Business Logic | ✅ |
| [Orchestrator](concepts/orchestrator.md) | Quản lý UI State | ✅ |
| [Dispatcher](concepts/dispatcher.md) | Trung tâm điều phối | ✅ |
| [SignalBus](concepts/signal_bus.md) | Giao tiếp sự kiện | ✅ |
| [Event](concepts/event.md) | Các loại sự kiện | ✅ |

### 🛠 Hướng dẫn tích hợp (Integration)
| Package | Thư viện | Status |
|---------|----------|--------|
| [orchestrator_bloc](guide/integration.md#bloc) | flutter_bloc | ✅ |
| [orchestrator_provider](guide/integration.md#provider) | provider | ✅ |
| [orchestrator_riverpod](guide/integration.md#riverpod) | riverpod | ✅ |

### 🔥 Tính năng nâng cao (Advanced)
- [Hỗ trợ Offline & Network Action](advanced/offline_support.md) ✅
- [Cache & Data Strategy](advanced/cache.md) ✅
- [Error Handling & Logging](advanced/error_handling.md) ✅
- [Testing](advanced/testing.md) ✅
- [Code Generation](advanced/code_generation.md) ✅

### 📦 Examples
- [Simple Counter](../../examples/simple_counter) - Hello World example

---

### 📋 Ghi chú
- ✅ = Đã viết nội dung đầy đủ
