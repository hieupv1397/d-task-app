# D Task App — ứng dụng di động (iOS / Android)

Một app dùng chung cho nhiều đơn vị. App đi kèm **D Task Gateway** (`../d-task-gateway`) để biết đơn vị nào dùng API nào.

> Trạng thái: **đã có bản MVP chạy được** (Flutter) cho các chức năng ở mục 2A–2F: chọn đơn vị, đăng nhập, trang chủ, danh sách và chi tiết việc, báo cáo tiến độ, chuyển bước, văn bản và ký duyệt, thông báo, cá nhân. Chưa làm: thông báo đẩy, đính kèm ảnh/tệp, mở khóa sinh trắc học, làm việc ngoại tuyến. Mục 11 ghi cách chạy.

## 1. Định vị

App **không thay thế web**. Web là nơi tạo, cấu hình và quản trị. App là nơi người dùng **nhận việc, báo cáo tiến độ và ký văn bản khi đang di chuyển**.

| Nên có trên app | Không đưa vào app (để web làm) |
|---|---|
| Nhận thông báo đẩy, mở thẳng vào việc hoặc văn bản liên quan | Cấu hình quy trình, biểu mẫu, loại công việc, vai trò, danh mục |
| Xem việc được giao cho mình, việc mình theo dõi | Quản trị nhân sự, phòng ban, phân quyền |
| Cập nhật tiến độ, nhận xét, chuyển bước quy trình | Thiết lập nhắc việc, cấu hình email, cấu hình AI |
| Xem, ký duyệt hoặc từ chối văn bản | Báo cáo, dashboard nhiều biểu đồ |
| Đính kèm ảnh, tài liệu từ điện thoại | Soạn quy trình ký (`SignFlows`) |
| Tạo việc nhanh (giai đoạn sau) | Sửa chi tiết biểu mẫu chuyên biệt phức tạp |

Nguyên tắc: mỗi màn hình trả lời một câu hỏi **"tôi phải làm gì ngay bây giờ?"**.

Mỗi đơn vị có thể được bật/tắt từng tính năng trên gateway (xem mục 5.3), nên mọi chức năng bên dưới đều phải ẩn được theo cờ.

## 2. Chức năng theo mức ưu tiên

### Giai đoạn 1 — MVP (nắm tình hình, cập nhật việc, ký văn bản)

**A. Chọn đơn vị và đăng nhập**
- Nhập mã đơn vị hoặc mở liên kết mời `https://donvi.hica.vn/t/{MÃ}` → app gọi gateway `GET /api/v1/public/partners/{code}` lấy `apiBaseUrl`, logo, màu chủ đạo, `minAppVersion`.
- Ghi nhớ đơn vị cho lần mở sau; có nút "Đổi đơn vị".
- Đăng nhập tài khoản D Task (`POST /api/v1/auth/login`, `GET auth/me`). Lưu token trong Keychain / Keystore.
- Mở khóa nhanh bằng vân tay / Face ID (chỉ mở khóa token đã lưu, không thay thế mật khẩu khi ký).
- Xử lý: đơn vị tạm ngưng (403 `PARTNER_SUSPENDED`), app quá cũ (`minAppVersion`) → màn hình bắt cập nhật.

**B. Trang chủ "Việc của tôi"**
- Ba số đếm: việc quá hạn, việc đến hạn trong 3 ngày, văn bản chờ tôi ký.
- Danh sách việc ưu tiên: quá hạn trước, rồi theo hạn gần nhất.
- Nguồn: `GET /api/v1/tasks` (lọc theo người phụ trách là tôi), `GET documents/inbox` (có sẵn `PendingCount`).

**C. Danh sách và chi tiết công việc**
- Danh sách có tìm kiếm, lọc: Giao cho tôi / Tôi theo dõi / Quá hạn / Đang thực hiện / Hoàn thành.
- Chi tiết (chỉ đọc là chính): mã, tiêu đề, loại việc, đơn vị phụ trách, người tham gia theo vai trò, hạn, mức ưu tiên, trạng thái quy trình, tiến độ, lịch sử cập nhật, tài liệu đính kèm.
- Nguồn: `GET tasks/{id}`.

