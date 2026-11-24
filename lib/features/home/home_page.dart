import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/config.dart';
import '../../core/models.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../shared/brand.dart';
import '../../shared/user_menu.dart';
import '../../shared/widgets.dart';
import '../auth/auth_pages.dart';
import '../documents/documents_page.dart';

final homeProvider = FutureProvider.autoDispose<HomeData>((ref) => ref.watch(apiProvider)!.home());

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final home = ref.watch(homeProvider);
    final data = home.value;
    final canDocs = session.hasFeature(Feature.docView);
    final pendingDocs = canDocs && (data?.counts.pendingSign ?? 0) > 0 ? ref.watch(documentInboxProvider('pending')).value : null;
    return Scaffold(
      backgroundColor: Brand.bg,
      body: RefreshIndicator(
        edgeOffset: 80,
        onRefresh: () async {
          ref.invalidate(documentInboxProvider('pending'));
          ref.invalidate(homeProvider);
          await ref.read(homeProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            _Hero(session: session, counts: data?.counts),
            if (home.hasError && data == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                child: AppCard(
                  margin: EdgeInsets.zero,
                  child: Column(children: [
                    const Icon(Icons.cloud_off_rounded, size: 36, color: Brand.bad),
                    const SizedBox(height: 8),
                    Text(errorText(home.error!), textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(onPressed: () => ref.invalidate(homeProvider), icon: const Icon(Icons.refresh), label: const Text('Thử lại')),
                  ]),
                ),
              )
            else if (data == null)
              const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: CircularProgressIndicator()))
            else ...[
              _Mix(counts: data.counts),
              if (pendingDocs != null && pendingDocs.items.isNotEmpty) ...[
                SectionHeader('Văn bản chờ bạn ký', action: 'Xem tất cả', onAction: () => context.go('/documents')),
                for (final d in pendingDocs.items.take(3)) DocumentTile(doc: d),
              ],
              SectionHeader('Việc cần làm', action: 'Xem tất cả', onAction: () => context.go('/tasks')),
              if (data.tasks.isEmpty)
                const EmptyIllustration(icon: Icons.celebration_rounded, title: 'Bạn không có việc nào đang thực hiện', text: 'Khi có việc mới được giao, bạn sẽ nhận thông báo ngay.', color: Brand.ok)
              else
                for (final t in data.tasks) TaskTile(task: t, onTap: () => context.push('/task/${t.id}')),
            ],
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.session, required this.counts});
  final Session session;
  final HomeCounts? counts;

  @override
  Widget build(BuildContext context) {
    final user = session.user;
    final tenant = session.tenant!;
    final top = MediaQuery.paddingOf(context).top;
    final hour = DateTime.now().hour;
    final hello = hour < 11 ? 'Chào buổi sáng' : hour < 14 ? 'Chào buổi trưa' : hour < 18 ? 'Chào buổi chiều' : 'Chào buổi tối';
    final today = DateFormat('EEEE, dd/MM', 'vi').format(DateTime.now());
    String n(int? v) => v == null ? '–' : '$v';
    final kpis = <_KpiData>[
      _KpiData('Quá hạn', n(counts?.overdue), Icons.local_fire_department_rounded, const Color(0xFFFF6B6B), () => context.go('/tasks?scope=OVERDUE')),
      _KpiData('Sắp đến hạn', n(counts?.dueSoon), Icons.schedule_rounded, const Color(0xFFFFB020), () => context.go('/tasks')),
      if (session.hasFeature(Feature.docView)) _KpiData('Chờ tôi ký', n(counts?.pendingSign), Icons.draw_rounded, const Color(0xFFB39DFF), () => context.go('/documents')),
      _KpiData('Đang thực hiện', n(counts?.openTasks), Icons.task_alt_rounded, const Color(0xFF7CC4FF), () => context.go('/tasks')),
    ];
    return HeroBackground(
      padding: EdgeInsets.fromLTRB(12, top + 6, 12, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconButton(tooltip: 'Menu', icon: const Icon(Icons.menu_rounded, color: Colors.white), onPressed: () => shellScaffoldKey.currentState?.openDrawer()),
          Expanded(
            child: Row(children: [
              TenantAvatar(tenant: tenant, size: 26),
              const SizedBox(width: 8),
              Expanded(child: Text(tenant.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontWeight: FontWeight.w600, fontSize: 14))),
            ]),
          ),
          if (session.hasFeature(Feature.notifications))
            Consumer(builder: (context, ref, _) {
              final unread = ref.watch(homeProvider.select((h) => h.value?.counts.unread ?? 0));
              return IconButton(
                tooltip: 'Thông báo',
                onPressed: () => context.go('/notifications'),
                icon: Badge.count(count: unread, isLabelVisible: unread > 0, backgroundColor: const Color(0xFFFF5A5F), child: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 27)),
              );
            }),
        ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
          child: Row(children: [
            AppAvatar(name: user?.fullName ?? '', size: 56, ring: true),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$hello · $today', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12.5)),
                Text(user?.fullName ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800, height: 1.25)),
                if ((user?.department ?? '').isNotEmpty) Text(user!.department, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12.5)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(children: [
            for (var i = 0; i < kpis.length; i += 2)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
                child: Row(children: [
                  Expanded(child: _Kpi(data: kpis[i])),
                  const SizedBox(width: 10),
                  Expanded(child: i + 1 < kpis.length ? _Kpi(data: kpis[i + 1]) : const SizedBox.shrink()),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _KpiData {
  const _KpiData(this.label, this.value, this.icon, this.color, this.onTap);
  final String label, value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.data});
  final _KpiData data;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: data.onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withValues(alpha: 0.26))),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Icon(data.icon, color: data.color, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(data.value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, height: 1.05)),
                Text(data.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Thanh cơ cấu công việc đang làm: quá hạn, sắp đến hạn, còn lại.
class _Mix extends StatelessWidget {
  const _Mix({required this.counts});
  final HomeCounts counts;

  @override
  Widget build(BuildContext context) {
    final total = counts.openTasks;
    if (total <= 0) return const SizedBox(height: 4);
    final over = counts.overdue.clamp(0, total);
    final soon = counts.dueSoon.clamp(0, total - over);
    final rest = total - over - soon;
    Widget seg(int v, Color c) => v <= 0 ? const SizedBox.shrink() : Expanded(flex: v, child: Container(height: 12, margin: const EdgeInsets.only(right: 3), decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(6))));
    Widget legend(String t, int v, Color c) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text('$t · $v', style: const TextStyle(fontSize: 12, color: Brand.mute, fontWeight: FontWeight.w600)),
        ]);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: Brand.softShadow, border: Border.all(color: Brand.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: Text('Tình hình công việc', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5))),
            Text('$total việc đang làm', style: const TextStyle(color: Brand.mute, fontSize: 12.5)),
          ]),
          const SizedBox(height: 12),
          Row(children: [seg(over, Brand.bad), seg(soon, Brand.warn), seg(rest, Brand.ok)]),
          const SizedBox(height: 12),
          Wrap(spacing: 16, runSpacing: 6, children: [legend('Quá hạn', over, Brand.bad), legend('Sắp đến hạn', soon, Brand.warn), legend('Đúng hạn', rest, Brand.ok)]),
        ]),
      ),
    );
  }
}
