import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../features/home/home_page.dart';
import '../features/notifications/notifications_page.dart';
import 'api.dart';
import 'session.dart';

/// Khóa để hiện thanh thông báo nhanh khi nhận tin lúc app đang mở.
final rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Đặt true khi Firebase khởi tạo được (có tệp cấu hình đúng); web và máy thiếu cấu hình thì tắt push.
bool firebaseReady = false;

Future<void> initFirebase() async {
  if (kIsWeb) return;
  try {
    await Firebase.initializeApp();
    firebaseReady = true;
  } catch (e) {
    debugPrint('Firebase chưa sẵn sàng, tắt thông báo đẩy: $e');
  }
}

/// Tin phải thuộc đúng đơn vị đang đăng nhập (gateway luôn gắn mã đơn vị vào dữ liệu tin).
bool pushMatchesTenant(Map<String, dynamic> data, String? tenantCode) {
  final t = '${data['tenant'] ?? ''}'.toUpperCase();
  return t.isEmpty || tenantCode == null || t == tenantCode.toUpperCase();
}

/// Điều hướng khi bấm thông báo: thông báo văn bản mở hộp văn bản, còn lại mở công việc liên quan.
String? routeForPush(Map<String, dynamic> data) {
  final type = '${data['type'] ?? ''}';
  if (type.startsWith('DOC_')) return '/documents';
  final id = int.tryParse('${data['entityId'] ?? ''}');
  return id == null ? '/notifications' : '/task/$id';
}

/// Đăng ký thiết bị với D Task API của đơn vị đang đăng nhập và xử lý tin nhận được.
class PushService {
  PushService(this._ref);
  final Ref _ref;
  String? _token;
  StreamSubscription<String>? _refreshSub;
  StreamSubscription<RemoteMessage>? _openedSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  bool _started = false;

  bool get _supported => firebaseReady && !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Gọi sau khi đăng nhập thành công (và mỗi lần mở app khi đã đăng nhập).
  Future<void> start() async {
    if (!_supported || _started) return;
    final session = _ref.read(sessionProvider);
    if (!session.loggedIn || session.tenant?.pushEnabled != true) return;
    _started = true;
    try {
      final messaging = FirebaseMessaging.instance;
      final perm = await messaging.requestPermission();
      if (perm.authorizationStatus == AuthorizationStatus.denied) return;
      // Hàm getToken đã được đánh dấu cũ nhưng vẫn là cách lấy mã gửi tin theo FCM HTTP v1; sẽ đổi khi có hướng dẫn thay thế ổn định.
      // ignore: deprecated_member_use
      _token = await messaging.getToken();
      await _register();
      // ignore: deprecated_member_use
      _refreshSub = messaging.onTokenRefresh.listen((t) {
        _token = t;
        _register();
      });
      _foregroundSub = FirebaseMessaging.onMessage.listen(_onForeground);
      _openedSub = FirebaseMessaging.onMessageOpenedApp.listen(_open);
      final initial = await messaging.getInitialMessage();
      if (initial != null) _open(initial);
    } catch (e) {
      debugPrint('Không bật được thông báo đẩy: $e');
      _started = false;
    }
  }

  Future<void> _register() async {
    final token = _token;
    final api = _ref.read(apiProvider);
    if (token == null || api == null) return;
    try {
      final info = _ref.read(appVersionProvider);
      await api.registerDevice(pushToken: token, platform: Platform.isIOS ? 'IOS' : 'ANDROID', appVersion: info);
    } on ApiError catch (e) {
      debugPrint('Đăng ký thiết bị thất bại: ${e.message}');
    }
  }

  /// Gỡ thiết bị khỏi tài khoản khi đăng xuất, để người sau dùng chung máy không nhận nhầm thông báo.
  Future<void> stop(TenantApi? api) async {
    final token = _token;
    await _refreshSub?.cancel();
    await _openedSub?.cancel();
    await _foregroundSub?.cancel();
    _refreshSub = _openedSub = _foregroundSub = null;
    _started = false;
    _token = null;
    if (token != null && api != null) {
      try {
        await api.unregisterDevice(token);
      } catch (_) {
        // không chặn đăng xuất; máy chủ sẽ tự chuyển mã sang người đăng nhập tiếp theo
      }
    }
  }

  void _open(RemoteMessage m) {
    if (!pushMatchesTenant(m.data, _ref.read(sessionProvider).tenant?.code)) return;
    final route = routeForPush(m.data);
    if (route == null) return;
    final router = _ref.read(routerProvider);
    if (route.startsWith('/task/')) {
      router.push(route);
    } else {
      router.go(route);
    }
  }

  void _onForeground(RemoteMessage m) {
    if (!pushMatchesTenant(m.data, _ref.read(sessionProvider).tenant?.code)) return;
    // Làm mới số đếm và hộp thông báo, rồi hiện thanh thông báo nhanh có nút Xem.
    _ref.invalidate(homeProvider);
    _ref.invalidate(notificationsProvider);
    final n = m.notification;
    if (n == null) return;
    rootMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text([if (n.title != null) n.title!, if (n.body != null) n.body!].join('\n'), maxLines: 3, overflow: TextOverflow.ellipsis),
        action: SnackBarAction(label: 'Xem', onPressed: () => _open(m)),
      ));
  }
}

final pushProvider = Provider<PushService>((ref) => PushService(ref));
