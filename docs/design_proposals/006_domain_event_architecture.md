# RFC 006: Domain Event Architecture v3

**Status**: ✅ Implemented
**Version**: 0.6.0
**Context**: Simplify event system - remove framework events, use domain events only

---

## 1. Problem Statement

Framework v0.5.x has too many event types (framework + domain):
- `JobSuccessEvent`, `JobFailureEvent`, `JobCacheHitEvent`, etc.
- Complex Active/Passive hooks in Orchestrator
- Hard to debug, hard to understand flow

**Goal**: Use only domain events defined by Jobs themselves.

---

## 2. Research Summary

### 2.1. Command/Handler Pattern (CQRS)

```dart
// Command with result type
abstract class Command<TResult> {}

// Handler knows command type and result type
abstract class CommandHandler<TCommand extends Command<TResult>, TResult> {
  Future<TResult> handle(TCommand command);
}

// Dispatcher uses Map<Type, Handler>
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

**Key insight**: Type inference works at REGISTER time, not dispatch time.

### 2.2. Result/Either Pattern

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

// Pattern matching (Dart 3)
final result = createUser('John');
switch (result) {
  case Ok(:final value): print('User: $value');
  case Err(:final error): print('Error: $error');
}
```

### 2.3. Dart Type Inference Limitations

**Dart CANNOT infer return type from parameter type**:

```dart
// ❌ Does not work as expected
T dispatch<T>(Command<T> command) {
  // Dart cannot infer T from command
}

final result = dispatch(CreateUserCommand());  // result is dynamic!
```

**Solutions**:
1. **Explicit type**: `dispatch<User>(CreateUserCommand())`
2. **Runtime cast**: Cast internally in dispatcher
3. **Type from Handler**: Register handler with type, dispatch looks up handler

---

## 3. Chosen Approach: Hybrid (Option A + C)

Combines:
- **Job<TResult, TEvent>**: Type-safe, Job knows result type
- **Executor inference**: Executor infers types from Job when processing

---

## 4. Core Design

### 4.1. BaseEvent (Minimal)

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
}
```

### 4.2. DataSource

```dart
enum DataSource { fresh, cached, optimistic }
```

### 4.3. Job Hierarchy

```dart
/// Base job - all jobs inherit from this
abstract class BaseJob {
  final String id;
  BaseJob({String? id}) : id = id ?? generateJobId();
}

/// Job capable of emitting events
/// TResult: Data type returned by worker
/// TEvent: Event type to emit
abstract class EventJob<TResult, TEvent extends BaseEvent> extends BaseJob {
  EventJob({super.id});

  /// Create event from result - correlationId = job.id
  TEvent createEvent(TResult result);

  /// Cache key (null = no caching)
  String? get cacheKey => null;

  /// Cache TTL
  Duration? get cacheTtl => null;

  /// SWR: Revalidate after cache hit?
  bool get revalidate => false;
}
```

### 4.4. Example Jobs

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
  // No caching for mutations
}
```

### 4.5. JobHandle

```dart
class JobHandle<T> {
  final String jobId;

  final Completer<JobResult<T>> _completer = Completer();
  final StreamController<JobProgress> _progress = StreamController.broadcast();

  Future<JobResult<T>> get future => _completer.future;
  Stream<JobProgress> get progress => _progress.stream;
  bool get isCompleted => _completer.isCompleted;

  JobHandle(this.jobId) {
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

## 5. Executor Design

### 5.1. BaseExecutor

```dart
abstract class BaseExecutor<TJob extends BaseJob> {
  final SignalBus _bus;
  final CacheProvider _cache;

  BaseExecutor({SignalBus? bus, CacheProvider? cache})
      : _bus = bus ?? SignalBus.instance,
        _cache = cache ?? OrchestratorConfig.cacheProvider;

  /// Override to implement business logic
  Future<dynamic> process(TJob job);

  /// Entry point - called by Dispatcher
  Future<void> execute(TJob job, {JobHandle? handle}) async {
    try {
      if (job is EventJob) {
        await _executeEventJob(job, handle);
      } else {
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
        final event = job.createEvent(cached);
        _bus.emit(event);
        handle?.complete(cached, DataSource.cached);

        if (!job.revalidate) return;
      }
    }

    // 2. Execute worker
    final result = await process(job as TJob);

    // 3. Cache result
    if (cacheKey != null) {
      await _cache.write(cacheKey, result, ttl: job.cacheTtl);
    }

    // 4. Create & emit event
    final event = job.createEvent(result);
    _bus.emit(event);

    // 5. Complete handle
    handle?.complete(result, DataSource.fresh);
  }
}
```

### 5.2. Example Executor

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

## 6. Orchestrator Design

### 6.1. BaseOrchestrator (Simplified)

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

  /// Override to handle domain events
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

### 6.2. Example Orchestrator

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

## 7. UI Usage Pattern

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

---

## 8. Breaking Changes Summary

| Component | v0.5.x | v0.6.0 |
|-----------|--------|--------|
| **Events** | Framework + Domain | Domain only |
| **Cache** | Raw data | Raw data (unchanged) |
| **Event creation** | Executor emits JobSuccessEvent | Job.createEvent() emits domain event |
| **JobHandle** | Returns data | Returns JobResult(data, source) |
| **Progress** | JobProgressEvent | handle.progress stream |
| **Orchestrator** | Active/Passive hooks | Single onEvent() |

---

## 9. Deleted Framework Events

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

---

## 10. Deleted Orchestrator Hooks

```dart
// DELETE these methods:
- onActiveSuccess()
- onActiveFailure()
- onActiveCancelled()
- onActiveTimeout()
- onActiveEvent()
- onPassiveEvent()  // renamed to onEvent()
- onProgress()
- onJobStarted()
- onJobRetrying()
- _handleActiveEvent()
- _handlePassiveEvent()
- _activeJobIds tracking
- _activeJobTypes tracking
```

---

## 11. Migration Guide

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

### After (v0.6.0)

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

## 12. Implementation Checklist

- [x] Simplify BaseEvent (remove framework fields)
- [x] Add EventJob<TResult, TEvent> class
- [x] Add JobResult<T> wrapper
- [x] Add JobProgress class
- [x] Update JobHandle with progress stream
- [x] Update BaseExecutor to handle EventJob
- [x] Simplify BaseOrchestrator (single onEvent)
- [x] Remove framework event classes
- [x] Remove Active/Passive distinction
- [x] Update all tests
- [x] Migration guide
