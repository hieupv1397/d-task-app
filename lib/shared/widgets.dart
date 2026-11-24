import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/api.dart';
import '../core/models.dart';
import '../core/theme.dart';
import 'brand.dart';

final _dateTime = DateFormat('dd/MM/yyyy HH:mm');
final _date = DateFormat('dd/MM/yyyy');
String fmtDateTime(DateTime d) => _dateTime.format(d);
String fmtDate(DateTime d) => _date.format(d);

String errorText(Object e) => e is ApiError ? e.message : toApiError(e).message;

/// Hiển thị AsyncValue với vòng tải, thông báo lỗi kèm nút thử lại.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({super.key, required this.value, required this.onRetry, required this.builder});
  final AsyncValue<T> value;
  final VoidCallback onRetry;
  final Widget Function(T data) builder;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: true,
      data: builder,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(message: errorText(e), onRetry: onRetry),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 40),
      children: [
        EmptyIllustration(icon: Icons.cloud_off_rounded, title: 'Chưa tải được dữ liệu', text: message, color: Brand.bad),
        Center(child: FilledButton.tonalIcon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Thử lại'))),
      ],
    );
  }
}

/// Dòng thông báo rỗng gọn, đặt được bên trong một ListView.
class EmptyHint extends StatelessWidget {
  const EmptyHint({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => EmptyIllustration(icon: icon, title: text);
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 48),
      children: [EmptyIllustration(icon: icon, title: text)],
    );
  }
}

void showSnack(BuildContext context, String text, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(error ? Icons.error_outline : Icons.check_circle_outline, color: error ? const Color(0xFFFFB4B4) : const Color(0xFF8FE3B4), size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ]),
      backgroundColor: error ? const Color(0xFF7A1F22) : Brand.ink,
    ));
}

const priorityLabels = {'LOW': 'Thấp', 'NORMAL': 'Bình thường', 'HIGH': 'Cao', 'URGENT': 'Khẩn'};

Color priorityColor(String p) => switch (p) {
      'URGENT' => Brand.bad,
      'HIGH' => Brand.warn,
      'LOW' => const Color(0xFF8C9BB0),
      _ => Brand.blue,
    };

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, required this.color, this.icon});
  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 4)],
          Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: color, fontWeight: FontWeight.w700))),
        ]),
      );
}

/// Một dòng công việc dùng chung cho trang chủ và danh sách.
class TaskTile extends StatelessWidget {
  const TaskTile({super.key, required this.task, required this.onTap});
  final AppTask task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final overdue = task.isOverdue;
    final accent = overdue ? Brand.bad : (task.priority == 'URGENT' ? Brand.bad : task.priority == 'HIGH' ? Brand.warn : Brand.blue);
    final dueColor = overdue ? Brand.bad : Brand.mute;
    return AppCard(
      onTap: onTap,
      accent: accent,
      padding: const EdgeInsets.fromLTRB(18, 13, 14, 13),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(task.code, style: const TextStyle(fontSize: 12, color: Brand.mute, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Pill(priorityLabels[task.priority] ?? task.priority, color: priorityColor(task.priority)),
              if (task.stateName != null) ...[const SizedBox(width: 6), Flexible(child: Pill(task.stateName!, color: Brand.violet))],
            ]),
            const SizedBox(height: 7),
            Text(task.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, height: 1.3)),
            const SizedBox(height: 8),
            Row(children: [
              Icon(overdue ? Icons.warning_amber_rounded : Icons.event_outlined, size: 15, color: dueColor),
              const SizedBox(width: 4),
              Text(overdue ? 'Quá hạn ${fmtDate(task.dueAt)}' : 'Hạn ${fmtDate(task.dueAt)}', style: TextStyle(fontSize: 12, color: dueColor, fontWeight: overdue ? FontWeight.w700 : FontWeight.w500)),
              if (task.ownerName != null && task.ownerName!.isNotEmpty) ...[
                const SizedBox(width: 10),
                const Icon(Icons.person_outline, size: 15, color: Brand.mute),
                const SizedBox(width: 3),
                Flexible(child: Text(task.ownerName!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Brand.mute))),
              ],
            ]),
          ]),
        ),
        const SizedBox(width: 12),
        ProgressRing(value: task.progress, color: overdue ? Brand.bad : Brand.blue),
      ]),
    );
  }
}