**D. Cập nhật thông tin công việc** (đúng yêu cầu "cập nhật thông tin công việc")
- **Báo cáo tiến độ**: phần trăm (thanh kéo), nội dung, rủi ro, đề xuất → `POST tasks/{id}/progress` (cần `RowVersion`, xung đột thì báo "việc đã được người khác cập nhật, tải lại").
- **Chuyển bước quy trình**: các nút hành động hợp lệ của trạng thái hiện tại (ví dụ Bắt đầu, Hoàn thành, Từ chối). Có yêu cầu nhập lý do / nhận xét thì bắt buộc nhập → `POST tasks/{id}/workflow-actions`.
- **Đính kèm**: chụp ảnh hoặc chọn tệp từ điện thoại, gắn vào việc → `POST tasks/{id}/documents`.
- Gồm cả ô nhận xét; **cần kiểm tra** backend đã có API bình luận riêng chưa (chưa thấy controller riêng).
- Không sửa các trường cấu trúc (loại việc, biểu mẫu chuyên biệt, đơn vị) — mở bằng web.

**E. Văn bản và ký duyệt** (đúng yêu cầu "ký văn bản")
- Hộp thư văn bản: tab **Chờ tôi ký / Tôi đã gửi / Đã xong / Tất cả** → `GET documents/inbox`.
- Chi tiết văn bản: tên, loại, phiên bản, tiến trình các bước ký (ai đã ký, ai đang chờ), xem tệp PDF/ảnh trong app → `GET documents/{id}`, `GET documents/{id}/download`.
- **Duyệt**: nhập nhận xét (không bắt buộc) + xác nhận mật khẩu → `POST documents/{id}/act` với `Decision = APPROVE`, `Password`.
- **Từ chối**: bắt buộc nhập lý do → `Decision = REJECT`. Văn bản bị từ chối quay về người gửi.
- Kiểm tra tính toàn vẹn: nút "Xác thực văn bản" → `GET documents/{id}/verify`.
- Người gửi: nộp ký / hủy / tải phiên bản mới (`submit`, `cancel`, `versions`) — làm sau khi luồng ký ổn.
- Chỉ người đang ở đúng bước ký mới thấy nút Duyệt / Từ chối.

**F. Thông báo**
- Danh sách thông báo, chấm đỏ chưa đọc, "đọc tất cả" → `GET notifications`, `unread-count`, `{id}/read`, `read-all`.
- Chạm vào thông báo → mở đúng việc hoặc văn bản theo `EntityType` / `EntityId`.
- **Thông báo đẩy** (cần gateway giai đoạn 2). Các loại hiện có trong hệ thống:

| Loại | Ý nghĩa | Mở tới |
|---|---|---|
| `DOC_SIGN_REQUEST` | Có văn bản chờ bạn ký | Chi tiết văn bản |
| `DOC_COMPLETED` | Văn bản đã ký xong | Chi tiết văn bản |
| `DOC_REJECTED` | Văn bản bị từ chối | Chi tiết văn bản |
| `TASK_DUE_SOON` / `TASK_OVERDUE` | Sắp đến hạn / quá hạn | Chi tiết việc |
| `TASK_STALE` | Việc lâu chưa cập nhật | Cập nhật tiến độ |
| `TASK_ESCALATION` | Leo thang lên cấp trên | Chi tiết việc |
| `TASK_REMINDER_MANUAL` | Người khác nhắc việc | Chi tiết việc |

**G. Cá nhân**
- Xem hồ sơ (`MyProfile`), đổi mật khẩu, đăng xuất, đổi đơn vị, bật/tắt nhận thông báo, phiên bản app.

