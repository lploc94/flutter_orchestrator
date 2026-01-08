# Orchestrator Core - Audit Checklist

> Danh sách các flow cần audit để đảm bảo chất lượng code trước khi release v1.0.0

## Audit Status

| # | Flow | Status | Issues Found | Commit |
|---|------|--------|--------------|--------|
| 1 | EventJob + Cache Flow | 🔄 In Progress | - | - |
| 2 | Cancellation Token Flow | ⏳ Pending | - | - |
| 3 | Retry Policy Flow | ⏳ Pending | - | - |
| 4 | Offline/NetworkAction Flow | ⏳ Pending | - | - |
| 5 | SignalBus Scoped vs Global | ⏳ Pending | - | - |
| 6 | OrchestratorObserver Flow | ⏳ Pending | - | - |
| 7 | Circuit Breaker (Loop Protection) | ⏳ Pending | - | - |
| 8 | SagaFlow Pattern | ⏳ Pending | - | - |
| 9 | JobHandle Progress Flow | ✅ Done | 3 issues | `dd8287a` |

---

## Audit #1: EventJob + Cache Flow

### Scope
- `EventJob<TResult, TEvent>` class trong `job.dart`
- `_executeEventJob()` method trong `base_executor.dart`
- Cache integration với `CacheProvider`
- SWR (Stale-While-Revalidate) pattern

### Checklist
- [ ] EventJob.createEvent() được gọi đúng timing
- [ ] Cache hit → emit domain event với correlationId đúng
- [ ] Cache miss → execute worker → write cache → emit event
- [ ] SWR: cache hit → emit → continue worker → emit fresh
- [ ] Cache-First: cache hit → emit → STOP (không chạy worker)
- [ ] TTL được truyền đúng khi write cache
- [ ] Handle complete với DataSource đúng (cached/fresh)
- [ ] Error handling khi cache read/write fail

### Files to Review
- `lib/src/models/job.dart` (EventJob class)
- `lib/src/base/base_executor.dart` (_executeEventJob method)
- `lib/src/infra/cache/cache_provider.dart`
- `lib/src/infra/cache/in_memory_cache_provider.dart`

---

## Audit #2: Cancellation Token Flow

### Scope
- `CancellationToken` class
- Token check points trong Executor
- Cleanup khi cancel

### Checklist
- [ ] Token.cancel() propagates correctly
- [ ] throwIfCancelled() checked before process()
- [ ] throwIfCancelled() checked after long operations
- [ ] Listeners cleaned up after job completes
- [ ] CancelledException không bị retry
- [ ] JobCancelledEvent emitted correctly

### Files to Review
- `lib/src/utils/cancellation_token.dart`
- `lib/src/base/base_executor.dart`

---

## Audit #3: Retry Policy Flow

### Scope
- `RetryPolicy` class
- Retry logic trong Executor
- Exponential backoff calculation

### Checklist
- [ ] maxRetries respected
- [ ] delay calculation correct
- [ ] backoffMultiplier applied correctly (1s, 2s, 4s...)
- [ ] retryIf predicate works
- [ ] JobRetryingEvent emitted with correct attempt count
- [ ] Final failure emitted after max retries

### Files to Review
- `lib/src/utils/retry_policy.dart`
- `lib/src/base/base_executor.dart` (_executeWithRetry)

---

## Audit #4: Offline/NetworkAction Flow

### Scope
- `NetworkAction` mixin
- Offline queue management
- Optimistic updates
- Sync when online

### Checklist
- [ ] Job queued when offline
- [ ] Optimistic result returned immediately
- [ ] Queue processed when connectivity restored
- [ ] Poison pill after max retries
- [ ] File cleanup after sync
- [ ] Deduplication by key

### Files to Review
- `lib/src/models/network_action.dart`
- `lib/src/infra/dispatcher.dart`
- `lib/src/infra/offline/offline_manager.dart`

---

## Audit #5: SignalBus Scoped vs Global

### Scope
- Global SignalBus.instance
- Scoped SignalBus.scoped()
- Event isolation

### Checklist
- [ ] Scoped bus isolated from global
- [ ] Job.bus attached correctly by Orchestrator
- [ ] Executor uses correct bus per job
- [ ] Multiple scoped buses don't interfere

### Files to Review
- `lib/src/infra/signal_bus.dart`
- `lib/src/base/base_orchestrator.dart`
- `lib/src/base/base_executor.dart`

---

## Audit #6: OrchestratorObserver Flow

### Scope
- Global observer pattern
- Lifecycle hooks

### Checklist
- [ ] onJobStart called at correct time
- [ ] onJobSuccess called with result and DataSource
- [ ] onJobError called with error and stack
- [ ] onEvent called for domain events
- [ ] Null-safe when no observer set

### Files to Review
- `lib/src/infra/orchestrator_observer.dart`
- `lib/src/base/base_executor.dart`

---

## Audit #7: Circuit Breaker (Loop Protection)

### Scope
- Event rate limiting per type
- Prevent infinite loops

### Checklist
- [ ] Counts reset every second
- [ ] Limit configurable per event type
- [ ] Only blocks specific type, not all events
- [ ] Warning logged when blocked

### Files to Review
- `lib/src/base/base_orchestrator.dart` (_routeEvent)
- `lib/src/utils/logger.dart` (OrchestratorConfig)

---

## Audit #8: SagaFlow Pattern

### Scope
- Multi-step orchestration
- Compensation/rollback on failure

### Checklist
- [ ] Steps execute in order
- [ ] Failure triggers compensation
- [ ] Compensation runs in reverse order
- [ ] Partial completion handled

### Files to Review
- `lib/src/utils/saga_flow.dart`

---

## Completed Audits

### Audit #9: JobHandle Progress Flow ✅

**Date:** 2026-01-08
**Commit:** `dd8287a`

**Issues Found:**
1. Race condition khi subscribe progress (late subscribers miss early updates)
2. Broadcast stream không có buffer/replay
3. Progress stream close quá sớm (trước khi events flush)
4. Không có cách query current progress synchronously

**Fixes Applied:**
- Added `_lastProgress` field for replay
- Changed `progress` getter to `async*` generator with replay
- Added `currentProgress` and `progressValue` getters
- Added 10ms delay before `dispose()` to allow events to flush
