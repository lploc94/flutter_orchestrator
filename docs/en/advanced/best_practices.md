# Strict Flutter Orchestrator: Best Practices & Design Principles

This document summarizes core principles to maintain a "Strict" Orchestrator architecture, ensuring Clean, Scalable and Maintainable code.

## 1. Separation of Concerns

### Orchestrator (The Commander)
*   **Role:** The central brain, coordinating workflow.
*   **Cross-Domain Logic:** Any logic involving multiple domains (e.g., Transfer money from Chamber A to B to fulfill Hope C) **must** reside in the Orchestrator layer.
*   **Extension Scripts:** For long, complex, or Cross-Domain business flows, DO NOT write directly in the Orchestrator class. Separate them into `extension` (Scripts).
    *   *Example:* `NestOrchestrator` is too large -> split `executeForagePlan` into `SystemScripts`, split `executeTransfer` into `AssetScripts`.
    *   *Benefit:* Keeps the main Orchestrator file lean, containing only State definitions and basic Dispatchers.

### Worker/Executor (The Worker)
*   **Role:** The skilled worker, focused solely on their specific task.
*   **Domain Isolation:** A Worker is only allowed to process logic on the Domain Entity it manages.
    *   *Wrong:* `ChamberExecutor` updates `Asset`.
    *   *Right:* `ChamberExecutor` only updates `AntChamber`. If Asset update is needed, Orchestrator must dispatch a job to `AssetExecutor`.
*   **Pure Execution:** Worker receives Job -> Executes Logic -> Emits Event -> Returns Result. No calling back to Orchestrator, no UI interaction.

---

## 2. State Management

### DB-State Symmetry
*   **Golden Rule:** Orchestrator state should be a mirror of the DB Entity.
*   **No Magic Fields:** Do not add complex historical calculated fields (like `totalCollected` over 10 years) to State if the DB Entity does not contain it.
*   **Reason:** Keep State "Lightweight", easily synchronized, avoiding State drift.

### Derived Metrics
*   **Internal Only:** Orchestrator can only calculate Metrics based on data it **currently holds** (State).
    *   *Example:* `ChamberState` holds `List<Asset>`. It has the right to calculate `totalValue = sum(assets)`. This is a valid metric.
    *   *Wrong:* `ForageState` calculates `totalCollected` by querying 1000 old records from Transaction Repository. This violates the "Worker does logic, Orchestrator holds State" rule.

### Event-Driven Updates (Observer Pattern)
*   **Passive Listening:** Orchestrator should not directly watch DB Streams (except special cases). It must update state by listening to **Events** emitted from Workers.
*   *Flow:* User Action -> Orchestrator -> Job -> Worker (Write DB) -> Emit Event -> Orchestrator (Listen & Update State).

### 2.3. State & Logic Classification

Do not use a sledgehammer to crack a nut. Distinguish clearly between two types of state:

#### Ephemeral State (Show/Hide, Animation, Scroll)
*   **Characteristics:** Visual only, lost when widget closes.
*   **Handling:** Use **StatefulWidget** or **Hooks**. Orchestrator is NOT needed.
*   **Example:** Toggle show password, Expand/Collapse item.

#### App/Business State (User, Cart, Data)
*   **Characteristics:** Affects business logic, IO/API calls, needs persistence.
*   **Handling:** Use **Orchestrator + Job**.
*   **Example:** Login, Checkout, Fetch Data, "Agree Terms" (if triggers logic).

> **The "Render Unto Caesar" Rule:**
> *   UI things (Visuals) -> Widget.
> *   Business things (Logic) -> Orchestrator.
> *   Provider is just a bridge (binding), no logic.

---

## 3. Hierarchical Orchestration

### Parent vs. Child Orchestrator
*   **Parent (NestOrchestrator):**
    *   Manages identifier list (`List<ChamberId>`).
    *   Manages macro metrics (Total Net Worth of the nest).
    *   Coordinates structure-related actions (Create/Delete Chamber).
*   **Child (ChamberOrchestrator):**
    *   Manages details of a specific Chamber (`AssetList`, `HopeList`, `Name`, `Description`).
    *   Performs micro actions inside the Chamber (Decoration, Local Forage).

### The "Who Holds What" Rule
*   **Nest holds ID, Chamber holds Content:** Nest doesn't need to load details of 1000 chambers. It only needs IDs. When user clicks a chamber, `ChamberOrchestrator(id)` is initialized and loads the "guts" of that chamber.
*   **Lazy & Granular:** This division optimizes Performance. Changes in Chamber A do not rebuild UI of Chamber B or lag the Nest Parent.

---

## 4. Do's & Don'ts Summary