### Giai đoạn 2
- Tạo việc nhanh: tiêu đề, loại, người phụ trách, hạn, ảnh đính kèm (có thể dùng trợ lý AI chụp ảnh tạo việc đã có ở web).
- Nhắc việc người khác (`POST tracking/reminders`) cho người có quyền `TASK.REMIND`.
- Xem việc theo dự án / không gian làm việc, theo dõi việc của nhân viên (cho trưởng phòng).
- Ký theo lô nhiều văn bản.
- Làm việc ngoại tuyến: xem lại danh sách đã tải, hàng đợi cập nhật tiến độ khi mất mạng.

### Ngoài phạm vi
Cấu hình hệ thống, quản trị người dùng và phân quyền, thiết kế quy trình / biểu mẫu, báo cáo nâng cao.

## 3. Danh sách màn hình (MVP)

```
Khởi động ─► Chọn đơn vị ─► Đăng nhập ─► Tab bar
                                          ├─ Trang chủ  (số đếm, việc cần làm, văn bản chờ ký)
                                          ├─ Công việc  ─► Chi tiết ─► Cập nhật tiến độ / Chuyển bước / Đính kèm
                                          ├─ Văn bản    ─► Chi tiết ─► Xem tệp / Duyệt / Từ chối
                                          ├─ Thông báo
                                          └─ Cá nhân
```

## 4. Phân quyền trong app

App dùng đúng quyền của backend (không tự phân quyền): ẩn nút theo quyền trả về từ `auth/me`, nhưng vẫn dựa vào backend từ chối.

| Hành động | Quyền backend |
|---|---|
| Xem việc, văn bản | `TASK.VIEW` |
| Cập nhật tiến độ, đính kèm, gửi ký | `TASK.PROGRESS` |
| Chuyển bước quy trình, sửa việc | `TASK.UPDATE` |
| Tạo việc (GĐ2) | `TASK.CREATE` |
| Nhắc việc (GĐ2) | `TASK.REMIND` |
| Duyệt / Từ chối văn bản | đăng nhập + đúng người ở bước ký hiện tại |

## 5. API dành cho app

### 5.1. Đã có trên D Task API (`/api/v1/app`, cần đăng nhập)

| Route | Việc |
|---|---|
| `GET app/config` | Phiên bản API, giờ máy chủ, dung lượng tải lên tối đa |
| `GET app/home` | **Trang chủ trong một lần gọi**: số việc đang mở, quá hạn, sắp hạn (3 ngày), văn bản chờ tôi ký, thông báo chưa đọc, và 5 việc ưu tiên nhất (quá hạn trước) |
| `GET app/tasks?scope=&keyword=&pageNumber=&pageSize=` | Danh sách việc gọn cho app. `scope`: `ASSIGNED` (có tên tôi, chưa xong), `OWNER` (tôi phụ trách), `FOLLOWING` (tôi tham gia, không phụ trách), `OVERDUE`, `DONE`, `ALL`. Mỗi dòng có `myRoles` (vai trò của tôi), trạng thái quy trình, `rowVersion` |
| `POST app/devices` | Đăng ký hoặc làm mới mã đẩy: `{ pushToken, platform: IOS/ANDROID, appVersion, deviceName }`. Gọi sau khi đăng nhập và mỗi lần mở app. Mã đã thuộc người khác (máy dùng chung) tự chuyển sang người đang đăng nhập |
| `GET app/devices` | Các thiết bị của tôi |
| `POST app/devices/unregister` | Gỡ thiết bị khi đăng xuất: `{ pushToken }` |

Các thao tác còn lại dùng route có sẵn của web: đăng nhập `auth/login`, hồ sơ `auth/me`, chi tiết việc `tasks/{id}`, tiến độ `tasks/{id}/progress`, chuyển bước `tasks/{id}/workflow-actions`, văn bản `documents/*`, thông báo `notifications/*`.

### 5.2. Đã có trên Gateway

- `GET /api/v1/public/partners/{code}` trả thêm `features`: bản đồ `{ MÃ_TÍNH_NĂNG: true/false }` đã tính sẵn (mặc định + phần quản trị đã đổi cho đơn vị).
- Quản trị: `GET /api/v1/admin/features` (danh mục), `PUT /api/v1/admin/partners/{id}/features` (bật/tắt), có ghi nhật ký.

