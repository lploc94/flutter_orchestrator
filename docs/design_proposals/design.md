# Domain Event Architecture v3 - Part 1: Research & Patterns

## Research Summary

### 1. Command/Handler Pattern (CQRS)

Dart community dùng pattern này cho type-safe command handling:

```dart
// Command với result type
abstract class Command<TResult> {}

// Handler biết command type và result type
abstract class CommandHandler<TCommand extends Command<TResult>, TResult> {
  Future<TResult> handle(TCommand command);
}

// Dispatcher dùng Map<Type, Handler>
class Dispatcher {
  final Map<Type, dynamic> _handlers = {};

  void register<TCommand extends Command<TResult>, TResult>(
    CommandHandler<TCommand, TResult> handler
  ) {
    _handlers[TCommand] = handler;
  }

  Future<TResult> dispatch<TResult>(Command<TResult> command) async {
    final handler = _handlers[command.runtimeType];
    return await handler.handle(command);
  }
}
```

**Key insight**: Type inference hoạt động khi REGISTER handler, không phải khi dispatch.

---

### 2. Result/Either Pattern

Thay vì throw exception, return explicit Result:

```dart
sealed class Result<T, E> {
  const Result();
}

final class Ok<T, E> extends Result<T, E> {
  final T value;
  const Ok(this.value);
}

final class Err<T, E> extends Result<T, E> {
  final E error;
  const Err(this.error);
}

// Usage
Result<User, String> createUser(String name) {
  if (name.isEmpty) return Err('Name cannot be empty');
  return Ok(User(name: name));
}

// Pattern matching (Dart 3)
final result = createUser('John');
switch (result) {
  case Ok(:final value): print('User: $value');
  case Err(:final error): print('Error: $error');
}
```

---

### 3. Dart Type Inference Limitations

**Dart CANNOT infer return type from parameter type**:

```dart
// ❌ Không hoạt động như mong đợi
T dispatch<T>(Command<T> command) {
  // Dart không infer T từ command
}

final result = dispatch(CreateUserCommand());  // result là dynamic!
```

**Solutions**:
1. **Explicit type**: `dispatch<User>(CreateUserCommand())`
2. **Runtime cast**: Cast internally trong dispatcher
3. **Type từ Handler**: Register handler với type, dispatch lookup handler

---

## Applying to Our Architecture

### Option A: Job<TResult, TEvent> Pattern

```dart
abstract class Job<TResult, TEvent extends BaseEvent> extends BaseJob {
  TEvent createEvent(TResult result);
}

class LoadUsersJob extends Job<List<User>, UsersLoadedEvent> {
  @override
  UsersLoadedEvent createEvent(List<User> result) {
    return UsersLoadedEvent(correlationId: id, users: result);
  }
}
```

**Pro**: Type-safe, compiler biết TResult và TEvent
**Con**: Verbose khi dispatch: `dispatch<List<User>, UsersLoadedEvent>(job)`

---

### Option B: Job với Type Erasure + Runtime Cast

```dart
abstract class EventEmittingJob extends BaseJob {
  BaseEvent createEvent(dynamic result);
  Type get resultType;
}

class LoadUsersJob extends EventEmittingJob {
  @override
  Type get resultType => List<User>;

  @override
  UsersLoadedEvent createEvent(dynamic result) {
    return UsersLoadedEvent(
      correlationId: id,
      users: result as List<User>,
    );
  }
}
```

**Pro**: Simple dispatch: `dispatch(job)`
**Con**: Runtime cast, không type-safe

---

### Option C: Typed Job Registry (CQRS-style) ⭐ RECOMMENDED

```dart
// Job chỉ define input, không có TResult
abstract class BaseJob {
  String get id;
}

// Executor biết Job type và Result type
abstract class JobExecutor<TJob extends BaseJob, TResult, TEvent extends BaseEvent> {
  Future<TResult> process(TJob job);
  TEvent createEvent(TJob job, TResult result);
  String? getCacheKey(TJob job) => null;
}

// Register executor với type
dispatcher.register<LoadUsersJob, List<User>, UsersLoadedEvent>(
  LoadUsersExecutor()
);

// Dispatch - type từ registered executor
final handle = dispatcher.dispatch(LoadUsersJob());
```

**Pro**:
- Type-safe tại registration time
- Simple dispatch syntax
- Follows CQRS pattern (Job = Command, Executor = Handler)

