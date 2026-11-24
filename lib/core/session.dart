import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'models.dart';
import 'push.dart';

/// Lưu phiên trên máy: mã đăng nhập trong kho khóa an toàn (Keychain / Keystore),
/// phần còn lại (đơn vị đã chọn, thông tin người dùng) trong bộ nhớ thường.
class SessionStore {
  SessionStore(this._prefs, [FlutterSecureStorage? secure]) : _secure = secure ?? const FlutterSecureStorage();
  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  static const _tenantKey = 'tenant';
  static const _userKey = 'user';
  static const _tokenKey = 'token';

  Future<Session> load() async {
    Tenant? tenant;
    AppUser? user;
    try {
      final t = _prefs.getString(_tenantKey);
      if (t != null) tenant = Tenant.fromJson(jsonDecode(t) as Map<String, dynamic>);
      final u = _prefs.getString(_userKey);
      if (u != null) user = AppUser.fromJson(jsonDecode(u) as Map<String, dynamic>);
    } catch (_) {
      // dữ liệu hỏng thì coi như chưa chọn đơn vị
      tenant = null;
      user = null;
    }
    String? token;
    try {
      token = await _secure.read(key: _tokenKey);
    } catch (_) {
      token = null;
    }
    if (tenant == null) return const Session();
    return Session(tenant: tenant, token: token, user: token == null ? null : user);
  }

  Future<void> save(Session s) async {
    if (s.tenant == null) {
      await _prefs.remove(_tenantKey);
    } else {
      await _prefs.setString(_tenantKey, jsonEncode(s.tenant!.toJson()));
    }
    if (s.user == null) {
      await _prefs.remove(_userKey);
    } else {
      await _prefs.setString(_userKey, jsonEncode(s.user!.toJson()));
    }
    try {
      if (s.token == null) {
        await _secure.delete(key: _tokenKey);
      } else {
        await _secure.write(key: _tokenKey, value: s.token);
      }
    } catch (_) {
      // kho khóa lỗi: phiên chỉ sống trong lần mở app này
    }
  }
}

class Session {
  const Session({this.tenant, this.token, this.user, this.notice});

  final Tenant? tenant;
  final String? token;
  final AppUser? user;

  /// Thông báo hiển thị ở màn hình chọn đơn vị (ví dụ đơn vị bị tạm ngưng).
  final String? notice;

  bool get loggedIn => tenant != null && token != null;

  bool hasFeature(String code) => tenant?.hasFeature(code) ?? false;
  bool can(String permission) => user?.can(permission) ?? false;

  Session copyWith({Tenant? tenant, String? token, AppUser? user}) => Session(tenant: tenant ?? this.tenant, token: token ?? this.token, user: user ?? this.user);
}

final sessionStoreProvider = Provider<SessionStore>((ref) => throw UnimplementedError('sessionStoreProvider phải được override ở main'));
final initialSessionProvider = Provider<Session>((ref) => const Session());
final gatewayProvider = Provider<GatewayApi>((ref) => GatewayApi());

final sessionProvider = NotifierProvider<SessionNotifier, Session>(SessionNotifier.new);

class SessionNotifier extends Notifier<Session> {
  @override
  Session build() => ref.read(initialSessionProvider);

  SessionStore get _store => ref.read(sessionStoreProvider);

  void _set(Session s) {
    state = s;
    _store.save(s);
  }

  /// Chọn đơn vị mới (mã đã được gateway xác nhận). Xóa phiên đăng nhập cũ.
  void selectTenant(Tenant tenant) => _set(Session(tenant: tenant));

  /// Gỡ thiết bị khỏi tài khoản trên máy chủ (nếu đang đăng nhập) trước khi bỏ token, tối đa vài giây.
  Future<void> _detachDevice() async {
    if (!state.loggedIn) return;
    final api = ref.read(apiProvider);
    try {
      await ref.read(pushProvider).stop(api).timeout(const Duration(seconds: 4));
    } catch (_) {
      // không chặn đăng xuất
    }
  }

  /// Về màn hình chọn đơn vị, giữ lại [notice] để giải thích.
  Future<void> leaveTenant([String? notice]) async {
    await _detachDevice();
    state = Session(notice: notice);
    _store.save(const Session());
  }

  Future<void> login(String username, String password) async {
    final tenant = state.tenant;
    if (tenant == null) return;
    final r = await ref.read(apiProvider)!.login(username.trim(), password);
    _set(Session(tenant: tenant, token: r.token, user: r.user));
  }

  Future<void> logout() async {
    await _detachDevice();
    final tenant = state.tenant;
    _set(Session(tenant: tenant));
  }

  /// Máy chủ trả 401: bỏ phiên đăng nhập nhưng giữ đơn vị để đăng nhập lại nhanh.
  void expire() {
    if (state.token == null) return;
    _set(Session(tenant: state.tenant)); // token đã hỏng nên không gọi máy chủ để gỡ thiết bị
  }

  /// Làm mới cờ tính năng và địa chỉ API từ gateway mỗi lần mở app. Lỗi mạng thì giữ bản đã lưu.
  Future<void> refreshTenant() async {
    final current = state.tenant;
    if (current == null) return;
    try {
      final fresh = await ref.read(gatewayProvider).resolve(current.code);
      if (state.tenant?.code != current.code) return;
      _set(state.copyWith(tenant: fresh));
    } on ApiError catch (e) {
      if (e.status == 403 || e.status == 404) leaveTenant(e.message);
    }
  }

  /// Kiểm tra token còn dùng được và lấy quyền mới nhất.
  Future<void> refreshUser() async {
    if (!state.loggedIn) return;
    try {
      final user = await ref.read(apiProvider)!.me();
      _set(state.copyWith(user: user));
    } on ApiError {
      // 401 đã được interceptor xử lý; lỗi khác (mạng) thì dùng thông tin đã lưu
    }
  }
}

/// API của đơn vị đang chọn; null khi chưa chọn đơn vị.
final apiProvider = Provider<TenantApi?>((ref) {
  final tenant = ref.watch(sessionProvider.select((s) => s.tenant));
  if (tenant == null) return null;
  return TenantApi(
    tenant,
    token: () => ref.read(sessionProvider).token,
    onUnauthorized: () => ref.read(sessionProvider.notifier).expire(),
  );
});