### 5.3. Danh mục tính năng bật/tắt theo đơn vị

| Mã | Tính năng | Mặc định |
|---|---|---|
| `TASK_PROGRESS` | Cập nhật tiến độ | Bật |
| `TASK_WORKFLOW` | Chuyển bước quy trình | Bật |
| `TASK_ATTACH` | Đính kèm ảnh và tệp | Bật |
| `TASK_CREATE` | Tạo việc nhanh | Tắt |
| `TASK_REMIND` | Nhắc việc người khác | Tắt |
| `DOC_VIEW` | Xem văn bản | Bật |
| `DOC_SIGN` | Ký duyệt / từ chối | Bật |
| `DOC_SUBMIT` | Gửi trình ký | Tắt |
| `DOC_BATCH_SIGN` | Ký theo lô | Tắt |
| `NOTIFICATIONS` | Hộp thông báo | Bật |
| `BIOMETRIC` | Mở khóa vân tay / Face ID | Bật |
| `AI_ASSISTANT` | Trợ lý AI | Tắt |
| `OFFLINE` | Làm việc ngoại tuyến | Tắt |

Quy tắc cho app:
1. Lấy `features` khi tra cứu đơn vị, lưu cùng đơn vị đã chọn và **làm mới mỗi lần mở app** (cờ đổi trên gateway có hiệu lực ở lần mở sau).
2. Mã không có trong bản đồ coi là **tắt**; app thấy mã lạ thì bỏ qua (app cũ chạy với gateway mới).
3. Tắt một tính năng thì ẩn hẳn nút và màn hình, không hiện nút xám.
4. Cờ chỉ ẩn giao diện. Quyền thật vẫn do D Task API quyết định, nên tắt cờ **không** thay thế phân quyền.
5. Muốn thêm tính năng mới thì thêm vào danh mục trong `d-task-gateway/api/.../Domain/Features.cs` và thêm vào bảng trên.

### 5.4. Còn thiếu

| # | Việc | Ở đâu |
|---|---|---|
| 1 | Gửi thông báo đẩy thật: khi tạo `Notification` thì tra thiết bị trong `user_devices`, gọi gateway `push/send` (ký HMAC) | D Task API + Gateway giai đoạn 2 |
| 2 | **Refresh token** / phiên dài hạn (cần kiểm tra hiện chỉ có access token) | D Task API (`auth`) |
| 3 | API bình luận công việc (chưa thấy controller riêng) | D Task API |
| 4 | Chữ ký chỉ có cách nhập lại mật khẩu (`Password` trong `act`); thêm mã PIN ký nếu cần | D Task API |

## 6. Công nghệ: Flutter

Đã chốt **Flutter** (iOS + Android một mã nguồn).

Gợi ý cấu trúc khi bắt đầu code:

| Việc | Gói đề xuất |
|---|---|
| Gọi API, token, tự gắn header | `dio` + interceptor |
| Lưu token an toàn | `flutter_secure_storage` |
| Sinh trắc học | `local_auth` |
| Thông báo đẩy | `firebase_messaging` (FCM, trên iOS đi qua APNs) |
| Chụp ảnh, chọn tệp | `image_picker`, `file_picker` |
| Xem PDF | `pdfx` hoặc `syncfusion_flutter_pdfviewer` |
| Quản lý trạng thái, điều hướng | `riverpod`, `go_router` |
| Mở liên kết mời `/t/{mã}` | `app_links` |

Cấu trúc thư mục: `lib/core` (api, auth, gateway, features), `lib/features/{home,tasks,documents,notifications,profile}`, `lib/shared` (widget dùng chung).

Việc cần chốt thêm:
1. **Cách ký**: MVP dùng nhập lại mật khẩu, về sau thêm PIN ký riêng.
2. **Xem văn bản**: PDF xem trong app; Word/Excel tải về mở bằng ứng dụng ngoài ở MVP.
3. **Định danh app** (`vn.hica.dtask`), tài khoản Apple Developer, Google Play, Firebase và khóa APNs: chuẩn bị sớm vì duyệt cửa hàng mất vài ngày.