**Con**:
- Executor và Job tách biệt
- Cần register mỗi cặp Job-Executor
# Domain Event Architecture v3 - Part 2: Final Design

## Chosen Approach: Hybrid (Option A + C)

Kết hợp:
- **Job<TResult, TEvent>**: Type-safe, Job biết result type
- **Executor inference**: Executor infer types từ Job khi process

---

## Core Design

### 1. BaseEvent (Minimal)

```dart
abstract class BaseEvent {
  final String id;
  final String correlationId;
  final DateTime timestamp;

  String get eventType => runtimeType.toString();

  BaseEvent({
    String? id,
    required this.correlationId,
    DateTime? timestamp,
  })  : id = id ?? _generateId(),
        timestamp = timestamp ?? DateTime.now();

  static String _generateId() =>
    '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(0xFFFFFF).toRadixString(16)}';
}
```

### 2. DataSource

```dart
enum DataSource { fresh, cached, optimistic }
```

### 3. Job Hierarchy

```dart
/// Base job - tất cả jobs kế thừa
abstract class BaseJob {
  final String id;
  BaseJob({String? id}) : id = id ?? generateJobId();
}

/// Job có khả năng emit event
/// TResult: Kiểu dữ liệu worker trả về
/// TEvent: Kiểu event được emit
abstract class EventJob<TResult, TEvent extends BaseEvent> extends BaseJob {
  EventJob({super.id});

  /// Tạo event từ result - correlationId = job.id
  TEvent createEvent(TResult result);

  /// Cache key (null = không cache)
  String? get cacheKey => null;

  /// Cache TTL
  Duration? get cacheTtl => null;

  /// SWR: Có revalidate sau cache hit?
  bool get revalidate => false;
}
```

### 4. Example Jobs

```dart
class LoadUsersJob extends EventJob<List<User>, UsersLoadedEvent> {
  LoadUsersJob() : super(id: generateJobId('load_users'));

  @override
  UsersLoadedEvent createEvent(List<User> result) {
    return UsersLoadedEvent(correlationId: id, users: result);
  }

  @override
  String? get cacheKey => 'users_list';

  @override
  Duration? get cacheTtl => Duration(minutes: 5);

  @override
  bool get revalidate => true;
}

class CreateUserJob extends EventJob<User, UserCreatedEvent> {
  final String name;
  final String email;

  CreateUserJob({required this.name, required this.email});

  @override
  UserCreatedEvent createEvent(User result) {
    return UserCreatedEvent(
      correlationId: id,
      userId: result.id,
      name: result.name,
      email: result.email,
    );
  }
  // Không cache mutation
}
```

### 5. JobHandle

```dart
class JobHandle<T> {
  final String jobId;

  final Completer<JobResult<T>> _completer = Completer();
  final StreamController<JobProgress> _progress = StreamController.broadcast();

  Future<JobResult<T>> get future => _completer.future;
  Stream<JobProgress> get progress => _progress.stream;
  bool get isCompleted => _completer.isCompleted;

  JobHandle(this.jobId) {
    // Prevent uncaught async error
    _completer.future.ignore();
  }

  void complete(T data, DataSource source) {
    if (!_completer.isCompleted) {
      _completer.complete(JobResult(data: data, source: source));
    }
  }

  void completeError(Object error, [StackTrace? stackTrace]) {
    if (!_completer.isCompleted) {
      _completer.completeError(error, stackTrace);
    }
  }

  void reportProgress(double value, {String? message}) {
    if (!_progress.isClosed) {
      _progress.add(JobProgress(value, message));
    }
  }

  void _dispose() {
    _progress.close();
  }
}

class JobResult<T> {
  final T data;
  final DataSource source;

  const JobResult({required this.data, required this.source});

  bool get isCached => source == DataSource.cached;
  bool get isFresh => source == DataSource.fresh;
  bool get isOptimistic => source == DataSource.optimistic;
}

class JobProgress {
  final double value;
  final String? message;
  const JobProgress(this.value, [this.message]);
}
```

---

## Executor Design

### BaseExecutor

