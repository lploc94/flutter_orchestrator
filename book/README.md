# Event-Driven Orchestrator Pattern Guide

This book provides a comprehensive path from conceptual thinking to technical implementation of the **Event-Driven Orchestrator** architecture.

> 🇻🇳 **[Phiên bản Tiếng Việt](vi/README.md)**

---

## Part I: Conceptual Foundation

### [Chapter 1: The Problem and Solution](chapters/01_the_pain.md)
- Current State: Why Controllers become "God Classes"
- Root Cause: Confusing UI State with Business Logic
- Solution: Fire-and-Forget & Bi-directional Async

### [Chapter 2: Architecture Overview](chapters/02_architecture_concepts.md)
- Orchestrator - Dispatcher - Executor
- Signal Bus and Pub/Sub mechanism
- Active Mode vs Passive Mode

---

## Part II: Technical Implementation

### [Chapter 3: Building the Core Framework](chapters/03_core_implementation.md)
- BaseJob, BaseEvent models
- Signal Bus with Broadcast Stream
- Dispatcher with Registry Pattern
- BaseExecutor and BaseOrchestrator

### [Chapter 4: UI Integration](chapters/04_integration.md)
- BLoC/Cubit integration (`orchestrator_bloc`)
- Provider integration (`orchestrator_provider`)
- Riverpod integration (`orchestrator_riverpod`)

---

## Part III: Advanced & Practical

### [Chapter 5: Advanced Patterns](chapters/05_advanced_patterns.md)
- Cancellation with CancellationToken
- Timeout handling
- Retry with Exponential Backoff
- Progress Reporting
- Logging System

### [Chapter 6: Case Study - AI Chatbot](chapters/06_case_study.md)
- [07. Best Practices & AI Integration](chapters/07_best_practices.md)
- Context Enrichment from multiple data sources
- Chaining Actions (Phase 1 → Phase 2)
- Streaming Response
- Security Analysis

---

## Reading Guide

| Audience | Recommended Path |
|----------|------------------|
| **Beginners** | Read Chapters 1 → 6 |
| **Familiar with architecture** | Start from Chapter 3 |
| **Just need integration** | Read Chapter 4 |
| **Want examples** | Read Chapter 6 |