## 7. Lộ trình đề xuất

| Bước | Nội dung |
|---|---|
| 0 | Tạo tài khoản cửa hàng, Firebase; `flutter create` trong thư mục này |
| 1 | Khung app, chọn đơn vị (gateway, lấy `features`), đăng nhập, lưu phiên, đăng ký thiết bị |
| 2 | Trang chủ (`app/home`), danh sách (`app/tasks`), chi tiết, cập nhật tiến độ, chuyển bước |
| 3 | Hộp thư văn bản, xem tệp, duyệt / từ chối ký |
| 4 | Nối gửi thông báo đẩy (D Task API gọi gateway, gateway gọi FCM/APNs), bấm thông báo mở đúng màn hình |
| 5 | Thử nội bộ (TestFlight / bản thử Android), thu phản hồi, đưa lên cửa hàng |
| 6 | Giai đoạn 2 theo phản hồi |

## 8. Đã làm trong mã nguồn

```
lib/
  main.dart, app.dart          khởi động, điều hướng (go_router), thanh tab, màu theo đơn vị
  core/
    config.dart                địa chỉ gateway, mã tính năng, so sánh phiên bản
    api.dart                   GatewayApi (tra mã đơn vị), TenantApi (gọi D Task API), chuyển lỗi sang tiếng Việt
    session.dart               phiên đăng nhập (token ở kho khóa an toàn), làm mới cờ tính năng mỗi lần mở app
    models.dart                mô hình dữ liệu
  features/{auth,home,tasks,documents,notifications,profile}
  shared/widgets.dart          thành phần dùng chung
test/core_test.dart            kiểm thử đơn vị
```

Ghi nhớ trên thiết bị (`lib/core/remember.dart`): mã đơn vị và tên đăng nhập đã đăng nhập thành công được gợi ý (tối đa 5, mới nhất trước); tên đăng nhập gần nhất tự điền khi mở màn đăng nhập. Tùy chọn "Ghi nhớ mật khẩu" lưu mật khẩu trong kho khóa an toàn (Keychain/Keystore) theo từng cặp đơn vị + tên đăng nhập và tự điền ở màn đăng nhập và hộp thoại ký; mật khẩu lưu sai (đã đổi mật khẩu) tự bị bỏ sau lần ký thất bại. Bấm dấu x trên tên gợi ý để quên tên đó cùng mật khẩu. Trên bản web, kho khóa chỉ là bộ nhớ của trình duyệt nên kém an toàn hơn trên điện thoại.

Hành vi đã có: tính năng nào gateway tắt thì ẩn tab và nút; thiếu quyền thì ẩn nút; đơn vị bị tạm ngưng hoặc xóa thì quay về màn hình chọn đơn vị kèm thông báo; app thấp hơn `minAppVersion` bị chặn bằng màn hình yêu cầu cập nhật; 401 thì về màn hình đăng nhập; mất mạng thì báo lỗi kèm nút thử lại.

## 9. Kiểm tra đã chạy

- `flutter analyze`: không có cảnh báo. `flutter test`: 10 bài đều qua.
- Chạy bản web với gateway và API cục bộ: chọn đơn vị qua gateway, đăng nhập, trang chủ, danh sách việc, chi tiết, báo cáo tiến độ (đối chiếu API thấy bản ghi mới), hộp thư văn bản, ký duyệt (bước ký chuyển sang "Đã ký", bước sau đến lượt lãnh đạo).
- **Chưa chạy thử trên Android/iOS thật**: máy dev chưa cài Android SDK; iOS cần máy Mac.

## 10. Còn thiếu

