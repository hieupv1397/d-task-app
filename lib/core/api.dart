import 'package:dio/dio.dart';

import 'config.dart';
import 'models.dart';

/// Lỗi đã được chuyển thành câu tiếng Việt để hiển thị trực tiếp cho người dùng.
class ApiError implements Exception {
  ApiError(this.message, {this.status, this.code, this.otpTransactionId});
  final String message;
  final int? status;
  final String? code;
  /// Mã giao dịch OTP khi nhà cung cấp ký số yêu cầu nhập mã xác thực.
  final String? otpTransactionId;

  bool get needsOtp => code == 'OTP_REQUIRED' || code == 'OTP_INVALID';

  @override
  String toString() => message;
}

ApiError toApiError(Object e) {
  if (e is ApiError) return e;
  if (e is DioException) {
    final status = e.response?.statusCode;
    if (status == null) {
      return ApiError('Không kết nối được máy chủ. Vui lòng kiểm tra mạng rồi thử lại.');
    }
    final data = e.response?.data;
    String? message;
    String? code;
    String? otpTx;
    if (data is String && data.trim().isNotEmpty) {
      message = data.trim();
    } else if (data is Map) {
      final title = data['title'];
      if (title is String && title.isNotEmpty && !title.startsWith('One or more')) message = title;
      final m = data['message'];
      if (message == null && m is String && m.isNotEmpty) message = m;
      final c = data['code'];
      if (c is String) code = c;
      final o = data['otpTransactionId'];
      if (o != null) otpTx = o.toString();
    }
    message ??= switch (status) {
      401 => 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
      403 => 'Bạn không có quyền thực hiện thao tác này.',
      404 => 'Không tìm thấy dữ liệu.',
      409 => 'Dữ liệu đã được người khác thay đổi. Vui lòng tải lại rồi thử lại.',
      _ => 'Có lỗi xảy ra (mã $status). Vui lòng thử lại.',
    };
    return ApiError(message, status: status, code: code, otpTransactionId: otpTx);
  }
  return ApiError('Có lỗi xảy ra. Vui lòng thử lại.');
}

Dio _dio(String baseUrl) => Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json'},
    ));

/// Gateway chung: tra mã đơn vị để biết đơn vị đó dùng API nào.
class GatewayApi {
  GatewayApi({String? baseUrl}) : _dio0 = _dio(baseUrl ?? AppConfig.gatewayUrl);
  final Dio _dio0;

  Future<Tenant> resolve(String code) async {
    final c = code.trim().toUpperCase();
    try {
      final r = await _dio0.get<Map<String, dynamic>>('/api/v1/public/partners/${Uri.encodeComponent(c)}');
      return Tenant.fromJson(r.data!);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 404) throw ApiError('Không tìm thấy đơn vị với mã này. Vui lòng kiểm tra lại mã.', status: 404);
      if (status == 403) throw ApiError('Đơn vị này đang tạm ngưng sử dụng. Vui lòng liên hệ quản trị đơn vị.', status: 403, code: 'PARTNER_SUSPENDED');
      if (status == 429) throw ApiError('Bạn thử quá nhiều lần. Vui lòng đợi một chút rồi thử lại.', status: 429);
      throw toApiError(e);
    }
  }
}

/// API của D Task thuộc một đơn vị. [token] đọc mỗi lần gọi để luôn lấy mã mới nhất;
/// [onUnauthorized] chạy khi máy chủ trả 401 (phiên hết hạn).
class TenantApi {
  TenantApi(Tenant tenant, {required this.token, required this.onUnauthorized}) : _dio0 = _dio(tenant.apiBaseUrl) {
    _dio0.interceptors.add(InterceptorsWrapper(
      onRequest: (o, h) {
        final t = token();
        if (t != null) o.headers['Authorization'] = 'Bearer $t';
        h.next(o);
      },
      onError: (e, h) {
        if (e.response?.statusCode == 401 && e.requestOptions.path != '/api/v1/auth/login') onUnauthorized();
        h.next(e);
      },
    ));
  }

  final String? Function() token;
  final void Function() onUnauthorized;
  final Dio _dio0;

  Future<T> _run<T>(Future<T> Function() call) async {
    try {
      return await call();
    } catch (e) {
      throw toApiError(e);
    }
  }

  // ---- đăng nhập
  Future<({String token, AppUser user})> login(String username, String password) => _run(() async {
        final r = await _dio0.post<Map<String, dynamic>>('/api/v1/auth/login', data: {'username': username, 'password': password});
        return (token: r.data!['accessToken'] as String, user: AppUser.fromJson(r.data!['user'] as Map<String, dynamic>));
      });

  Future<AppUser> me() => _run(() async => AppUser.fromJson((await _dio0.get<Map<String, dynamic>>('/api/v1/auth/me')).data!));

  Future<void> changePassword(String current, String next) =>
      _run(() => _dio0.put('/api/v1/profile/me/password', data: {'currentPassword': current, 'newPassword': next}));

  // ---- trang chủ, việc
  Future<HomeData> home() => _run(() async {
        final j = (await _dio0.get<Map<String, dynamic>>('/api/v1/app/home')).data!;
        return HomeData(
          HomeCounts.fromJson(j['counts'] as Map<String, dynamic>),
          (j['tasks'] as List).map((e) => AppTask.fromJson(e as Map<String, dynamic>)).toList(),
        );
      });

