# Bảng Thuật ngữ Anh-Việt (Glossary)

Bảng này cung cấp bản dịch các thuật ngữ kỹ thuật được sử dụng trong sách.

| Tiếng Anh | Tiếng Việt | Giải thích |
|-----------|------------|------------|
| **Orchestrator** | Bộ điều phối | Thành phần quản lý trạng thái và điều phối luồng xử lý |
| **Dispatcher** | Bộ định tuyến | Thành phần định tuyến Job đến Executor phù hợp |
| **Executor** | Bộ thực thi | Thành phần thực hiện logic nghiệp vụ |
| **Signal Bus** | Kênh truyền tín hiệu | Hạ tầng giao tiếp theo mô hình Publish-Subscribe |
| **Job** | Công việc/Tác vụ | Gói tin yêu cầu gửi từ Orchestrator đến Executor |
| **Event** | Sự kiện | Gói tin kết quả phát từ Executor về Signal Bus |
| **Fire-and-Forget** | Gửi và Quên | Mô hình gửi lệnh không chờ đợi kết quả đồng bộ |
| **Correlation ID** | Mã định danh giao dịch | ID duy nhất liên kết Job với Event tương ứng |
| **State Machine** | Máy trạng thái | Cơ chế quản lý trạng thái dựa trên sự kiện |
| **Direct Mode** | Chế độ Trực tiếp | Xử lý sự kiện từ Job do chính mình khởi tạo |
| **Observer Mode** | Chế độ Quan sát | Lắng nghe sự kiện từ nguồn khác |
| **Broadcast Stream** | Luồng Phát sóng | Stream cho phép nhiều listener cùng lắng nghe |
| **Cancellation Token** | Mã hủy | Cơ chế cho phép hủy tác vụ đang chạy |
| **Retry Policy** | Chính sách Thử lại | Cấu hình cho việc tự động thử lại khi lỗi |
| **Exponential Backoff** | Tăng cấp theo Hàm mũ | Thuật toán tăng dần thời gian chờ giữa các lần thử |
| **Context Enrichment** | Bổ sung Ngữ cảnh | Thu thập data từ nhiều nguồn để tạo context đầy đủ |
| **Chaining** | Chuỗi hóa | Thực hiện tuần tự nhiều tác vụ phụ thuộc |
