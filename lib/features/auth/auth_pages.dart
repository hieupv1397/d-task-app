import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/models.dart';
import '../../core/remember.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../shared/brand.dart';
import '../../shared/widgets.dart';

/// Khung chung của các màn hình trước đăng nhập: nửa trên là nền gradient có logo, nửa dưới là tờ giấy bo góc chứa biểu mẫu.
class _AuthFrame extends StatelessWidget {
  const _AuthFrame({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Brand.bg,
      body: LayoutBuilder(builder: (context, box) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight),
            child: IntrinsicHeight(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const _AuthHero(),
                Expanded(
                  child: Transform.translate(
                    offset: const Offset(0, -28),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                      decoration: const BoxDecoration(color: Brand.bg, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
                      child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children))),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        );
      }),
    );
  }
}

class _AuthHero extends StatelessWidget {
  const _AuthHero();

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return HeroBackground(
      bottomRadius: 0,
      padding: EdgeInsets.fromLTRB(24, top + 34, 24, 56),
      child: Column(children: [
        Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0x40FFFFFF), Color(0x14FFFFFF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
          ),
          child: const Center(child: ShieldLogo(size: 60)),
        ),
        const SizedBox(height: 16),
        const Text('D Task', style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        const SizedBox(height: 4),
        Text('Công việc và văn bản trong túi áo', style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 14.5)),
        const SizedBox(height: 18),
        const Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
          _GlassChip(icon: Icons.task_alt_rounded, label: 'Việc của tôi'),
          _GlassChip(icon: Icons.draw_rounded, label: 'Ký văn bản'),
          _GlassChip(icon: Icons.notifications_active_rounded, label: 'Thông báo'),
        ]),
      ]),
    );
  }
}

class _GlassChip extends StatelessWidget {
  const _GlassChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.28))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
        ]),
      );
}

/// Ô nhập mã đơn vị 4 chữ số: bốn ô lớn hiển thị, một ô nhập ẩn phía trên để nhận bàn phím.
class _CodeBoxes extends StatefulWidget {
  const _CodeBoxes({required this.controller, required this.enabled, required this.onChanged, required this.onSubmitted, this.error});
  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;
  final String? error;

  @override
  State<_CodeBoxes> createState() => _CodeBoxesState();
}

class _CodeBoxesState extends State<_CodeBoxes> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ListenableBuilder(
        listenable: Listenable.merge([widget.controller, _focus]),
        builder: (context, _) {
          final text = widget.controller.text;
          final cursor = text.length.clamp(0, 3);
          return Semantics(
            textField: true,
            label: 'Mã đơn vị 4 chữ số',
            child: Stack(children: [
              Row(children: [
                for (var i = 0; i < 4; i++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: i == 0 ? 0 : 10),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        height: 64,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: widget.error != null ? Brand.bad : (_focus.hasFocus && i == cursor) ? Brand.blue : const Color(0xFFD9E4F2),
                            width: (_focus.hasFocus && i == cursor) || widget.error != null ? 2 : 1,
                          ),
                          boxShadow: i < text.length ? Brand.tinyShadow : null,
                        ),
                        child: Text(i < text.length ? text[i] : '', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Brand.blue)),
                      ),
                    ),
                  ),
              ]),
              Positioned.fill(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  enabled: widget.enabled,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textInputAction: TextInputAction.go,
                  autocorrect: false,
                  enableSuggestions: false,
                  maxLength: 4,
                  showCursor: false,
                  enableInteractiveSelection: false,
                  cursorColor: Colors.transparent,
                  style: const TextStyle(color: Colors.transparent, fontSize: 1),
                  buildCounter: (_, {required currentLength, required isFocused, required maxLength}) => null,
                  onChanged: widget.onChanged,
                  onSubmitted: (_) => widget.onSubmitted(),
                  decoration: const InputDecoration.collapsed(hintText: ''),
                ),
              ),
            ]),
          );
        },
      ),
      const SizedBox(height: 10),
      if (widget.error != null)
        Row(children: [const Icon(Icons.error_outline, size: 16, color: Brand.bad), const SizedBox(width: 6), Expanded(child: Text(widget.error!, style: const TextStyle(color: Brand.bad, fontSize: 13)))])
      else
        const Text('Gồm 4 chữ số do quản trị đơn vị cung cấp', style: TextStyle(color: Brand.mute, fontSize: 13)),
    ]);
  }
}

/// Màn hình chọn đơn vị: người dùng nhập mã, app hỏi gateway để biết đơn vị dùng API nào.
class TenantPage extends ConsumerStatefulWidget {
  const TenantPage({super.key, this.initialCode});
  final String? initialCode;

  @override
  ConsumerState<TenantPage> createState() => _TenantPageState();
}

