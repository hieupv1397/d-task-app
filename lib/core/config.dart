/// Cấu hình cố định của app. Gateway là địa chỉ chung duy nhất app biết trước;
/// địa chỉ API của từng đơn vị lấy từ gateway theo mã đơn vị.
class AppConfig {
  /// Có thể ghi đè khi chạy thử: `flutter run --dart-define=GATEWAY_URL=http://10.0.2.2:5301`
  static const gatewayUrl = String.fromEnvironment('GATEWAY_URL', defaultValue: 'https://donvi.hica.vn');
}

/// Mã tính năng do gateway quản lý (xem d-task-gateway README).
class Feature {
  static const taskProgress = 'TASK_PROGRESS';
  static const taskWorkflow = 'TASK_WORKFLOW';
  static const docView = 'DOC_VIEW';
  static const docSign = 'DOC_SIGN';
  static const notifications = 'NOTIFICATIONS';
}

/// So sánh phiên bản dạng 1.2.3. Trả true nếu [current] thấp hơn [minimum].
bool isVersionBelow(String current, String? minimum) {
  if (minimum == null || minimum.trim().isEmpty) return false;
  List<int> parse(String v) => v.split('+').first.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  final a = parse(current), b = parse(minimum);
  for (var i = 0; i < 3; i++) {
    final x = i < a.length ? a[i] : 0, y = i < b.length ? b[i] : 0;
    if (x != y) return x < y;
  }
  return false;
}
