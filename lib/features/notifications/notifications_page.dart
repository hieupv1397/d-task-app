import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../shared/brand.dart';
import '../../shared/user_menu.dart';
import '../../shared/widgets.dart';
import '../home/home_page.dart';

final notificationsProvider = FutureProvider.autoDispose<({int unread, List<NotificationItem> items})>((ref) => ref.watch(apiProvider)!.notifications());

(IconData, Color) _look(String type) => switch (type) {
      'DOC_SIGN_REQUEST' => (Icons.draw_rounded, Brand.blue),
      'DOC_COMPLETED' => (Icons.verified_rounded, Brand.ok),
      'DOC_REJECTED' => (Icons.cancel_rounded, Brand.bad),
      'TASK_OVERDUE' || 'TASK_ESCALATION' => (Icons.local_fire_department_rounded, Brand.bad),
      'TASK_DUE_SOON' => (Icons.schedule_rounded, Brand.warn),
      _ => (Icons.notifications_rounded, Brand.violet),
    };

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(notificationsProvider);
    return Scaffold(
      appBar: AppBar(
        leading: const MenuButton(),
        title: const Text('Thông báo'),
        actions: [
          if ((data.value?.unread ?? 0) > 0)
            TextButton(
              onPressed: () async {
                try {
                  await ref.read(apiProvider)!.markAllRead();
                  ref.invalidate(notificationsProvider);
                  ref.invalidate(homeProvider);
                } catch (e) {
                  if (context.mounted) showSnack(context, errorText(e), error: true);
                }
              },
              child: const Text('Đọc tất cả'),
            ),
          const UserMenuButton(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(notificationsProvider.future),
        child: AsyncView(
          value: data,
          onRetry: () => ref.invalidate(notificationsProvider),
          builder: (d) => d.items.isEmpty
              ? const EmptyView(icon: Icons.notifications_off_rounded, text: 'Chưa có thông báo nào')
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(top: 10, bottom: 24),
                  itemCount: d.items.length,
                  itemBuilder: (_, i) => _Tile(item: d.items[i]),
                ),
        ),
      ),
    );
  }
}

class _Tile extends ConsumerWidget {
  const _Tile({required this.item});
  final NotificationItem item;

  /// Chạm vào thì đánh dấu đã đọc rồi mở đúng việc hoặc văn bản liên quan.
  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final router = GoRouter.of(context);
    if (!item.isRead) {
      try {
        await ref.read(apiProvider)!.markRead(item.id);
        ref.invalidate(notificationsProvider);
        ref.invalidate(homeProvider);
      } catch (_) {
        // không chặn việc mở nội dung
      }
    }
    // Thông báo văn bản gắn với công việc (entityId là mã công việc), nên đưa người dùng tới hộp văn bản.
    if (item.type.startsWith('DOC_')) {
      router.go('/documents');
      return;
    }
    final id = item.entityId;
    if (id != null) router.push('/task/$id');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (icon, color) = _look(item.type);
    return AppCard(
      onTap: () => _open(context, ref),
      accent: item.isRead ? null : color,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        IconBadge(icon: icon, color: color, solid: !item.isRead),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.title, style: TextStyle(fontWeight: item.isRead ? FontWeight.w600 : FontWeight.w800, fontSize: 14.5, height: 1.3)),
            if (item.body != null && item.body!.trim().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text(item.body!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Brand.mute, fontSize: 13, height: 1.35))),
            const SizedBox(height: 5),
            Text('${item.actorName == null ? '' : '${item.actorName} · '}${fmtDateTime(item.createdAt)}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF9AA8BC))),
          ]),
        ),
        if (!item.isRead) Padding(padding: const EdgeInsets.only(left: 8, top: 4), child: Container(width: 9, height: 9, decoration: const BoxDecoration(color: Brand.blue, shape: BoxShape.circle))),
      ]),
    );
  }
}