| Feature | DO | DON'T |
| :--- | :--- | :--- |
| **Cross-Domain** | Write in Orchestrator (Extension Scripts) | Sneak calls from one Worker to another |
| **Long Logic** | Split into `part of` or `extension` files | Write everything in a 2000-line Orchestrator file |
| **Metric** | Calculate from available State data | Secretly query DB in State Getters |
| **Update UI** | Listen to Events to update State | Direct Watch DB Streams |
| **Responsibility** | Parent holds Struct, Child holds Detail | Parent hoards all child data |

---

## 5. Transaction & Saga Pattern

### When to use Saga?
*   **Complex Flows:** When a User action triggers changes across multiple Entities (e.g., "Delete Chamber" -> Evacuate Assets to Deep Storage -> Delete related Hopes -> Delete Chamber).
*   **Fail-Safe:** If step 3 fails, system must Rollback state to original (return Assets, restore Hopes).

### Where to Implement?
Two levels of Saga:

**1. Macro-Saga (Orchestrator Level):**
*   **Scope:** Cross-Domain (multiple Workers).
*   **Logic:** Resides in Orchestrator Scripts.
*   **Example:** Delete Chamber (Asset Worker evacuates -> Hope Worker cleans -> Chamber Worker deletes). If error, Orchestrator commands Assets to return.

**2. Micro-Saga (Worker Level):**
*   **Scope:** Single-Domain (multiple steps in 1 Entity).
*   **Logic:** Resides in Executor process method.
*   **Example:** "Create Chamber Template" (Create Chamber Record -> Create Default Config -> Create Sample Data). If Sample creation fails, Worker must delete the created Chamber Record (DB Transaction rollback).

### Idempotency Rule
*   In Saga environment, Jobs dispatched to Workers should be Idempotent (running twice yields same result) for safe retries.

---

## 6. Ownership & Lifecycle Rules

### Parent Manages Lifecycle
*   **No Suicide:** Child Orchestrator **SHOULD NOT** have a method to delete itself (`delete()`). If an Asset wants to be deleted, it must go through the Chamber.
*   **Reason:** Parent holds the ID list. If Child deletes itself, Parent won't know to update the list -> Data sync error.

### Child Manages State
*   **Update:** Child Orchestrator is responsible for updating its internal fields.
    *   `AssetOrchestrator` -> `update()`, `calculatePnL()`.
*   **Self-Aware:** Child only knows itself, doesn't know about siblings (no `listOthers()` method).

### Parent Manages Query
*   **Listing:** Parent is responsible for listing child IDs.
    *   `Nest` -> `loadChambers()` (List IDs).
    *   `Chamber` -> `loadAssets()` (List IDs or List Entities).

---

## 7. Worker vs. Orchestrator Capabilities

### Worker (Executor) - The Toolset
*   **Full Capabilities:** Worker (e.g., `AssetExecutor`) must support full CRUD and List operations to serve all system needs.
    *   `process(Job.create)` -> OK.
    *   `process(Job.list)` -> OK (Returns List<Asset>).
    *   `process(Job.delete)` -> OK.
*   **No Logic Constraints:** Worker doesn't care who calls it, it executes command and returns data/event.

### Orchestrator - The User
*   **Role-Based Usage:** Orchestrator rights to call Worker are limited by its role (Parent vs Child).
    *   `AssetOrchestrator` (Child): ONLY allowed to call `Job.get`, `Job.update`. MUST NOT call `Job.list`, `Job.delete` (suicide).
    *   `ChamberOrchestrator` (Parent): ALLOWED to call `Job.list` (to get child assets), `Job.delete` (to delete child asset).

---> *Rule: "The Worker must know how to do everything, but the Commander only uses tools appropriate for their rank."*

---

## 8. Event Payload Strategy

### Principle: Smart Events
Event is not just a change signal ("Hey, something changed"), it must carry **Changed Data** ("Hey, Object A changed to this").

### Why?
*   **Avoid Round-Trip:** If Event only carries ID, Orchestrator must dispatch another Job `fetch(id)` to get new data -> 2 steps, UI delay.
*   **Performance:** Reduces DB load (avoids redundant reads).

### Standard Payloads
1.  **CreatedEvent:** Carries **Full Object** just created.
    *   `AssetCreatedEvent(id, Asset object)`
2.  **UpdatedEvent:** Carries **Full Object** after update.
    *   `AssetUpdatedEvent(id, Asset newObject)`
3.  **DeletedEvent:** Carries **ID** (object gone, no data needed).
    *   `AssetDeletedEvent(id)`
4.  **TransactionEvent:** Carries Delta amount and Context (Source/Target).
    *   `AssetTransferredEvent(fromId, toId, amount, hopeId)`

---
*This document is compiled by Antigravity Team.*
