# Kiến Trúc Orchestrator Core

> Tài liệu kỹ thuật chi tiết của orchestrator_core v1.0.0 với Domain Event Architecture v3

## Mục Lục

1. [Tổng Quan](#tổng-quan)
2. [Các Thành Phần Chính](#các-thành-phần-chính)
3. [Luồng Dữ Liệu](#luồng-dữ-liệu)
4. [Vòng Đời Job](#vòng-đời-job)
5. [Hệ Thống Event](#hệ-thống-event)
6. [Tính Năng Nâng Cao](#tính-năng-nâng-cao)

---

## Tổng Quan

Orchestrator Pattern tách biệt **làm gì** (Jobs) khỏi **làm như thế nào** (Executors), với **Dispatcher** trung tâm định tuyến jobs và **SignalBus** cho giao tiếp dựa trên sự kiện.


```mermaid
graph TB
    subgraph "Tầng UI"
        UI[Flutter Widget]
    end

    subgraph "Tầng Điều Phối"
        O[Orchestrator<br/>Quản lý State]
        JH[JobHandle&lt;T&gt;<br/>Future + Progress]
    end

    subgraph "Tầng Dispatch"
        D[Dispatcher<br/>Định tuyến Job]
    end

    subgraph "Tầng Thực Thi"
        E1[Executor A]
        E2[Executor B]
        E3[Executor C]
    end

    subgraph "Hạ Tầng"
        SB[SignalBus<br/>Phát sóng Event]
        OBS[OrchestratorObserver<br/>Logging toàn cục]
    end

    UI -->|"ref.watch(state)"| O
    UI -->|"dispatch(Job)"| O
    O -->|"dispatch(Job)"| D
    O -.->|"trả về"| JH
    D -->|"định tuyến theo type"| E1
    D -->|"định tuyến theo type"| E2
    D -->|"định tuyến theo type"| E3
    E1 -->|"emit events"| SB
    E2 -->|"emit events"| SB
    E3 -->|"emit events"| SB
    SB -->|"broadcast"| O
    E1 -.->|"lifecycle hooks"| OBS
    E2 -.->|"lifecycle hooks"| OBS
    E3 -.->|"lifecycle hooks"| OBS

    style O fill:#4CAF50,color:#fff
    style D fill:#2196F3,color:#fff
    style SB fill:#FF9800,color:#fff
    style JH fill:#9C27B0,color:#fff
```


---

## Các Thành Phần Chính

### 1. BaseJob

Đối tượng command bất biến mô tả **cần làm gì**.

```dart
// Job đơn giản
class LoadUsersJob extends BaseJob {
  LoadUsersJob() : super(id: generateJobId('load_users'));
}

// Job có tham số
class CreateUserJob extends BaseJob {
  final String name;
  final String email;
  
  CreateUserJob({required this.name, required this.email})
    : super(id: generateJobId('create_user'));
}
```

#### EventJob (v1.0.0+)

Jobs tự động emit domain events khi hoàn thành:

```dart
class LoadUsersJob extends EventJob<List<User>, UsersLoadedEvent> {
  @override
  UsersLoadedEvent createEventTyped(List<User> result) {
    return UsersLoadedEvent(correlationId: id, users: result);
  }
  
  @override
  String? get cacheKey => 'users_list';
  
  @override
  Duration? get cacheTtl => Duration(minutes: 5);
}
```


### 2. BaseExecutor

Xử lý thực thi job với hỗ trợ sẵn cho timeout, retry, cancellation và progress.

```dart
class LoadUsersExecutor extends BaseExecutor<LoadUsersJob> {
  final UserRepository _repo;
  
  LoadUsersExecutor(this._repo);
  
  @override
  Future<List<User>> process(LoadUsersJob job) async {
    // Báo cáo tiến độ
    emitProgress(job.id, progress: 0.3, message: 'Đang tải...');
    
    final users = await _repo.getAll();
    
    emitProgress(job.id, progress: 1.0, message: 'Hoàn tất');
    return users;
  }
}
```

#### Vòng Đời Executor

```mermaid
stateDiagram-v2
    [*] --> Received: Job được dispatch
    Received --> Started: Bắt đầu thực thi
    Started --> Processing: process() được gọi
    
    Processing --> Success: Trả về kết quả
    Processing --> Failure: Ném exception
    Processing --> Cancelled: Token bị hủy
    Processing --> Timeout: Vượt thời gian
    
    Success --> [*]: Emit success event
    Failure --> Retrying: Có retry policy
    Failure --> [*]: Emit failure event
    Retrying --> Processing: Thử lại
    Cancelled --> [*]: Emit cancelled event
    Timeout --> [*]: Emit timeout event
```


### 3. Dispatcher

Định tuyến jobs đến executors đã đăng ký. Sử dụng Singleton pattern.

```dart
// Đăng ký (thường trong khởi tạo app)
final dispatcher = Dispatcher();
dispatcher.register<LoadUsersJob>(LoadUsersExecutor(repo));
dispatcher.register<CreateUserJob>(CreateUserExecutor(repo));

// Dispatch (nội bộ - được gọi bởi Orchestrator)
dispatcher.dispatch(job, handle: jobHandle);
```

```mermaid
flowchart LR
    subgraph "Dispatcher Registry"
        R["Map&lt;Type, Executor&gt;"]
    end
    
    J1[LoadUsersJob] --> R
    J2[CreateUserJob] --> R
    J3[DeleteUserJob] --> R
    
    R --> E1[LoadUsersExecutor]
    R --> E2[CreateUserExecutor]
    R --> E3[DeleteUserExecutor]
    
    style R fill:#2196F3,color:#fff
```


### 4. BaseOrchestrator

"Bộ Não Phản Ứng" - quản lý state và phản ứng với domain events.

```dart
class UserOrchestrator extends BaseOrchestrator<UserState> {
  UserOrchestrator() : super(UserState.initial());
  
  // Dispatch jobs
  JobHandle<List<User>> loadUsers() {
    return dispatch<List<User>>(LoadUsersJob());
  }
  
  // Phản ứng với TẤT CẢ events qua một handler duy nhất
  @override
  void onEvent(BaseEvent event) {
    switch (event) {
      case UsersLoadedEvent e:
        emit(state.copyWith(users: e.users));
      case UserCreatedEvent e:
        emit(state.copyWith(users: [...state.users, e.user]));
      case UserDeletedEvent e:
        emit(state.copyWith(
          users: state.users.where((u) => u.id != e.userId).toList()
        ));
    }
  }
}
```


### 5. SignalBus

Event bus phát sóng cho giao tiếp tách rời. Hỗ trợ cả global và scoped instances.

```dart
// Global bus (mặc định)
final globalBus = SignalBus.instance;

// Scoped bus (cho testing hoặc cách ly)
final scopedBus = SignalBus.scoped();

// Lắng nghe events
bus.listen((event) {
  print('Nhận được: $event');
});

// Emit events
bus.emit(UserCreatedEvent(correlationId: jobId, user: newUser));
```

```mermaid
flowchart TB
    subgraph "Global Scope"
        GB[SignalBus.instance]
        O1[Orchestrator 1]
        O2[Orchestrator 2]
        E1[Executor 1]
        E2[Executor 2]
    end
    
    subgraph "Scoped (Test)"
        SB[SignalBus.scoped]
        TO[Test Orchestrator]
        TE[Test Executor]
    end
    
    E1 -->|emit| GB
    E2 -->|emit| GB
    GB -->|broadcast| O1
    GB -->|broadcast| O2
    
    TE -->|emit| SB
    SB -->|broadcast| TO
    
    GB x--x SB
    
    style GB fill:#FF9800,color:#fff
    style SB fill:#9C27B0,color:#fff
```


### 6. JobHandle

Đại diện cho một job đang chạy với kết quả future và theo dõi tiến độ.

```dart
// Fire and forget (chạy rồi quên)
orchestrator.loadUsers();

// Chờ kết quả
final handle = orchestrator.loadUsers();
final result = await handle.future;
print(result.data);        // List<User>
print(result.source);      // DataSource.fresh | cached | optimistic

// Theo dõi tiến độ
handle.progress.listen((p) {
  print('${p.value * 100}% - ${p.message}');
});
```

```mermaid
classDiagram
    class JobHandle~T~ {
        +String jobId
        +Future~JobHandleResult~T~~ future
        +Stream~JobProgress~ progress
        +bool isCompleted
        +complete(T data, DataSource source)
        +completeError(Object error)
        +reportProgress(double value, String? message)
    }
    
    class JobHandleResult~T~ {
        +T data
        +DataSource source
        +bool isCached
        +bool isFresh
        +bool isOptimistic
    }
    
    class JobProgress {
        +double value
        +String? message
        +int? currentStep
        +int? totalSteps
    }
    
    class DataSource {
        <<enumeration>>
        fresh
        cached
        optimistic
    }
    
    JobHandle --> JobHandleResult : hoàn thành với
    JobHandle --> JobProgress : emit
    JobHandleResult --> DataSource : có
```


---

## Luồng Dữ Liệu

### Luồng Thực Thi Job Hoàn Chỉnh

```mermaid
sequenceDiagram
    autonumber
    participant UI as Flutter UI
    participant O as Orchestrator
    participant D as Dispatcher
    participant E as Executor
    participant SB as SignalBus
    participant OBS as Observer
    
    UI->>O: dispatch(LoadUsersJob)
    activate O
    O->>O: Tạo JobHandle<T>
    O->>O: Theo dõi job ID
    O->>D: dispatch(job, handle)
    deactivate O
    O-->>UI: trả về JobHandle
    
    activate D
    D->>D: Tìm executor theo job type
    D->>E: execute(job, handle)
    deactivate D
    
    activate E
    E->>OBS: onJobStart(job)
    E->>E: Kiểm tra cancellation token
    E->>E: process(job)
    
    alt Thành công
        E->>OBS: onJobSuccess(job, result, source)
        E->>SB: emit(JobSuccessEvent)
        E->>E: handle.complete(result, source)
    else Thất bại
        E->>OBS: onJobError(job, error, stack)
        E->>SB: emit(JobFailureEvent)
        E->>E: handle.completeError(error)
    end
    deactivate E
    
    activate SB
    SB->>O: broadcast event
    deactivate SB
    
    activate O
    O->>O: onEvent(event)
    O->>O: emit(newState)
    O->>O: Dọn dẹp job tracking
    deactivate O
    
    UI->>UI: Rebuild với state mới
```


### Luồng EventJob (Domain Events)

```mermaid
sequenceDiagram
    autonumber
    participant O as Orchestrator
    participant E as Executor
    participant SB as SignalBus
    
    O->>E: execute(EventJob)
    activate E
    
    Note over E: Kiểm tra cache
    alt Cache Hit
        E->>SB: emit(job.createEvent(cachedData))
        E->>E: handle.complete(cachedData, DataSource.cached)
        
        opt Revalidate bật
            E->>E: Tiếp tục xử lý...
            E->>SB: emit(job.createEvent(freshData))
        end
    else Cache Miss
        E->>E: process(job)
        E->>E: Ghi vào cache
        E->>SB: emit(job.createEvent(result))
        E->>E: handle.complete(result, DataSource.fresh)
    end
    deactivate E
    
    SB->>O: UsersLoadedEvent
    activate O
    O->>O: onEvent(UsersLoadedEvent)
    O->>O: emit(state.copyWith(users: e.users))
    deactivate O
```


---

## Hệ Thống Event

### Active vs Passive Events

```mermaid
flowchart TB
    subgraph "Orchestrator A"
        OA[UserOrchestrator]
        JA[LoadUsersJob]
    end
    
    subgraph "Orchestrator B"
        OB[DashboardOrchestrator]
    end
    
    subgraph "SignalBus"
        SB[Broadcast]
    end
    
    OA -->|"dispatch"| JA
    JA -->|"success"| SB
    SB -->|"Active Event"| OA
    SB -->|"Passive Event"| OB
    
    OA -->|"isJobRunning(id) = true"| OA
    OB -->|"isJobRunning(id) = false"| OB
    
    style OA fill:#4CAF50,color:#fff
    style OB fill:#9C27B0,color:#fff
```

**Active Event**: Orchestrator đã dispatch job nhận được completion event.
- `isJobRunning(event.correlationId)` trả về `true`

**Passive Event**: Các orchestrators khác nhận cùng event như observers.
- `isJobRunning(event.correlationId)` trả về `false`
- Hữu ích cho đồng bộ state giữa các features


---

## Tính Năng Nâng Cao

### 1. Timeout & Cancellation

```dart
// Với timeout
final job = LoadUsersJob()..timeout = Duration(seconds: 30);

// Với cancellation
final token = CancellationToken();
final job = LoadUsersJob()..cancellationToken = token;

// Hủy sau
token.cancel();
```

### 2. Retry Policy

```dart
final job = LoadUsersJob()
  ..retryPolicy = RetryPolicy(
    maxRetries: 3,
    delay: Duration(seconds: 1),
    backoffMultiplier: 2.0,  // 1s, 2s, 4s
  );
```

### 3. Circuit Breaker (Bảo Vệ Loop)

Orchestrator có bảo vệ sẵn chống infinite event loops.

```dart
// Cấu hình giới hạn theo event type
OrchestratorConfig.setLimit(JobProgressEvent, 100);  // Cho phép 100/giây
OrchestratorConfig.setLimit(JobSuccessEvent, 50);    // Cho phép 50/giây
```


### 4. OrchestratorObserver (Logging Toàn Cục)

```dart
class MyObserver extends OrchestratorObserver {
  @override
  void onJobStart(BaseJob job) {
    analytics.track('job_started', {'type': job.runtimeType.toString()});
  }
  
  @override
  void onJobError(BaseJob job, Object error, StackTrace stack) {
    crashlytics.recordError(error, stack);
  }
}

// Đặt toàn cục
OrchestratorObserver.instance = MyObserver();
```

---

## Tham Khảo Nhanh

### Các Pattern Sử Dụng

| Pattern | Code | Trường Hợp Dùng |
|---------|------|-----------------|
| Fire & Forget | `orchestrator.loadUsers()` | Cập nhật state qua events |
| Chờ Kết Quả | `await handle.future` | Cần kết quả ngay |
| Theo Dõi Tiến Độ | `handle.progress.listen(...)` | Hiển thị UI tiến độ |
| Kiểm Tra Active | `isJobRunning(id)` | Phân biệt job của mình vs của người khác |

### Giá Trị DataSource

| Giá Trị | Ý Nghĩa |
|---------|---------|
| `DataSource.fresh` | Vừa lấy từ nguồn |
| `DataSource.cached` | Trả về từ cache |
| `DataSource.optimistic` | Cập nhật lạc quan (chờ xác nhận) |

---

*Tạo cho orchestrator_core v1.0.0 - Domain Event Architecture v3*
