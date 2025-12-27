# Hướng Dẫn DevTools Extension

DevTools Extension của Flutter Orchestrator cung cấp khả năng debug real-time cho các ứng dụng sử dụng Orchestrator.

## Tính Năng

### 1. Event Timeline
Theo dõi tất cả jobs và events khi chúng xảy ra:
- Xem loại event (JobStarted, JobSuccess, JobFailure, etc.)
- Lọc theo loại event hoặc tên job
- Xem timestamps và correlation IDs

### 2. Job Inspector
Nhóm các events liên quan theo correlation ID:
- Xem toàn bộ lifecycle của mỗi job
- Kiểm tra dữ liệu success/failure
- Xem retry attempts và chi tiết lỗi

### 3. Metrics Dashboard
Thống kê về việc thực thi jobs trong ứng dụng:
- **Total Events/Jobs**: Tổng số hoạt động
- **Success Rate**: Tỷ lệ jobs thành công
- **Peak Throughput**: Số jobs tối đa xử lý mỗi giây
- **Cache Hit Rate**: Hiệu quả của chiến lược caching
- **Anomaly Detection**: Tự động phát hiện failures và patterns bất thường

### 4. Network Queue
Kiểm tra hàng đợi offline jobs:
- Xem các jobs đang chờ kết nối mạng
- Kiểm tra retry counts và trạng thái poison pill
- Theo dõi tiến trình sync

### 5. Executor Registry
Xem tất cả executors đã đăng ký:
- Xem executors nào khả dụng
- Xác minh registration khi khởi động

## Cài Đặt

DevTools extension tự động khả dụng khi bạn:

1. Thêm `orchestrator_flutter` vào project:
   ```bash
   flutter pub add orchestrator_flutter
   ```

2. Khởi tạo DevTools observer trong `main()`:
   ```dart
   import 'package:orchestrator_flutter/orchestrator_flutter.dart';

   void main() {
     initDevToolsObserver();
     runApp(MyApp());
   }
   ```

3. Chạy app ở chế độ debug hoặc profile và mở Flutter DevTools.

## Mẹo Sử Dụng

- **Filter Events**: Dùng filter bar để tập trung vào loại event hoặc job cụ thể
- **Click Events**: Click vào bất kỳ event nào để xem dữ liệu JSON chi tiết
- **Watch Metrics**: Giữ tab Metrics mở trong khi load testing
- **Debug Offline**: Dùng tab Network Queue để xác minh xử lý offline job

## Tối Ưu Release Build

> [!IMPORTANT]
> Mặc dù `OrchestratorObserver` chỉ activate trong debug/profile mode (tự động kiểm tra `kDebugMode || kProfileMode`), code vẫn tồn tại trong release build. Để tối ưu kích thước app và đảm bảo không có code debug trong production, hãy làm theo hướng dẫn sau.

### Cách 1: Conditional Import (Khuyến nghị)

Sử dụng `kReleaseMode` để không gọi `initDevToolsObserver()` trong release:

```dart
import 'package:flutter/foundation.dart';
import 'package:orchestrator_flutter/orchestrator_flutter.dart';

void main() {
  // Chỉ init DevTools trong debug/profile mode
  if (!kReleaseMode) {
    initDevToolsObserver();
  }
  runApp(MyApp());
}
```

### Cách 2: Assert (Tree-shaking friendly)

Dùng `assert` để compiler tự động loại bỏ code trong release:

```dart
void main() {
  assert(() {
    initDevToolsObserver();
    return true;
  }());
  runApp(MyApp());
}
```

### Cách 3: Không import trong release

Nếu muốn loại bỏ hoàn toàn dependency trong release, sử dụng conditional imports:

```dart
// lib/devtools_init.dart
export 'devtools_init_stub.dart'
    if (dart.library.developer) 'devtools_init_real.dart';

// lib/devtools_init_stub.dart
void initDevTools() {} // No-op

// lib/devtools_init_real.dart
import 'package:orchestrator_flutter/orchestrator_flutter.dart';
void initDevTools() => initDevToolsObserver();
```

### Kiểm Tra Kích Thước Build

So sánh kích thước trước và sau khi áp dụng tối ưu:

```bash
# Trước
flutter build apk --release --analyze-size

# Sau khi thêm conditional
flutter build apk --release --analyze-size
```

Thông thường, việc này có thể giảm vài KB đến vài chục KB tùy theo tree-shaking của compiler.

## Khắc Phục Sự Cố

### Extension Không Hiển Thị
- Đảm bảo `orchestrator_flutter` đã được import đúng
- Xác minh `initDevToolsObserver()` được gọi trước `runApp()`
- Kiểm tra đang chạy ở chế độ debug/profile (không phải release)

### Không Có Events Xuất Hiện
- Xác nhận app đang dispatch jobs thông qua Dispatcher
- Kiểm tra executors đã được đăng ký đúng

## Kiến Trúc

```mermaid
sequenceDiagram
    participant App as Flutter App
    participant Observer as OrchestratorObserver
    participant DevTools as DevTools Extension
    
    App->>Observer: SignalBus.emit(event)
    Observer->>DevTools: postEvent('ext.orchestrator.event', data)
    DevTools->>DevTools: Update Timeline/Metrics
```

Extension hoạt động bằng cách:
1. `OrchestratorObserver` subscribe vào `SignalBus`
2. Events được serialize và gửi qua `dart:developer.postEvent()`
3. DevTools extension nhận và hiển thị events real-time
