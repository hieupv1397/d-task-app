import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/config.dart';
import 'core/push.dart';
import 'core/session.dart';
import 'core/theme.dart';
import 'shared/brand.dart';
import 'shared/user_menu.dart';
import 'features/auth/auth_pages.dart';
import 'features/documents/document_viewer.dart';
import 'features/documents/documents_page.dart';
import 'features/home/home_page.dart';
import 'features/notifications/notifications_page.dart';
import 'features/profile/profile_page.dart';
import 'features/tasks/task_detail_page.dart';
import 'features/tasks/tasks_page.dart';

/// Phiên bản app đang chạy (đọc một lần ở main).
final appVersionProvider = Provider<String>((ref) => '0.0.0');

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  String? redirect(BuildContext context, GoRouterState state) {
    final s = ref.read(sessionProvider);
    final loc = state.matchedLocation;
    if (s.tenant == null) return loc == '/tenant' ? null : '/tenant';
    if (isVersionBelow(ref.read(appVersionProvider), s.tenant!.minAppVersion)) return loc == '/update' ? null : '/update';
    if (!s.loggedIn) return loc == '/login' ? null : '/login';
    if (loc == '/tenant' || loc == '/login' || loc == '/update' || loc == '/') return '/home';
    return null;
  }

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: refresh,
    redirect: redirect,
    routes: [
      GoRoute(path: '/tenant', builder: (_, state) => TenantPage(initialCode: state.uri.queryParameters['code'])),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/update', builder: (_, _) => UpdateRequiredPage(minVersion: ref.read(sessionProvider).tenant?.minAppVersion ?? '')),
      GoRoute(path: '/task/:id', builder: (_, state) => TaskDetailPage(id: int.parse(state.pathParameters['id']!))),
      GoRoute(
        path: '/document/:id/view',
        builder: (_, state) => DocumentViewerPage(
          id: int.parse(state.pathParameters['id']!),
          versionId: int.tryParse(state.uri.queryParameters['v'] ?? ''),
          fileName: state.uri.queryParameters['name'] ?? '',
        ),
      ),
      GoRoute(path: '/document/:id', builder: (_, state) => DocumentDetailPage(id: int.parse(state.pathParameters['id']!))),
      ShellRoute(
        builder: (context, state, child) => MainShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/home', pageBuilder: (_, _) => const NoTransitionPage(child: HomePage())),
          GoRoute(path: '/tasks', pageBuilder: (_, state) => NoTransitionPage(child: TasksPage(initialScope: state.uri.queryParameters['scope']))),
          GoRoute(path: '/documents', pageBuilder: (_, _) => const NoTransitionPage(child: DocumentsPage())),
          GoRoute(path: '/notifications', pageBuilder: (_, _) => const NoTransitionPage(child: NotificationsPage())),
          GoRoute(path: '/profile', pageBuilder: (_, _) => const NoTransitionPage(child: ProfilePage())),
        ],
      ),
    ],
  );
});

class DTaskApp extends ConsumerStatefulWidget {
  const DTaskApp({super.key});
  @override
  ConsumerState<DTaskApp> createState() => _DTaskAppState();
}

class _DTaskAppState extends ConsumerState<DTaskApp> {
  @override
  void initState() {
    super.initState();
    // Mỗi lần mở app: lấy lại cờ tính năng từ gateway và kiểm tra phiên đăng nhập.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final session = ref.read(sessionProvider.notifier);
      await session.refreshTenant();
      await session.refreshUser();
      ref.read(pushProvider).start(); // đã đăng nhập từ lần trước thì đăng ký lại thiết bị
    });
  }

  @override
  Widget build(BuildContext context) {
    // Vừa đăng nhập xong thì bật thông báo đẩy (xin quyền, đăng ký thiết bị).
    ref.listen(sessionProvider.select((s) => s.loggedIn), (was, now) {
      if (now && was != true) ref.read(pushProvider).start();
    });
    return MaterialApp.router(
      title: 'D Task',
      debugShowCheckedModeBanner: false,
      routerConfig: ref.watch(routerProvider),
      scaffoldMessengerKey: rootMessengerKey,
      theme: buildTheme(),
      builder: (context, child) {
        final width = MediaQuery.sizeOf(context).width;
        if (width <= 700 || child == null) return child ?? const SizedBox.shrink();
        // Màn hình rộng (trình duyệt máy tính): giữ bố cục như điện thoại ở giữa, nền xám hai bên.
        final scheme = Theme.of(context).colorScheme;
        return ColoredBox(
          color: Color.alphaBlend(scheme.primary.withValues(alpha: 0.10), const Color(0xFFE3EAF4)),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: DecoratedBox(
                decoration: BoxDecoration(boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 24)]),
                child: ClipRect(child: child),
              ),
            ),
          ),
        );
      },
      locale: const Locale('vi', 'VN'),
      supportedLocales: const [Locale('vi', 'VN')],
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
    );
  }
}