```dart
abstract class BaseExecutor<TJob extends BaseJob> {
  final SignalBus _bus;
  final CacheProvider _cache;

  BaseExecutor({SignalBus? bus, CacheProvider? cache})
      : _bus = bus ?? SignalBus.instance,
        _cache = cache ?? OrchestratorConfig.cacheProvider;

  /// Override này để implement business logic
  Future<dynamic> process(TJob job);

  /// Entry point - được gọi bởi Dispatcher
  Future<void> execute(TJob job, {JobHandle? handle}) async {
    try {
      // Handle EventJob với cache + event emission
      if (job is EventJob) {
        await _executeEventJob(job, handle);
      } else {
        // Regular job - không cache, không event
        final result = await process(job);
        handle?.complete(result, DataSource.fresh);
      }
    } catch (e, stack) {
      handle?.completeError(e, stack);
      rethrow;
    } finally {
      handle?._dispose();
    }
  }

  Future<void> _executeEventJob(EventJob job, JobHandle? handle) async {
    final cacheKey = job.cacheKey;

    // 1. Check cache
    if (cacheKey != null) {
      final cached = await _cache.read(cacheKey);
      if (cached != null) {
        // Recreate event với correlationId MỚI (job hiện tại)
        final event = job.createEvent(cached);
        _bus.emit(event);
        handle?.complete(cached, DataSource.cached);

        // SWR: không revalidate thì stop
        if (!job.revalidate) return;
        // Else: continue, handle đã complete
      }
    }

    // 2. Execute worker
    final result = await process(job as TJob);

    // 3. Cache result (data, không phải event)
    if (cacheKey != null) {
      await _cache.write(cacheKey, result, ttl: job.cacheTtl);
    }

    // 4. Create & emit event
    final event = job.createEvent(result);
    _bus.emit(event);

    // 5. Complete handle (nếu chưa complete bởi cache)
    handle?.complete(result, DataSource.fresh);
  }
}
```

### Example Executor

```dart
class UserExecutor extends BaseExecutor<BaseJob> {
  final UserRepository _repo;

  UserExecutor(this._repo);

  @override
  Future<dynamic> process(BaseJob job) async {
    return switch (job) {
      LoadUsersJob() => await _repo.getUsers(),
      CreateUserJob j => await _repo.createUser(j.name, j.email),
      DeleteUserJob j => await _repo.deleteUser(j.userId),
      _ => throw UnimplementedError('Unknown job: $job'),
    };
  }
}
```

---

## Orchestrator Design

### BaseOrchestrator (Simplified)

```dart
abstract class BaseOrchestrator<S> {
  S _state;
  final SignalBus _bus;
  final Dispatcher _dispatcher;
  final StreamController<S> _stateController = StreamController.broadcast();
  StreamSubscription? _subscription;

  BaseOrchestrator(this._state, {SignalBus? bus, Dispatcher? dispatcher})
      : _bus = bus ?? SignalBus.instance,
        _dispatcher = dispatcher ?? Dispatcher() {
    _stateController.add(_state);
    _subscription = _bus.stream.listen(_onBusEvent);
  }

  S get state => _state;
  Stream<S> get stream => _stateController.stream;

  void _onBusEvent(BaseEvent event) {
    try {
      onEvent(event);
    } catch (e, stack) {
      OrchestratorConfig.logger.error('Error in onEvent', e, stack);
    }
  }

  /// Override để handle domain events
  @protected
  void onEvent(BaseEvent event) {}

  /// Emit new state
  @protected
  void emit(S newState) {
    if (_stateController.isClosed) return;
    _state = newState;
    _stateController.add(newState);
  }

  /// Dispatch job
  @protected
  JobHandle<T> dispatch<T>(BaseJob job) {
    final handle = JobHandle<T>(job.id);
    job.bus = _bus;
    _dispatcher.dispatch(job, handle: handle);
    return handle;
  }

  @mustCallSuper
  void dispose() {
    _subscription?.cancel();
    _stateController.close();
  }
}
```

### Example Orchestrator

