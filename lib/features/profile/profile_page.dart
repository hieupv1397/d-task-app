import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../shared/brand.dart';
import '../../shared/user_menu.dart';
import '../../shared/widgets.dart';
import '../auth/auth_pages.dart';

final packageInfoProvider = FutureProvider<PackageInfo>((ref) => PackageInfo.fromPlatform());

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    final tenant = s.tenant!;
    final user = s.user;
    final version = ref.watch(packageInfoProvider).value;
    final top = MediaQuery.paddingOf(context).top;

    Widget group(List<Widget> rows) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Brand.line), boxShadow: Brand.tinyShadow),
          child: ClipRRect(borderRadius: BorderRadius.circular(20), child: Column(children: [for (var i = 0; i < rows.length; i++) ...[if (i > 0) const Divider(height: 1, indent: 64), rows[i]]])),
        );
    Widget row(IconData icon, Color color, String title, {String? sub, VoidCallback? onTap, Color? titleColor}) => ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          leading: IconBadge(icon: icon, color: color, size: 40),
          title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: titleColor)),
          subtitle: sub == null ? null : Text(sub, style: const TextStyle(fontSize: 12.5)),
          trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded, color: Color(0xFFB4C1D4)),
        );

    return Scaffold(
      backgroundColor: Brand.bg,
      body: ListView(padding: const EdgeInsets.only(bottom: 28), children: [
        HeroBackground(
          padding: EdgeInsets.fromLTRB(20, top + 10, 20, 26),
          child: Column(children: [
            Align(alignment: Alignment.centerLeft, child: IconButton(tooltip: 'Menu', icon: const Icon(Icons.menu_rounded, color: Colors.white), onPressed: () => shellScaffoldKey.currentState?.openDrawer())),
            AppAvatar(name: user?.fullName ?? '', size: 84, ring: true),
            const SizedBox(height: 12),
            Text(user?.fullName ?? '', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('@${user?.username ?? ''}', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13.5)),
            if ((user?.department ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.28))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.apartment_rounded, size: 15, color: Colors.white),
                  const SizedBox(width: 6),
                  Flexible(child: Text(user!.department, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600))),
                ]),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 8),
        group([
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            leading: TenantAvatar(tenant: tenant, size: 42),
            title: Text(tenant.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('Mã đơn vị ${tenant.code}'),
          ),
        ]),
        group([
          if (tenant.pushEnabled)
            row(Icons.notifications_active_rounded, Brand.warn, 'Gửi thông báo thử', sub: 'Kiểm tra máy này có nhận được thông báo đẩy không', onTap: () async {
              try {
                final r = await ref.read(apiProvider)!.pushTest();
                if (context.mounted) showSnack(context, r.message, error: r.sent == 0);
              } catch (e) {
                if (context.mounted) showSnack(context, errorText(e), error: true);
              }
            }),
          row(Icons.lock_reset_rounded, Brand.violet, 'Đổi mật khẩu', onTap: () => showDialog(context: context, builder: (_) => const _ChangePasswordDialog())),
          row(Icons.swap_horiz_rounded, Brand.teal, 'Đổi đơn vị', onTap: () => _confirm(context, 'Đổi đơn vị?', 'Bạn sẽ đăng xuất và chọn lại đơn vị.', () => ref.read(sessionProvider.notifier).leaveTenant())),
        ]),
        group([
          row(Icons.logout_rounded, Brand.bad, 'Đăng xuất', titleColor: Brand.bad, onTap: () => _confirm(context, 'Đăng xuất?', 'Bạn cần đăng nhập lại để tiếp tục.', () => ref.read(sessionProvider.notifier).logout())),
        ]),
        group([
          row(Icons.info_outline_rounded, Brand.blue, 'Phiên bản ứng dụng', sub: version == null ? '—' : '${version.version} (${version.buildNumber})'),
        ]),
      ]),
    );
  }

  void _confirm(BuildContext context, String title, String text, VoidCallback onYes) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              onYes();
            },
            child: const Text('Đồng ý'),
          ),
        ],
      ),
    );
  }
}

class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog();
  @override
  ConsumerState<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _again = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _again.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_current.text.isEmpty || _next.text.isEmpty) {
      setState(() => _error = 'Vui lòng nhập đủ mật khẩu hiện tại và mật khẩu mới.');
      return;
    }
    if (_next.text != _again.text) {
      setState(() => _error = 'Mật khẩu nhập lại chưa khớp.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(apiProvider)!.changePassword(_current.text, _next.text);
      if (!mounted) return;
      Navigator.pop(context);
      showSnack(context, 'Đã đổi mật khẩu.');
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Đổi mật khẩu'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: _current, obscureText: true, enabled: !_busy, decoration: const InputDecoration(labelText: 'Mật khẩu hiện tại', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _next, obscureText: true, enabled: !_busy, decoration: const InputDecoration(labelText: 'Mật khẩu mới', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _again, obscureText: true, enabled: !_busy, decoration: const InputDecoration(labelText: 'Nhập lại mật khẩu mới', border: OutlineInputBorder())),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        ]),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Hủy')),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('Lưu')),
      ],
    );
  }
}
