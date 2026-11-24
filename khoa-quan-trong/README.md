# Khóa quan trọng của app D Task (Android)

**Thư mục này chứa bí mật. Không gửi qua chat, email, không đưa lên git, không chia sẻ công khai.**
Git đã được cấu hình bỏ qua mọi tệp ở đây, chỉ `README.md` này và `.gitignore` được phép commit.

## Trong thư mục có gì

| Tệp | Là gì | Bí mật? |
|---|---|---|
| `upload-keystore.jks` | **Khóa ký tải lên** Google Play. Mỗi lần tải bản mới lên Play đều phải ký bằng khóa này | **Rất bí mật** |
| `key.properties` | Mật khẩu của khóa trên, tên khóa (`upload`) và tên tệp khóa | **Rất bí mật** |
| `thong-tin-khoa.txt` | Tên khóa, ngày tạo, chủ sở hữu và dấu vân tay SHA-1, SHA-256 (không có mật khẩu) | Ít nhạy cảm |

Hai tệp đầu là **bản sao**. Bản gốc mà việc build đang dùng nằm ở `android\app\upload-keystore.jks` và `android\key.properties`. Không xóa bản gốc, nếu không build bản phát hành sẽ ký bằng khóa debug và Play không nhận.

## Vì sao quan trọng

- Play yêu cầu mọi bản cập nhật của cùng một app phải ký bằng đúng khóa tải lên đã đăng ký.
- **Mất khóa hoặc quên mật khẩu**: không tải được bản cập nhật. Phải gửi yêu cầu **đặt lại khóa tải lên** cho Google Play (qua Play Console → Thiết lập → Chữ ký ứng dụng), mất vài ngày và phải chứng minh quyền sở hữu tài khoản.
- **Lộ khóa**: người khác có thể ký bản giả mạo và gửi lên Play nếu họ cũng chiếm được tài khoản của bạn. Khi nghi lộ, vào Play Console yêu cầu đặt lại khóa tải lên.
- Nhờ **Play App Signing** (bật khi tạo ứng dụng), khóa ký **chính** thuộc về Google. Khóa ở đây chỉ để chứng minh bản tải lên đến từ bạn, nên đặt lại được nếu mất.

## Đây mới chỉ là bản sao cùng ổ đĩa

Thư mục này nằm cùng ổ với mã nguồn nên **chưa phải là sao lưu thật**. Ổ hỏng, máy mất hoặc xóa nhầm thư mục dự án là mất cả hai. Hãy chép thêm ra ít nhất **một nơi khác**:
1. Kho mật khẩu của công ty (Bitwarden, 1Password...) dưới dạng tệp đính kèm, và ghi mật khẩu trong `key.properties`.
2. Ổ USB hoặc ổ cứng ngoài cất ở nơi khác.
3. Không dùng thư mục chia sẻ công khai, Zalo nhóm hay email thường.

Sau khi chép xong, kiểm tra bản sao còn mở được: chạy lệnh dưới (dùng mật khẩu trong `key.properties`), thấy dòng `Alias name: upload` nghĩa là bản sao còn dùng được.

```
C:\src\jdk-21.0.13+9\bin\keytool.exe -list -keystore upload-keystore.jks
```

## Dấu vân tay để đối chiếu

Mở `thong-tin-khoa.txt` để xem SHA-1 và SHA-256 của khóa tải lên. Khi Play báo "chữ ký không khớp", đối chiếu với dòng này.

## Cách dùng khi build

Mở PowerShell trong thư mục `code\d-task-app`:

```
$env:JAVA_HOME = 'C:\src\jdk-21.0.13+9'
$env:Path = "$env:JAVA_HOME\bin;C:\src\flutter\bin;$env:Path"
$env:ANDROID_HOME = 'C:\src\android-sdk'
flutter build appbundle --release
```

Tệp kết quả: `build\app\outputs\bundle\release\app-release.aab`, tải lên Play Console. Nhớ tăng số sau dấu `+` trong `pubspec.yaml` (`version: 1.0.0+1`) mỗi lần tải bản mới.

## Khi chuyển sang máy mới

1. Cài lại Flutter, Android SDK, JDK 21 như hướng dẫn ở README chính của app (mục 14).
2. Chép `upload-keystore.jks` vào `android\app\` và `key.properties` vào `android\`.
3. Build lại như trên. Không cần tạo khóa mới.

## Các khóa khác của dự án (không nằm ở đây)

| Khóa | Nằm ở đâu | Ghi chú |
|---|---|---|
| Khóa dịch vụ Firebase (gửi thông báo) | VPS: `/etc/dtask/firebase-dtask.json` | Khóa gốc đã lộ trong chat; cần xóa và tạo khóa mới |
| Cấu hình Firebase của app (`google-services.json`) | `android\app\` | Công khai theo thiết kế, có trong git |
| Cấu hình môi trường của D Task API và gateway (mật khẩu DB, khóa JWT, khóa mã hóa secret đơn vị) | VPS: `/etc/dtask/*.env` | Mất khóa mã hóa của gateway thì phải cấp lại secret cho mọi đơn vị. Nên sao lưu riêng |