```dart
class UserOrchestrator extends BaseOrchestrator<UserState> {
  UserOrchestrator() : super(UserState.initial());

  @override
  void onEvent(BaseEvent event) {
    switch (event) {
      case UsersLoadedEvent e:
        emit(state.copyWith(users: e.users));
      case UserCreatedEvent e:
        emit(state.copyWith(
          users: [...state.users, User(id: e.userId, name: e.name, email: e.email)]
        ));
      case UserDeletedEvent e:
        emit(state.copyWith(
          users: state.users.where((u) => u.id != e.userId).toList()
        ));
    }
  }

  // Fire and forget
  void loadUsers() {
    dispatch<List<User>>(LoadUsersJob());
  }

  // Await result
  Future<User> createUser(String name, String email) async {
    final handle = dispatch<User>(CreateUserJob(name: name, email: email));
    final result = await handle.future;
    return result.data;
  }

  // With progress
  Future<void> uploadFile(File file) async {
    final handle = dispatch<void>(UploadFileJob(file: file));

    handle.progress.listen((p) {
      emit(state.copyWith(uploadProgress: p.value));
    });

    await handle.future;
  }
}
```

---

## UI Usage Pattern

```dart
class UserScreen extends StatefulWidget {
  @override
  _UserScreenState createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  final _orchestrator = UserOrchestrator();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);

    final handle = _orchestrator.dispatch<List<User>>(LoadUsersJob());

    try {
      final result = await handle.future;

      if (result.isCached) {
        // Optionally show indicator that data is from cache
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Showing cached data...')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserState>(
      stream: _orchestrator.stream,
      initialData: _orchestrator.state,
      builder: (context, snapshot) {
        final state = snapshot.data!;

        if (_isLoading && state.users.isEmpty) {
          return Center(child: CircularProgressIndicator());
        }

        return ListView.builder(
          itemCount: state.users.length,
          itemBuilder: (context, index) {
            final user = state.users[index];
            return ListTile(title: Text(user.name));
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _orchestrator.dispose();
    super.dispose();
  }
}
```
# Domain Event Architecture v3 - Part 3: Implementation Plan

## Summary of Changes

| Component | Current | New |
|-----------|---------|-----|
| **Events** | Framework + Domain | Domain only |
| **Cache** | Raw data | Raw data (unchanged) |
| **Event creation** | Executor emits JobSuccessEvent | Job.createEvent() emits domain event |
| **JobHandle** | Returns data | Returns JobResult(data, source) |
| **Progress** | JobProgressEvent | handle.progress stream |
| **Orchestrator** | Active/Passive hooks | Single onEvent() |

---

## Files to DELETE

### Events (lib/src/models/event.dart)
```dart
// DELETE these classes:
- JobSuccessEvent
- JobFailureEvent
- JobCacheHitEvent
- JobPlaceholderEvent
- JobStartedEvent
- JobProgressEvent
- JobCancelledEvent
- JobTimeoutEvent
- JobRetryingEvent
```

### Orchestrator hooks (lib/src/base/base_orchestrator.dart)
```dart
// DELETE these methods:
- onActiveSuccess()
- onActiveFailure()
- onActiveCancelled()
- onActiveTimeout()
- onActiveEvent()
- onPassiveEvent()  // rename to onEvent()
- onProgress()
- onJobStarted()
- onJobRetrying()
- _handleActiveEvent()
- _handlePassiveEvent()
- _activeJobIds tracking
- _activeJobTypes tracking
```

---

## Files to MODIFY

### 1. lib/src/models/event.dart
- Keep only BaseEvent
- Simplify BaseEvent fields

### 2. lib/src/models/job.dart
- Add EventJob<TResult, TEvent> class

### 3. lib/src/models/job_handle.dart
- Add progress stream
- Return JobResult instead of raw data
- Add JobProgress class
- Add JobResult class

### 4. lib/src/models/data_source.dart
- Already exists, keep as is

### 5. lib/src/base/base_executor.dart
- Update execute() flow
- Handle EventJob specially
- Cache data, recreate event

### 6. lib/src/base/base_orchestrator.dart
- Remove Active/Passive
- Single onEvent() method
- Simplify dispatch()

### 7. lib/src/infra/dispatcher.dart
- Update dispatch signature if needed

---

## Files to CREATE

None - all changes fit in existing files

---

## Implementation Phases

### Phase 1: Add New Classes (Non-breaking)
1. Add `EventJob<TResult, TEvent>` to job.dart
2. Add `JobResult<T>` to job_handle.dart
3. Add `JobProgress` to job_handle.dart
4. Update `JobHandle` with progress stream

### Phase 2: Update Executor
1. Update execute() to handle EventJob
2. Cache data, create event on cache hit
3. Support SWR via job.revalidate