| Việc | Ghi chú |
|---|---|
| Thông báo đẩy: chạy thử trên điện thoại thật | Code app, D Task API và gateway đã xong (xem mục 13); cần khóa dịch vụ Firebase trên VPS, secret của đơn vị và máy thật để thử |
| Đính kèm ảnh, tệp vào việc | `image_picker`, `file_picker` + route `tasks/{id}/documents` |
| Xem tệp Word, Excel trong app | PDF và ảnh đã xem được (luôn mở phiên bản mới nhất, sau khi ký là bản có dấu ký điện tử); định dạng khác cần mở bằng web |
| Mở khóa sinh trắc học | `local_auth`, bật theo cờ `BIOMETRIC` |
| Tạo việc nhanh, nhắc việc, ký theo lô, ngoại tuyến | Giai đoạn 2, bật theo cờ gateway |
| Cấu hình Android/iOS | Định danh đã đặt `vn.hica.dtask` (Android và iOS), tên hiển thị "D Task"; còn biểu tượng và ký bản phát hành |

Lưu ý khi thử: các vai trò mẫu (`DEMO_*`) của D Task không có quyền `TASK.PROGRESS` và `TASK.UPDATE`, nên nhân viên không thấy nút báo cáo tiến độ và chuyển bước. Cần cấp hai quyền này cho vai trò thật của đơn vị trên web.

## 11. Chạy thử

```
flutter pub get
flutter analyze && flutter test
flutter run --dart-define=GATEWAY_URL=https://donvi.hica.vn        # mặc định đã là địa chỉ này
flutter build web --dart-define=GATEWAY_URL=http://localhost:5301   # chạy thử trên trình duyệt với gateway cục bộ
```

Dùng được với Android giả lập: địa chỉ máy chủ cục bộ là `http://10.0.2.2:<cổng>`. Gateway trên máy chủ chỉ nhận API dùng https; gateway cục bộ (môi trường Development) cho phép http.

## 12. Liên quan

- Gateway danh bạ đơn vị: [`../d-task-gateway`](../d-task-gateway/README.md)
- Backend: [`../d-task-api`](../d-task-api), web: [`../d-task-ui`](../d-task-ui)

## 13. Thông báo đẩy

Đường đi: D Task API tạo thông báo (nhắc việc, có văn bản chờ ký, ký xong, bị từ chối) → tra thiết bị của người nhận trong `user_devices` → gọi gateway `push/send` (ký HMAC) → gateway gọi Firebase → điện thoại.

- **App** (`lib/core/push.dart`): sau khi đăng nhập xin quyền thông báo, lấy mã thiết bị và đăng ký qua `POST app/devices`; đăng xuất thì gỡ thiết bị. Bấm thông báo mở đúng văn bản/công việc; tin của đơn vị khác với đơn vị đang đăng nhập bị bỏ qua; app đang mở thì hiện thanh thông báo nhanh và làm mới số đếm. Web không dùng push.
- **Nút thử:** Cá nhân → "Gửi thông báo thử" (route `POST app/push-test`) đi đủ đường D Task API → gateway → Firebase tới chính thiết bị của bạn.
- **Cấu hình Android:** `android/app/google-services.json` (đã có), plugin `com.google.gms.google-services`, quyền `POST_NOTIFICATIONS`. Id ứng dụng `vn.hica.dtask`.
- **iPhone (chưa làm):** cần máy Mac + tài khoản Apple Developer: thêm `GoogleService-Info.plist`, bật Push Notifications và Background Modes (Remote notifications) trong Xcode, tải khóa APNs `.p8` lên Firebase.
- **Chưa kiểm tra trên thiết bị thật.** Đã thử toàn tuyến D Task API → gateway → Firebase **giả** trên máy dev (chữ ký, mã đơn vị, xóa thiết bị hỏng); Firebase thật và máy thật chưa thử.

### Thông báo đẩy trên web D Task

