# Hướng dẫn Event-Driven Orchestrator Pattern

Cuốn sách này cung cấp một lộ trình từ tư duy đến triển khai kỹ thuật cho kiến trúc **Event-Driven Orchestrator**.

> 🇺🇸 **[English Version](../README.md)**

> 📚 **[Bảng Thuật ngữ Anh-Việt](../GLOSSARY.md)**

---

## Phần I: Nền tảng Tư duy

### [Chương 1: Bài toán và Giải pháp](chapters/01_the_pain.md)
- Thực trạng: Tại sao Controller trở thành "God Classes"
- Nguyên nhân: Nhầm lẫn UI State với Business Logic
- Giải pháp: Fire-and-Forget & Bi-directional Async

### [Chương 2: Tổng quan Kiến trúc](chapters/02_architecture_concepts.md)
- Orchestrator - Dispatcher - Executor
- Signal Bus và cơ chế Pub/Sub
- Active Mode vs Passive Mode

---

## Phần II: Triển khai Kỹ thuật

### [Chương 3: Xây dựng Core Framework](chapters/03_core_implementation.md)
- BaseJob, BaseEvent models
- Signal Bus với Broadcast Stream
- Dispatcher với Registry Pattern
- BaseExecutor và BaseOrchestrator

### [Chương 4: Tích hợp UI](chapters/04_integration.md)
- BLoC/Cubit integration (`orchestrator_bloc`)
- Provider integration (`orchestrator_provider`)
- Riverpod integration (`orchestrator_riverpod`)

---

## Phần III: Nâng cao & Thực chiến

### [Chương 5: Các Kỹ thuật Nâng cao](chapters/05_advanced_patterns.md)
- Cancellation với CancellationToken
- Timeout handling
- Retry với Exponential Backoff
- Progress Reporting
- Logging System

### [Chương 6: Case Study (Thực hành)](chapters/06_case_study.md)
- Context Enrichment từ nhiều nguồn dữ liệu
- Chaining Actions (Phase 1 → Phase 2)
- Streaming Response
- Security Analysis

### [Chương 7: Best Practices & Hướng dẫn cho AI](chapters/07_best_practices.md)
- Quy tắc Vàng (Nên & Không nên)
- Cấu trúc thư mục chuẩn
- **AI System Prompts** (Dành cho Agent)

---

## Cách đọc sách

| Đối tượng | Lộ trình |
|-----------|----------|
| **Mới bắt đầu** | Đọc từ Chương 1 → 6 |
| **Đã biết kiến trúc** | Bắt đầu từ Chương 3 |
| **Chỉ cần tích hợp** | Đọc Chương 4 |
| **Muốn xem ví dụ** | Đọc Chương 6 |
