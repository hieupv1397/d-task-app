import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Một lần đăng nhập thành công: tài khoản [username] của đơn vị [code].
class RecentLogin {
  const RecentLogin({required this.code, required this.username, this.tenantName});
  final String code;
  final String username;
  final String? tenantName;

  Map<String, dynamic> toJson() => {'code': code, 'user': username, 'name': tenantName};
}

/// Ghi nhớ trên thiết bị để nhập nhanh. Mỗi tài khoản được nhớ riêng theo từng đơn vị
/// (cùng tên đăng nhập ở hai đơn vị là hai mục khác nhau). Mật khẩu chỉ nằm trong kho khóa
/// an toàn (Keychain / Keystore), không bao giờ ghi vào bộ nhớ thường.
class RememberStore {
  RememberStore(this._prefs, [FlutterSecureStorage? secure]) : _secure = secure ?? const FlutterSecureStorage();
  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  static const _loginsKey = 'remember.logins';
  static const _pwKey = 'remember.pw';

  /// Số mã đơn vị gợi ý tối đa, số tài khoản gợi ý tối đa cho mỗi đơn vị, và tổng số mục lưu.
  static const maxItems = 5;
  static const maxLogins = 12;

  /// Các lần đăng nhập thành công gần đây, mới nhất trước; mỗi (đơn vị, tài khoản) một mục.
  List<RecentLogin> recentLogins() {
    try {
      final raw = _prefs.getString(_loginsKey);
      if (raw == null) return const [];
      return (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map((e) => RecentLogin(code: e['code'] as String, username: e['user'] as String, tenantName: e['name'] as String?))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  List<String> recentCodes() => {for (final l in recentLogins()) l.code}.take(maxItems).toList();

  /// Tên đăng nhập đã dùng thành công với [code] (mới nhất trước).
  List<String> recentUsers(String code) => [for (final l in recentLogins()) if (l.code == code.toUpperCase()) l.username];

  Future<void> recordSuccess(String code, String username, {String? tenantName}) async {
    final c = code.toUpperCase();
    final u = username.trim();
    final old = recentLogins();
    final previous = old.where((l) => _same(l, c, u)).firstOrNull;
    final entry = RecentLogin(code: c, username: u, tenantName: tenantName ?? previous?.tenantName);
    var list = [entry, ...old.where((l) => !_same(l, c, u))];
    // Mỗi đơn vị giữ tối đa maxItems tài khoản mới nhất.
    final perCode = <String, int>{};
    list = list.where((l) => (perCode[l.code] = (perCode[l.code] ?? 0) + 1) <= maxItems).take(maxLogins).toList();
    await _save(list);
  }

  Future<String?> password(String code, String username) async {
    try {
      return (await _readPw())[_pwId(code, username)];
    } catch (_) {
      return null;
    }
  }

  Future<bool> hasPassword(String code, String username) async => (await password(code, username)) != null;

  Future<void> savePassword(String code, String username, String password) async {
    final map = await _readPw();
    map[_pwId(code, username)] = password;
    await _writePw(map);
  }

  Future<void> clearPassword(String code, String username) async {
    final map = await _readPw();
    if (map.remove(_pwId(code, username)) != null) await _writePw(map);
  }

  /// Xóa tài khoản này của đơn vị này khỏi gợi ý, kèm mật khẩu đã lưu của nó.
  Future<void> forgetUser(String code, String username) async {
    final c = code.toUpperCase();
    await _save(recentLogins().where((l) => !_same(l, c, username.trim())).toList());
    await clearPassword(code, username);
  }

  // ---- nội bộ
  static bool _same(RecentLogin l, String code, String username) => l.code == code && l.username.toLowerCase() == username.toLowerCase();

  static String _pwId(String code, String username) => '${code.toUpperCase()}|${username.trim().toLowerCase()}';

  Future<void> _save(List<RecentLogin> list) => _prefs.setString(_loginsKey, jsonEncode([for (final l in list) l.toJson()]));

  Future<Map<String, String>> _readPw() async {
    try {
      final raw = await _secure.read(key: _pwKey);
      if (raw == null) return {};
      return (jsonDecode(raw) as Map<String, dynamic>).map((k, v) => MapEntry(k, v as String));
    } catch (_) {
      return {};
    }
  }

  Future<void> _writePw(Map<String, String> map) async {
    try {
      if (map.isEmpty) {
        await _secure.delete(key: _pwKey);
      } else {
        await _secure.write(key: _pwKey, value: jsonEncode(map));
      }
    } catch (_) {
      // kho khóa lỗi: coi như không ghi nhớ được, không làm hỏng luồng đăng nhập
    }
  }
}

final rememberProvider = Provider<RememberStore>((ref) => throw UnimplementedError('rememberProvider phải được override ở main'));

/// Tên đăng nhập được chọn từ màn hình chọn đơn vị, để màn đăng nhập điền sẵn đúng tài khoản đó.
class PendingUsername extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? value) => state = value;
}

final pendingUsernameProvider = NotifierProvider<PendingUsername, String?>(PendingUsername.new);