Web (`d-task-ui`) dùng chung project Firebase `dtask-app` với app: nền tảng thiết bị `WEB` trong `user_devices`. Người dùng bật ở **Hồ sơ của tôi → Thông báo trên trình duyệt này** (lựa chọn được nhớ theo từng tài khoản trên từng trình duyệt). Service worker `public/firebase-messaging-sw.js` hiển thị tin khi trang đóng và mở đúng công việc (`/tasks-v2?open=ID`, văn bản thì kèm `tab=documents`) khi bấm; cấu hình công khai nằm ở `src/app/core/firebase.config.ts`. Cần HTTPS (hoặc localhost); iPhone/iPad chỉ nhận khi thêm trang vào màn hình chính. Cần giới hạn khóa API web theo tên miền trong Google Cloud Console và thêm tên miền của mỗi đơn vị mới.

## 14. Build Android và đưa lên Google Play

Công cụ dựng trên máy dev: Flutter ở `C:\src\flutter`, Android SDK ở `C:\src\android-sdk`, JDK 21 (Temurin) ở `C:\src\jdk-21.0.13+9` (JDK đi kèm IntelliJ thiếu `jlink` nên không dùng được). Mở PowerShell:

```
$env:JAVA_HOME = 'C:\src\jdk-21.0.13+9'
$env:Path = "$env:JAVA_HOME\bin;C:\src\flutter\bin;$env:Path"
$env:ANDROID_HOME = 'C:\src\android-sdk'
flutter build apk --release          # tệp cài thử: build/app/outputs/flutter-apk/app-release.apk
flutter build appbundle --release    # tệp đưa lên Play: build/app/outputs/bundle/release/app-release.aab
```

- Id ứng dụng `vn.hica.dtask`. Phiên bản lấy từ `pubspec.yaml` (`version: 1.0.0+1`): phần sau dấu `+` là `versionCode`, **phải tăng mỗi lần tải lên Play**.
- **Khóa ký tải lên**: `android/app/upload-keystore.jks` và `android/key.properties` (đã nằm trong `.gitignore`); bản sao và hướng dẫn nằm ở thư mục `khoa-quan-trong/` (cũng không đưa lên git). **Phải sao lưu hai tệp này ra nơi an toàn**; mất khóa thì phải xin Google đặt lại khóa tải lên. Cần bật Play App Signing khi tạo ứng dụng trên Play Console (Google giữ khóa ký chính).
- Thông báo đẩy Android cần `android/app/google-services.json` (đã có) và cấu hình gateway; xem mục 13.

### Cấu hình thông báo đẩy ở trang Cài đặt của D Task

Quản trị viên (quyền `SYSTEM.ADMIN`) nhập **địa chỉ gateway, mã đơn vị, secret** tại **Cài đặt → Thông báo đẩy**, không cần sửa tệp môi trường trên máy chủ. Secret được mã hóa khi lưu và không hiển thị lại (chỉ 4 ký tự cuối). Có nút **Kiểm tra kết nối** (xác minh mã và secret với gateway bằng giá trị đang nhập, không gửi tin tới ai), nút **Gửi thông báo thử cho tôi**, và bảng số thiết bị đã đăng ký (Android, iPhone, web). Chưa nhập ở đây thì hệ thống dùng `Push__GatewayUrl`, `Push__PartnerCode`, `Push__Secret` trong tệp môi trường; bấm Lưu ở trang này thì chuyển cấu hình về cơ sở dữ liệu. Mã và secret lấy từ trang quản trị gateway (Đối tác → đơn vị → Cấp secret). Đổi mã đơn vị ở gateway thì phải sửa lại mã ở đây.

## 15. Biểu tượng ứng dụng

Biểu tượng là hình khiên trắng có dấu tích trên nền xanh, cùng hình khiên với logo web D Task. Tệp gốc nằm ở `assets/icon/`: `icon.png` (1024×1024, dùng cho iOS, web và Android cũ), `icon_foreground.png` (lớp trước của biểu tượng thích ứng Android) và `play-store-512.png` (tải lên Google Play làm biểu tượng cửa hàng). Muốn đổi thì thay ảnh rồi chạy `dart run flutter_launcher_icons` để tạo lại mọi kích thước cho Android, iPhone và web, sau đó build lại. Ảnh gốc được vẽ bằng một tập lệnh Python; có thể thay bằng ảnh do nhà thiết kế làm, miễn đúng kích thước.