class _Tab {
  const _Tab(this.path, this.label, this.icon, this.activeIcon);
  final String path, label;
  final IconData icon, activeIcon;
}

/// Ngăn kéo chức năng: thông tin đơn vị và người dùng, các mục chính, đổi đơn vị, đăng xuất.
class _AppDrawer extends ConsumerWidget {
  const _AppDrawer({required this.tabs, required this.location, required this.rootContext});
  final List<_Tab> tabs;
  final String location;

  /// Context của khung chính: còn sống sau khi ngăn kéo đóng, nên mở hộp thoại xác nhận từ đây.
  final BuildContext rootContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final tenant = session.tenant!;
    final user = session.user;
    final scheme = Theme.of(context).colorScheme;
    final version = ref.watch(appVersionProvider);
    final session0 = ref.read(sessionProvider.notifier);
    void go(String path) {
      Navigator.pop(context);
      context.go(path);
    }

    return Drawer(
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          HeroBackground(
            bottomRadius: 28,
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
            child: SizedBox(
              width: double.infinity,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.35))),
                    child: const Center(child: ShieldLogo(size: 34)),
                  ),
                  const SizedBox(width: 12),
                  const Text('D Task', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 18),
                Row(children: [
                  AppAvatar(name: user?.fullName ?? '', size: 40, ring: true),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(user?.fullName ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                      Text(tenant.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12.5)),
                    ]),
                  ),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          for (final t in tabs)
            ListTile(
              leading: Icon(location.startsWith(t.path) ? t.activeIcon : t.icon),
              title: Text(t.label, style: const TextStyle(fontWeight: FontWeight.w600)),
              selected: location.startsWith(t.path),
              selectedColor: Brand.blue,
              selectedTileColor: const Color(0xFFE9F1FF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              onTap: () => go(t.path),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.swap_horiz),
            title: const Text('Đổi đơn vị'),
            onTap: () {
              Navigator.pop(context);
              confirmAction(rootContext, title: 'Đổi đơn vị?', text: 'Bạn sẽ đăng xuất và chọn lại đơn vị.', okLabel: 'Đổi đơn vị', onYes: () => session0.leaveTenant());
            },
          ),
          ListTile(
            leading: Icon(Icons.logout, color: scheme.error),
            title: Text('Đăng xuất', style: TextStyle(color: scheme.error)),
            onTap: () {
              Navigator.pop(context);
              confirmAction(rootContext, title: 'Đăng xuất?', text: 'Bạn cần đăng nhập lại để tiếp tục.', okLabel: 'Đăng xuất', danger: true, onYes: () => session0.logout());
            },
          ),
          const Spacer(),
          Padding(padding: const EdgeInsets.all(16), child: Text('D Task · phiên bản $version', style: TextStyle(fontSize: 12, color: scheme.outline))),
        ]),
      ),
    );
  }
}

/// Khung chính có thanh tab dưới; tab nào đơn vị chưa bật thì ẩn.
class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final unread = ref.watch(homeProvider.select((h) => h.value?.counts.unread ?? 0));
    final tabs = [
      const _Tab('/home', 'Trang chủ', Icons.home_outlined, Icons.home_rounded),
      const _Tab('/tasks', 'Công việc', Icons.task_alt_outlined, Icons.task_alt_rounded),
      if (session.hasFeature(Feature.docView)) const _Tab('/documents', 'Văn bản', Icons.description_outlined, Icons.description_rounded),
      if (session.hasFeature(Feature.notifications)) const _Tab('/notifications', 'Thông báo', Icons.notifications_none_rounded, Icons.notifications_rounded),
      const _Tab('/profile', 'Cá nhân', Icons.person_outline_rounded, Icons.person_rounded),
    ];
    final index = tabs.indexWhere((t) => location.startsWith(t.path)).clamp(0, tabs.length - 1);
    return Scaffold(
      key: shellScaffoldKey,
      drawer: _AppDrawer(tabs: tabs, location: location, rootContext: context),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => context.go(tabs[i].path),
        destinations: [
          for (final t in tabs)
            NavigationDestination(
              label: t.label,
              icon: t.path == '/notifications' && unread > 0 ? Badge.count(count: unread, child: Icon(t.icon)) : Icon(t.icon),
              selectedIcon: Icon(t.activeIcon),
            ),
        ],
      ),
    );
  }
}
