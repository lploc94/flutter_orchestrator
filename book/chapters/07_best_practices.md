# Chapter 7: Best Practices & AI Integration

This final chapter synthesizes the experience of building large systems with the Event-Driven Orchestrator architecture. It provides golden rules, structural guidelines, and **Specialized Prompts to assist AI Agents** in generating compliant code.

---

## 7.1. The Golden Rules (Do's & Don'ts)

### ✅ Do's
1.  **Strict Separation**: Always put business logic in `Executors` and UI state logic in `Orchestrators`.
2.  **Immutable State**: Always use `copyWith` patterns for state updates.
3.  **Explicit Context**: Use `SignalBus.scoped()` for modular features to prevent event leaking.
4.  **Correlation IDs**: Always pass `job.id` when emitting events so the Orchestrator knows sourcing.

### ❌ Don'ts
1.  **Never call Repositories in Orchestrator**: This breaks the "Execution" separation.
2.  **Don't ignore Cancellation**: Always check `cancellationToken?.throwIfCancelled()` in long-running loops.
3.  **Avoid God-Events**: Don't create a single `AppEvent` class. Use specific events like `UserLoggedInEvent`.

---

## 7.2. Recommended Folder Structure

For scalable applications, we recommend grouping by **Feature** rather than Layer.

```text
lib/
├── core/                  # Core Architecture
│   ├── bus/
│   └── base/
├── features/
│   ├── auth/
│   │   ├── jobs/          # Job Definitions
│   │   ├── events/        # Event Definitions
│   │   ├── executors/     # Business Logic
│   │   ├── orchestrator/  # State Management
│   │   └── ui/            # Flutter Widgets
│   └── chat/
│       └── ...
└── main.dart
```

---

## 7.3. AI System Prompts (For Agents)

To ensure AI coding assistants (like Cursor, GitHub Copilot, or ChatGPT) generate code that adheres to this architecture, paste the following instructions into their **System Prompt** or **Custom Instructions**.

### 📋 The "Orchestrator Architect" Prompt

```markdown
You are an expert Flutter Developer specializing in the **Event-Driven Orchestrator Architecture**.

**Core Principles:**
1.  **Separation of Concerns**:
    - **Orchestrator**: ONLY manages UI State (Bloc/Cubit). NEVER executes business logic or calls APIs directly. It dispatches `Jobs`.
    - **Executor**: ONLY executes business logic (API calls, DB access). It emits `Events`.
    - **SignalBus**: The communication channel connecting them.

**Coding Rules:**
1.  **Jobs**: Must extend `BaseJob`. Always use `generateJobId()`.
2.  **Executors**: Must extend `BaseExecutor<T>`.
    - Use `process(job)` for logic.
    - Use `emitResult` for success and `emitFailure` for errors.
    - Always handle `cancellationToken` for loops.
3.  **Orchestrators**: Must extend `BaseOrchestrator` (or `OrchestratorCubit`).
    - Dispatch jobs using `dispatch(Job(...))`.
    - Handle results in `onActiveSuccess` (for jobs initiated by this orchestrator).
    - Handle global events in `onPassiveEvent`.

**Code Style**:
- Use specific types for Events (e.g., `UserLoadedEvent` not `DataLoadedEvent`).
- Prefer `SignalBus.scoped()` for independent modules.
```

---

## 7.4. Troubleshooting

| Symptom | Probable Cause | Solution |
| :--- | :--- | :--- |
| **Orchestrator ignores Event** | Wrong `Correlation ID` | Ensure Executor emits event using `job.id` as correlationId. |
| **Infinite Loop** | Orchestrator dispatches Job in `onActiveSuccess` without condition | Add a state check before dispatching follow-up jobs. |
| **Memory Leak** | Scoped Bus not disposed | Ensure `bus.dispose()` is called when the Orchestrator/Module is closed. |

---

## 7.5. Conclusion

The **Event-Driven Orchestrator** architecture is not just a pattern; it's a discipline. By decoupling "What happens" (UI) from "How it happens" (Execution), you gain:

- **Testability**: Executors can be tested without UI.
- **Scalability**: Modules can be developed in parallel using Scoped Buses.
- **Resilience**: Error boundaries and isolation prevent app-wide crashes.

Thank you for adopting this architecture. Happy Coding! 🚀