  Future<TaskPage> tasks({required String scope, String? keyword, int page = 1, int pageSize = 20}) => _run(() async {
        final j = (await _dio0.get<Map<String, dynamic>>('/api/v1/app/tasks', queryParameters: {
          'scope': scope,
          if (keyword != null && keyword.trim().isNotEmpty) 'keyword': keyword.trim(),
          'pageNumber': page,
          'pageSize': pageSize,
        })).data!;
        return TaskPage((j['items'] as List).map((e) => AppTask.fromJson(e as Map<String, dynamic>)).toList(), j['totalCount'] as int);
      });

  Future<TaskDetail> taskDetail(int id) =>
      _run(() async => TaskDetail.fromJson((await _dio0.get<Map<String, dynamic>>('/api/v1/tasks/$id')).data!));

  Future<void> reportProgress(int id, {required double percent, String? content, String? risks, String? proposal, required int rowVersion}) =>
      _run(() => _dio0.post('/api/v1/tasks/$id/progress', data: {
            'progressPercent': percent,
            'content': _blank(content),
            'risks': _blank(risks),
            'proposal': _blank(proposal),
            'rowVersion': rowVersion,
          }));

  Future<void> workflowAction(int id, {required String code, String? comment, required int rowVersion}) =>
      _run(() => _dio0.post('/api/v1/tasks/$id/workflow-actions', data: {'transitionCode': code, 'comment': _blank(comment), 'rowVersion': rowVersion}));

  // ---- văn bản
  Future<DocumentInbox> documents({required String scope, int pageSize = 30}) => _run(() async {
        final j = (await _dio0.get<Map<String, dynamic>>('/api/v1/documents/inbox', queryParameters: {'scope': scope, 'pageSize': pageSize})).data!;
        return DocumentInbox(
          items: (j['items'] as List).map((e) => DocumentItem.fromJson(e as Map<String, dynamic>)).toList(),
          pending: j['pendingCount'] as int,
          submitted: j['submittedCount'] as int,
          done: j['doneCount'] as int,
          all: j['allCount'] as int,
        );
      });

  Future<DocumentItem> document(int id) =>
      _run(() async => DocumentItem.fromJson((await _dio0.get<Map<String, dynamic>>('/api/v1/documents/$id')).data!));

  /// Tải nội dung tệp của văn bản (kèm token). Bỏ [versionId] để lấy phiên bản mới nhất.
  Future<List<int>> downloadDocument(int id, {int? versionId}) => _run(() async {
        final r = await _dio0.get<List<int>>('/api/v1/documents/$id/download',
            queryParameters: {'versionId': ?versionId}, options: Options(responseType: ResponseType.bytes, receiveTimeout: const Duration(seconds: 90)));
        return r.data ?? const <int>[];
      });

  /// Xem một phiên bản dưới dạng PDF: Word, Excel, PowerPoint được máy chủ chuyển tạm sang PDF.
  Future<List<int>> previewDocumentPdf(int id, {int? versionId}) => _run(() async {
        final r = await _dio0.get<List<int>>('/api/v1/documents/$id/preview-pdf',
            queryParameters: {'versionId': ?versionId}, options: Options(responseType: ResponseType.bytes, receiveTimeout: const Duration(seconds: 120)));
        return r.data ?? const <int>[];
      });

  /// Văn bản của một công việc (kể cả đang nháp hoặc đang ký) mà người dùng được xem.
  Future<List<DocumentItem>> taskDocuments(int taskId) => _run(() async {
        final j = (await _dio0.get<Map<String, dynamic>>('/api/v1/tasks/$taskId/documents')).data!;
        return ((j['items'] as List?) ?? const []).map((e) => DocumentItem.fromJson(e as Map<String, dynamic>)).toList();
      });

  /// [decision] là APPROVE hoặc REJECT. Duyệt cần mật khẩu để xác nhận chữ ký.
  Future<DocumentItem> actOnDocument(int id, {required String decision, String? comment, String? password, String? otp, String? otpTransactionId}) => _run(() async {
        final r = await _dio0.post<Map<String, dynamic>>('/api/v1/documents/$id/act',
            data: {'decision': decision, 'comment': _blank(comment), 'password': password, 'otp': _blank(otp), 'otpTransactionId': otpTransactionId});
        return DocumentItem.fromJson(r.data!);
      });

  // ---- thiết bị nhận thông báo đẩy
  Future<void> registerDevice({required String pushToken, required String platform, String? appVersion, String? deviceName}) => _run(() => _dio0.post(
      '/api/v1/app/devices', data: {'pushToken': pushToken, 'platform': platform, 'appVersion': appVersion, 'deviceName': deviceName}));

  Future<void> unregisterDevice(String pushToken) => _run(() => _dio0.post('/api/v1/app/devices/unregister', data: {'pushToken': pushToken}));

  /// Nhờ máy chủ gửi một thông báo thử tới các thiết bị của mình (đi đủ đường qua gateway và Firebase).
  Future<({bool configured, int devices, int sent, int failed, String message})> pushTest() => _run(() async {
        final j = (await _dio0.post<Map<String, dynamic>>('/api/v1/app/push-test')).data!;
        return (configured: j['configured'] == true, devices: j['devices'] as int, sent: j['sent'] as int, failed: j['failed'] as int, message: j['message'] as String);
      });

  // ---- thông báo
  Future<({int unread, List<NotificationItem> items})> notifications() => _run(() async {
        final j = (await _dio0.get<Map<String, dynamic>>('/api/v1/notifications', queryParameters: {'limit': 50})).data!;
        return (unread: j['unread'] as int, items: (j['items'] as List).map((e) => NotificationItem.fromJson(e as Map<String, dynamic>)).toList());
      });

  Future<void> markRead(int id) => _run(() => _dio0.post('/api/v1/notifications/$id/read'));
  Future<void> markAllRead() => _run(() => _dio0.post('/api/v1/notifications/read-all'));

  static String? _blank(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();
}