class _TenantPageState extends ConsumerState<TenantPage> {
  late final _code = TextEditingController(text: widget.initialCode);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit({String? code0, String? username}) async {
    if (code0 != null) _code.text = code0;
    final code = _code.text.trim();
    if (!RegExp(r'^\d{4}$').hasMatch(code)) {
      setState(() => _error = 'Vui lòng nhập mã đơn vị gồm 4 chữ số.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final tenant = await ref.read(gatewayProvider).resolve(code);
      ref.read(pendingUsernameProvider.notifier).set(username);
      ref.read(sessionProvider.notifier).selectTenant(tenant);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notice = ref.watch(sessionProvider.select((s) => s.notice));
    final scheme = Theme.of(context).colorScheme;
    final store = ref.read(rememberProvider);
    final logins = store.recentLogins();
    return _AuthFrame(children: [
      const Text('Chào mừng bạn', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      const Text('Nhập mã đơn vị để bắt đầu', style: TextStyle(color: Brand.mute, fontSize: 15)),
      const SizedBox(height: 22),
      if (notice != null) ...[
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: scheme.errorContainer.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(14)),
          child: Row(children: [const Icon(Icons.info_outline, color: Brand.bad, size: 20), const SizedBox(width: 10), Expanded(child: Text(notice, style: const TextStyle(color: Brand.bad)))]),
        ),
        const SizedBox(height: 16),
      ],
      _CodeBoxes(
        controller: _code,
        enabled: !_busy,
        error: _error,
        onChanged: (v) {
          if (_error != null) setState(() => _error = null);
          if (v.length == 4 && !_busy) _submit(); // đủ 4 số thì vào luôn, không cần bấm nút
        },
        onSubmitted: _submit,
      ),
      const SizedBox(height: 20),
      GradientButton(label: 'Tiếp tục', icon: Icons.arrow_forward_rounded, busy: _busy, onPressed: _submit),
      if (logins.isNotEmpty) ...[
        const SizedBox(height: 26),
        const Text('Đăng nhập gần đây', style: TextStyle(fontSize: 13, color: Brand.mute, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        for (final l in logins)
          AppCard(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            onTap: _busy ? null : () => _submit(code0: l.code, username: l.username),
            child: Row(children: [
              AppAvatar(name: l.username, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.username, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('${l.tenantName ?? l.code} · mã ${l.code}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: Brand.mute)),
                ]),
              ),
              IconButton(
                tooltip: 'Quên tài khoản này',
                icon: const Icon(Icons.close, size: 18),
                onPressed: _busy
                    ? null
                    : () async {
                        await store.forgetUser(l.code, l.username);
                        if (mounted) setState(() {});
                      },
              ),
            ]),
          ),
      ],
      const Spacer(),
      const SizedBox(height: 20),
      const Center(child: Text('Mã đơn vị do quản trị đơn vị cung cấp.', style: TextStyle(fontSize: 12.5, color: Brand.mute))),
    ]);
  }
}

/// Đăng nhập tài khoản D Task của đơn vị đã chọn.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  bool _hide = true;
  bool _remember = false;
  List<String> _recentUsers = const [];
  String? _error;

  String get _code => ref.read(sessionProvider).tenant!.code;

  @override
  void initState() {
    super.initState();
    final store = ref.read(rememberProvider);
    _recentUsers = store.recentUsers(_code);
    // Tự điền tài khoản vừa chọn ở màn trước, hoặc tài khoản gần nhất của đơn vị này (và mật khẩu nếu đã ghi nhớ).
    final chosen = ref.read(pendingUsernameProvider);
    Future.microtask(() => ref.read(pendingUsernameProvider.notifier).set(null));
    final first = chosen ?? (_recentUsers.isNotEmpty ? _recentUsers.first : null);
    if (first != null) _pick(first);
  }

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _pick(String username) async {
    _user.text = username;
    final saved = await ref.read(rememberProvider).password(_code, username);
    if (!mounted) return;
    setState(() {
      _pass.text = saved ?? '';
      _remember = saved != null;
    });
  }

  Future<void> _forget(String username) async {
    final store = ref.read(rememberProvider);
    await store.forgetUser(_code, username);
    if (!mounted) return;
    setState(() {
      _recentUsers = store.recentUsers(_code);
      if (_user.text.trim().toLowerCase() == username.toLowerCase()) {
        _pass.clear();
        _remember = false;
      }
    });
  }

  Future<void> _submit() async {
    if (_user.text.trim().isEmpty || _pass.text.isEmpty) {
      setState(() => _error = 'Vui lòng nhập tên đăng nhập và mật khẩu.');
      return;
    }
    // Lấy trước các đối tượng cần dùng, vì đăng nhập xong màn hình này sẽ bị thay thế.
    final store = ref.read(rememberProvider);
    final notifier = ref.read(sessionProvider.notifier);
    final code = _code;
    final tenantName = ref.read(sessionProvider).tenant?.name;
    final username = _user.text.trim();
    final password = _pass.text;
    final remember = _remember;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await notifier.login(username, password);
      await store.recordSuccess(code, username, tenantName: tenantName);
      if (remember) {
        await store.savePassword(code, username, password);
      } else {
        await store.clearPassword(code, username);
      }
    } catch (e) {
      final err = toApiError(e);
      if (mounted) setState(() => _error = err.status == 400 || err.status == 401 ? 'Tên đăng nhập hoặc mật khẩu không đúng.' : err.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tenant = ref.watch(sessionProvider.select((s) => s.tenant))!;
    return _AuthFrame(children: [
      AppCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        child: Row(children: [
          TenantAvatar(tenant: tenant, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tenant.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              Text('Mã đơn vị ${tenant.code}', style: const TextStyle(color: Brand.mute, fontSize: 12.5)),
            ]),
          ),
          TextButton(onPressed: _busy ? null : () => ref.read(sessionProvider.notifier).leaveTenant(), child: const Text('Đổi')),
        ]),
      ),
      const SizedBox(height: 22),
      const Text('Đăng nhập', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      const Text('Dùng tài khoản D Task của bạn', style: TextStyle(color: Brand.mute, fontSize: 15)),
      const SizedBox(height: 20),
      TextField(
        controller: _user,
        enabled: !_busy,
        autocorrect: false,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.username],
        decoration: const InputDecoration(labelText: 'Tên đăng nhập', prefixIcon: Icon(Icons.person_outline_rounded)),
      ),
      if (_recentUsers.isNotEmpty) ...[
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 0, children: [
          for (final u in _recentUsers)
            InputChip(
              avatar: AppAvatar(name: u, size: 20),
              label: Text(u),
              selected: _user.text.trim().toLowerCase() == u.toLowerCase(),
              onPressed: _busy ? null : () => _pick(u),
              onDeleted: _busy ? null : () => _forget(u),
              deleteButtonTooltipMessage: 'Quên tên này',
            ),
        ]),
      ],
      const SizedBox(height: 14),
      TextField(
        controller: _pass,
        enabled: !_busy,
        obscureText: _hide,
        textInputAction: TextInputAction.go,
        autofillHints: const [AutofillHints.password],
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: 'Mật khẩu',
          prefixIcon: const Icon(Icons.lock_outline_rounded),
          suffixIcon: IconButton(icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined), onPressed: () => setState(() => _hide = !_hide)),
        ),
      ),
      const SizedBox(height: 6),
      SwitchListTile(
        value: _remember,
        onChanged: _busy ? null : (v) => setState(() => _remember = v),
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: const Text('Ghi nhớ mật khẩu trên máy này', style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: const Text('Lưu trong kho khóa an toàn của máy, tự điền khi đăng nhập và khi ký.', style: TextStyle(fontSize: 12)),
      ),
      if (_error != null) ...[
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: Brand.bad.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [const Icon(Icons.error_outline, size: 18, color: Brand.bad), const SizedBox(width: 8), Expanded(child: Text(_error!, style: const TextStyle(color: Brand.bad, fontSize: 13.5)))]),
        ),
      ],
      const SizedBox(height: 18),
      GradientButton(label: 'Đăng nhập', icon: Icons.login_rounded, busy: _busy, onPressed: _submit),
      const Spacer(),
      const SizedBox(height: 20),
    ]);
  }
}

