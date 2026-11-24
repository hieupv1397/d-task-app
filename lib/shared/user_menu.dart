import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/session.dart';
import 'brand.dart';

/// Khóa của khung chính, để nút menu ở mọi trang mở được ngăn kéo chức năng.
final shellScaffoldKey = GlobalKey<ScaffoldState>();

/// Nút ba gạch ở góc trái thanh đầu: mở menu chức năng.
class MenuButton extends StatelessWidget {
  const MenuButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Menu',
        icon: const Icon(Icons.menu),
        onPressed: () => shellScaffoldKey.currentState?.openDrawer(),
      );
}

void confirmAction(BuildContext context, {required String title, required String text, required String okLabel, required VoidCallback onYes, bool danger = false}) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(text),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error) : null,
          onPressed: () {
            Navigator.pop(ctx);
            onYes();
          },
          child: Text(okLabel),
        ),
      ],
    ),
  );
}

/// Nút ảnh đại diện ở thanh đầu của mọi trang chính: mở menu hồ sơ, đổi đơn vị, đăng xuất.
class UserMenuButton extends ConsumerWidget {
  const UserMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider.select((s) => s.user));
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<String>(
      tooltip: 'Tài khoản',
      offset: const Offset(0, 48),
      position: PopupMenuPosition.under,
      onSelected: (v) {
        switch (v) {
          case 'profile':
            context.go('/profile');
          case 'tenant':
            confirmAction(
              context,
              title: 'Đổi đơn vị?',
              text: 'Bạn sẽ đăng xuất và chọn lại đơn vị.',
              okLabel: 'Đổi đơn vị',
              onYes: () => ref.read(sessionProvider.notifier).leaveTenant(),
            );
          case 'logout':
            confirmAction(
              context,
              title: 'Đăng xuất?',
              text: 'Bạn cần đăng nhập lại để tiếp tục.',
              okLabel: 'Đăng xuất',
              danger: true,
              onYes: () => ref.read(sessionProvider.notifier).logout(),
            );
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(user?.fullName ?? '', style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface)),
            if ((user?.department ?? '').isNotEmpty) Text(user!.department, style: TextStyle(fontSize: 12, color: scheme.outline)),
          ]),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'profile', child: ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Icon(Icons.person_outline), title: Text('Tài khoản của tôi'))),
        const PopupMenuItem(value: 'tenant', child: ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Icon(Icons.swap_horiz), title: Text('Đổi đơn vị'))),
        PopupMenuItem(value: 'logout', child: ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Icon(Icons.logout, color: scheme.error), title: Text('Đăng xuất', style: TextStyle(color: scheme.error)))),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: AppAvatar(name: user?.fullName ?? '', size: 34),
      ),
    );
  }
}
