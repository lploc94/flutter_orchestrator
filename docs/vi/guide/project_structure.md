# Cấu trúc thư mục chuẩn

Gợi ý cấu trúc thư mục cho dự án sử dụng Flutter Orchestrator.

---

## 1. Cấu trúc cơ bản (Nhỏ/Vừa)

Phù hợp với dự án **nhỏ đến vừa** (<20 screens, 1-3 developers).

```
lib/
├── app.dart                    # MaterialApp, routing
├── main.dart                   # Entry point, setup
│
├── core/                       # Foundation layer
│   ├── config/                 # App configuration
│   │   └── orchestrator_config.dart  # Dispatcher, executors registration
│   ├── services/               # External services (API, DB)
│   │   ├── api_service.dart
│   │   └── database_service.dart
│   └── utils/                  # Helpers, extensions
│
├── jobs/                       # All Job definitions
│   ├── auth_jobs.dart          # LoginJob, LogoutJob, etc.
│   ├── user_jobs.dart          # FetchUserJob, UpdateUserJob
│   └── product_jobs.dart       # FetchProductsJob, etc.
│
├── executors/                  # All Executors
│   ├── auth_executor.dart      # LoginExecutor, LogoutExecutor
│   ├── user_executor.dart      # UserExecutor
│   └── product_executor.dart   # ProductExecutor
│
├── cubits/                     # Orchestrators (UI State)
│   ├── auth/
│   │   ├── auth_cubit.dart
│   │   └── auth_state.dart
│   ├── user/
│   │   ├── user_cubit.dart
│   │   └── user_state.dart
│   └── product/
│       ├── product_cubit.dart
│       └── product_state.dart
│
├── models/                     # Domain models
│   ├── user.dart
│   └── product.dart
│
└── ui/                         # Presentation layer
    ├── screens/
    │   ├── home_screen.dart
    │   ├── login_screen.dart
    │   └── profile_screen.dart
    └── widgets/
        ├── buttons/
        └── cards/
```

---

## 2. Cấu trúc Feature-based (Lớn)

Phù hợp với dự án **lớn** (20+ screens, nhiều teams).

```
lib/
├── app.dart
├── main.dart
│
├── core/                           # Shared foundation
│   ├── config/
│   ├── services/
│   ├── utils/
│   └── widgets/                    # Shared widgets
│
├── features/                       # Feature modules
│   ├── auth/
│   │   ├── jobs/
│   │   │   ├── login_job.dart
│   │   │   └── logout_job.dart
│   │   ├── executors/
│   │   │   ├── login_executor.dart
│   │   │   └── logout_executor.dart
│   │   ├── cubit/
│   │   │   ├── auth_cubit.dart
│   │   │   └── auth_state.dart
│   │   ├── models/
│   │   │   └── auth_result.dart
│   │   ├── screens/
│   │   │   ├── login_screen.dart
│   │   │   └── register_screen.dart
│   │   └── auth.dart               # Barrel export
│   │
│   ├── products/
│   │   ├── jobs/
│   │   ├── executors/
│   │   ├── cubit/
│   │   ├── models/
│   │   ├── screens/
│   │   └── products.dart
│   │
│   └── cart/
│       └── ...
│
└── shared/                         # Cross-feature shared code
    ├── models/
    └── widgets/
```

---

## 3. main.dart chuẩn

```dart
import 'package:flutter/material.dart';
import 'package:orchestrator_core/orchestrator_core.dart';

import 'core/config/orchestrator_config.dart';
import 'app.dart';

void main() {
  // 1. Đăng ký tất cả Executors (BẮT BUỘC trước runApp)
  setupExecutors();
  
  // 2. (Tùy chọn) Đăng ký Network Jobs cho offline support
  // registerNetworkJobs();
  
  // 3. (Tùy chọn) Cấu hình logging
  if (kDebugMode) {
    OrchestratorConfig.enableDebugLogging();
  }
  
  runApp(const MyApp());
}
```

---

## 4. orchestrator_config.dart

```dart
import 'package:orchestrator_core/orchestrator_core.dart';

// Import services
import '../services/api_service.dart';
import '../services/database_service.dart';

// Import executors
import '../../executors/auth_executor.dart';
import '../../executors/user_executor.dart';
import '../../executors/product_executor.dart';

// Import jobs
import '../../jobs/auth_jobs.dart';
import '../../jobs/user_jobs.dart';
import '../../jobs/product_jobs.dart';

/// Setup all executors with Dispatcher
void setupExecutors() {
  // Initialize services
  final api = ApiService();
  final db = DatabaseService();
  
  // Register executors
  final dispatcher = Dispatcher();
  
  // Auth
  dispatcher.register<LoginJob>(LoginExecutor(api));
  dispatcher.register<LogoutJob>(LogoutExecutor(api));
  
  // User
  dispatcher.register<FetchUserJob>(FetchUserExecutor(api));
  dispatcher.register<UpdateUserJob>(UpdateUserExecutor(api));
  
  // Products
  dispatcher.register<FetchProductsJob>(FetchProductsExecutor(api));
}
```

---

## 5. Naming Conventions

| Component | Pattern | Ví dụ |
|-----------|---------|-------|
| Job | `{Action}Job` | `FetchUserJob`, `LoginJob`, `CreateOrderJob` |
| Executor | `{Action}Executor` | `FetchUserExecutor`, `LoginExecutor` |
| Cubit | `{Feature}Cubit` | `AuthCubit`, `ProductCubit` |
| State | `{Feature}State` | `AuthState`, `ProductState` |
| Screen | `{Feature}Screen` | `LoginScreen`, `ProductListScreen` |

---

## 6. Quy tắc tổ chức

### ✅ Nên làm

- **Một Job = Một hành động cụ thể:** `FetchUserJob`, không `UserJob`
- **Một Executor = Một Job type:** Tách biệt rõ ràng
- **Cubit theo feature:** Không theo screen
- **Barrel exports:** Mỗi folder có file export

### ❌ Không nên làm

```dart
// ❌ SAI: Job làm quá nhiều thứ
class UserJob extends BaseJob {
  final UserAction action;  // fetch, update, delete...
}

// ✅ ĐÚNG: Tách thành nhiều Jobs
class FetchUserJob extends BaseJob {}
class UpdateUserJob extends BaseJob {}
class DeleteUserJob extends BaseJob {}

// ❌ SAI: Executor xử lý nhiều Job types
class UserExecutor extends BaseExecutor<BaseJob> {}

// ✅ ĐÚNG: Mỗi Executor một type
class FetchUserExecutor extends BaseExecutor<FetchUserJob> {}
```

---

## Xem thêm

- [Getting Started](getting_started.md) - Bắt đầu nhanh
- [Simple Counter Example](../../examples/simple_counter) - Code mẫu