### Phase 3: Update Orchestrator
1. Add onEvent() method
2. Remove Active/Passive distinction
3. Simplify internal routing

### Phase 4: Cleanup (Breaking)
1. Delete framework events
2. Delete old hooks
3. Update all tests

---

## Test Cases

### EventJob Tests
```dart
test('EventJob.createEvent creates correct event', () {
  final job = LoadUsersJob();
  final users = [User(id: '1', name: 'John')];
  final event = job.createEvent(users);

  expect(event, isA<UsersLoadedEvent>());
  expect(event.correlationId, equals(job.id));
  expect(event.users, equals(users));
});
```

### Cache + Event Tests
```dart
test('Cache hit emits event with new correlationId', () async {
  // Setup: Pre-populate cache
  await cache.write('users', [User(id: '1', name: 'John')]);

  // Execute
  final job = LoadUsersJob();
  executor.execute(job, handle: handle);

  // Verify: Event has job's correlationId, not old one
  final emittedEvent = await bus.stream.first;
  expect(emittedEvent.correlationId, equals(job.id));
});

test('SWR: Cache hit completes handle, then worker emits fresh', () async {
  // Setup
  await cache.write('users', [cachedUser]);
  final job = LoadUsersJob(); // revalidate = true

  // Execute
  executor.execute(job, handle: handle);

  // Verify: Handle completes with cached
  final result1 = await handle.future;
  expect(result1.source, equals(DataSource.cached));

  // Verify: Fresh event emitted later
  final events = await bus.stream.take(2).toList();
  expect(events[0].users, equals([cachedUser]));  // cached
  expect(events[1].users, equals([freshUser]));   // fresh
});
```

### Orchestrator Tests
```dart
test('onEvent receives all domain events', () async {
  final events = <BaseEvent>[];
  orchestrator.onEvent = (e) => events.add(e);

  // Dispatch from this orchestrator
  orchestrator.dispatch(LoadUsersJob());

  // Emit from another source
  bus.emit(UserCreatedEvent(...));

  await Future.delayed(Duration(milliseconds: 50));

  expect(events.length, equals(2));
  expect(events[0], isA<UsersLoadedEvent>());
  expect(events[1], isA<UserCreatedEvent>());
});
```

### JobHandle Progress Tests
```dart
test('handle.progress receives progress updates', () async {
  final handle = JobHandle<void>('test');
  final progressValues = <double>[];

  handle.progress.listen((p) => progressValues.add(p.value));

  handle.reportProgress(0.25);
  handle.reportProgress(0.50);
  handle.reportProgress(1.0);

  await Future.delayed(Duration(milliseconds: 10));

  expect(progressValues, equals([0.25, 0.50, 1.0]));
});
```

---

## Migration Guide for Users

### Before (v0.5.x)
```dart
class MyOrchestrator extends BaseOrchestrator<MyState> {
  @override
  void onActiveSuccess(JobSuccessEvent event) {
    final data = event.data;
    if (data is List<User>) {
      emit(state.copyWith(users: data));
    }
  }

  @override
  void onPassiveEvent(BaseEvent event) {
    if (event is UserCreatedEvent) {
      emit(state.copyWith(users: [...state.users, event.user]));
    }
  }

  void loadUsers() {
    dispatch(LoadUsersJob());
  }
}

// Job
class LoadUsersJob extends BaseJob {
  LoadUsersJob() : super(id: generateJobId());
}
```

### After (v1.0.0)
```dart
class MyOrchestrator extends BaseOrchestrator<MyState> {
  @override
  void onEvent(BaseEvent event) {
    switch (event) {
      case UsersLoadedEvent e:
        emit(state.copyWith(users: e.users));
      case UserCreatedEvent e:
        emit(state.copyWith(users: [...state.users, e.user]));
    }
  }

  void loadUsers() {
    dispatch<List<User>>(LoadUsersJob());
  }
}

// Job - now with event creation
class LoadUsersJob extends EventJob<List<User>, UsersLoadedEvent> {
  LoadUsersJob() : super(id: generateJobId());

  @override
  UsersLoadedEvent createEvent(List<User> result) {
    return UsersLoadedEvent(correlationId: id, users: result);
  }

  @override
  String? get cacheKey => 'users_list';
}
```

---

## Version Bump

Current: 0.5.2
New: **1.0.0** (Major breaking change)