/// Chặn dùng app khi phiên bản thấp hơn mức tối thiểu đơn vị yêu cầu.
class UpdateRequiredPage extends ConsumerWidget {
  const UpdateRequiredPage({super.key, required this.minVersion});
  final String minVersion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const EmptyIllustration(icon: Icons.system_update_rounded, title: 'Cần cập nhật ứng dụng'),
                Text('Đơn vị của bạn yêu cầu phiên bản $minVersion trở lên. Vui lòng cập nhật app rồi mở lại.', textAlign: TextAlign.center, style: const TextStyle(color: Brand.mute, height: 1.5)),
                const SizedBox(height: 20),
                TextButton(onPressed: () => ref.read(sessionProvider.notifier).leaveTenant(), child: const Text('Chọn đơn vị khác')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Logo đơn vị; chưa có logo thì hiện chữ cái đầu trên nền màu chủ đạo.
class TenantAvatar extends StatelessWidget {
  const TenantAvatar({super.key, required this.tenant, this.size = 40});
  final Tenant tenant;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = parseColor(tenant.primaryColor) ?? Brand.blue;
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(size * 0.22)),
      child: Text(tenant.name.isEmpty ? '?' : tenant.name.characters.first.toUpperCase(), style: TextStyle(color: Colors.white, fontSize: size * 0.45, fontWeight: FontWeight.w700)),
    );
    final url = tenant.logoUrl;
    if (url == null) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image.network(url, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback),
    );
  }
}

Color? parseColor(String hex) {
  final h = hex.replaceFirst('#', '');
  if (h.length != 6) return null;
  final v = int.tryParse(h, radix: 16);
  return v == null ? null : Color(0xFF000000 | v);
}
