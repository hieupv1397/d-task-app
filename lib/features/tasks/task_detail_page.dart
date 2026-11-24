import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../core/models.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../shared/brand.dart';
import '../../shared/widgets.dart';
import '../documents/documents_page.dart';
import '../home/home_page.dart';

final taskDetailProvider = FutureProvider.autoDispose.family<TaskDetail, int>((ref, id) => ref.watch(apiProvider)!.taskDetail(id));

class TaskDetailPage extends ConsumerWidget {
  const TaskDetailPage({super.key, required this.id});
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(taskDetailProvider(id));
    return Scaffold(
      appBar: AppBar(title: Text(detail.value?.code ?? 'Công việc')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(taskDetailProvider(id).future),
        child: AsyncView<TaskDetail>(
          value: detail,
          onRetry: () => ref.invalidate(taskDetailProvider(id)),
          builder: (t) => _Body(task: t),
        ),
      ),
      bottomNavigationBar: detail.value == null ? null : _Actions(task: detail.requireValue),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.task});
  final TaskDetail task;

  @override
  Widget build(BuildContext context) {
    final overdue = task.isOverdue;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        AppCard(
          margin: EdgeInsets.zero,
          accent: overdue ? Brand.bad : Brand.blue,
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(task.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19, height: 1.3)),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: [
              Pill(task.stateName.isEmpty ? 'Chưa có trạng thái' : task.stateName, color: Brand.violet),
              Pill(priorityLabels[task.priority] ?? task.priority, color: priorityColor(task.priority)),
              if (task.isDone) const Pill('Đã hoàn thành', color: Brand.ok, icon: Icons.check_circle_rounded),
              if (overdue) const Pill('Quá hạn', color: Brand.bad, icon: Icons.local_fire_department_rounded),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              ProgressRing(value: task.progress, size: 68, color: overdue ? Brand.bad : Brand.blue),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Tiến độ hiện tại', style: TextStyle(color: Brand.mute, fontSize: 12.5)),
                  Text('${task.progress.round()}% hoàn thành', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                  const SizedBox(height: 4),
                  Text(overdue ? 'Quá hạn ${fmtDate(task.dueAt)}' : 'Hạn ${fmtDate(task.dueAt)}', style: TextStyle(color: overdue ? Brand.bad : Brand.mute, fontWeight: FontWeight.w600, fontSize: 13)),
                ]),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        AppCard(margin: EdgeInsets.zero, padding: const EdgeInsets.fromLTRB(14, 8, 14, 8), child: Column(children: [
        _Info(icon: Icons.event_outlined, label: 'Hạn hoàn thành', value: fmtDateTime(task.dueAt), valueColor: overdue ? const Color(0xFFC43838) : null),
        if (task.completedAt != null) _Info(icon: Icons.check_circle_outline, label: 'Hoàn thành lúc', value: fmtDateTime(task.completedAt!)),
        _Info(icon: Icons.category_outlined, label: 'Loại công việc', value: task.typeName),
        _Info(icon: Icons.folder_outlined, label: 'Dự án', value: task.workspaceName),
        _Info(icon: Icons.apartment_outlined, label: 'Đơn vị phụ trách', value: task.departmentName),
        if (task.confidentiality != 'INTERNAL') _Info(icon: Icons.lock_outline, label: 'Mức mật', value: task.confidentiality == 'CONFIDENTIAL' ? 'Bảo mật' : 'Công khai'),
        ])),
        if (task.description != null && task.description!.trim().isNotEmpty) ...[
          const _Heading('Mô tả'),
          Text(task.description!),
        ],
        if (task.assignments.isNotEmpty) ...[
          const _Heading('Người tham gia'),
          for (final a in task.assignments)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(radius: 16, child: Text(a.personName.characters.first.toUpperCase())),
              title: Text(a.personName),
              subtitle: Text(a.roleName),
            ),
        ],
        _TaskDocs(taskId: task.id, requiresResponse: task.requiresResponse),
        if (task.progressUpdates.isNotEmpty) ...[
          const _Heading('Cập nhật tiến độ'),
          for (final u in task.progressUpdates.take(10))
            _Timeline(title: '${u.percent.round()}%', time: u.createdAt, lines: [if (u.content != null) u.content!, if (u.risks != null) 'Rủi ro: ${u.risks}', if (u.proposal != null) 'Đề xuất: ${u.proposal}']),
        ],
        if (task.history.isNotEmpty) ...[
          const _Heading('Lịch sử xử lý'),
          for (final h in task.history.take(10)) _Timeline(title: h.stateName, time: h.createdAt, lines: [if (h.comment != null) h.comment!]),
        ],
      ],
    );
  }
}

/// Văn bản của công việc: trạng thái ký và lối vào xem, ký ngay trên app.
class _TaskDocs extends ConsumerWidget {
  const _TaskDocs({required this.taskId, required this.requiresResponse});
  final int taskId;
  final bool requiresResponse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = ref.watch(taskDocumentsProvider(taskId));
    final items = docs.value;
    if (items == null || (items.isEmpty && !requiresResponse)) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _Heading('Văn bản'),
      if (items.isEmpty) Text('Công việc yêu cầu văn bản trả lời nhưng chưa có văn bản nào.', style: TextStyle(color: Theme.of(context).colorScheme.outline)),
      for (final d in items)
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.description_outlined),
          title: Text(d.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(d.typeName),
          trailing: Pill(docStatusLabels[d.status] ?? d.status, color: docStatusColor(d.status)),
          onTap: () => context.push('/document/${d.id}'),
        ),
    ]);
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(top: 20, bottom: 6), child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5)));
}

class _Info extends StatelessWidget {
  const _Info({required this.icon, required this.label, required this.value, this.valueColor});
  final IconData icon;
  final String label, value;
  final Color? valueColor;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 8),
          SizedBox(width: 120, child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.outline))),
          Expanded(child: Text(value.isEmpty ? '—' : value, style: TextStyle(color: valueColor, fontWeight: FontWeight.w500))),
        ]),
      );
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.title, required this.time, required this.lines});
  final String title;
  final DateTime time;
  final List<String> lines;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(fmtDateTime(time), style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
          ]),
          for (final l in lines) Padding(padding: const EdgeInsets.only(top: 2), child: Text(l, style: const TextStyle(fontSize: 13))),
          const Divider(height: 14),
        ]),
      );
}

/// Thanh nút ở đáy: báo cáo tiến độ và các hành động quy trình, tùy quyền và cờ tính năng của đơn vị.
class _Actions extends ConsumerWidget {
  const _Actions({required this.task});
  final TaskDetail task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    final canProgress = s.hasFeature(Feature.taskProgress) && s.can('TASK.PROGRESS') && !task.isDone;
    final canFlow = s.hasFeature(Feature.taskWorkflow) && s.can('TASK.UPDATE') && task.actions.isNotEmpty;
    if (!canProgress && !canFlow) return const SizedBox.shrink();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(children: [
          if (canProgress)
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _progressSheet(context, ref, task),
                icon: const Icon(Icons.trending_up),
                label: const Text('Báo cáo tiến độ'),
              ),
            ),
          if (canProgress && canFlow) const SizedBox(width: 10),
          if (canFlow)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _flowSheet(context, ref, task),
                icon: const Icon(Icons.alt_route),
                label: const Text('Chuyển bước'),
              ),
            ),
        ]),
      ),
    );
  }
}

void _refreshAfterChange(WidgetRef ref, int id) {
  ref.invalidate(taskDetailProvider(id));
  ref.invalidate(homeProvider);
}

Future<void> _progressSheet(BuildContext context, WidgetRef ref, TaskDetail task) async {
  final done = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ProgressForm(task: task),
  );
  if (done == true && context.mounted) {
    _refreshAfterChange(ref, task.id);
    showSnack(context, 'Đã cập nhật tiến độ.');
  }
}

class _ProgressForm extends ConsumerStatefulWidget {
  const _ProgressForm({required this.task});
  final TaskDetail task;
  @override
  ConsumerState<_ProgressForm> createState() => _ProgressFormState();
}

class _ProgressFormState extends ConsumerState<_ProgressForm> {
  late double _percent = widget.task.progress;
  final _content = TextEditingController();
  final _risks = TextEditingController();
  final _proposal = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _content.dispose();
    _risks.dispose();
    _proposal.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(apiProvider)!.reportProgress(widget.task.id, percent: _percent.roundToDouble(), content: _content.text, risks: _risks.text, proposal: _proposal.text, rowVersion: widget.task.rowVersion);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Báo cáo tiến độ', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Row(children: [
            const Text('Hoàn thành'),
            const Spacer(),
            Text('${_percent.round()}%', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          ]),
          Slider(value: _percent, min: 0, max: 100, divisions: 20, label: '${_percent.round()}%', onChanged: _busy ? null : (v) => setState(() => _percent = v)),
          TextField(controller: _content, enabled: !_busy, minLines: 2, maxLines: 4, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Nội dung đã thực hiện', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _risks, enabled: !_busy, minLines: 1, maxLines: 3, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Rủi ro, vướng mắc', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _proposal, enabled: !_busy, minLines: 1, maxLines: 3, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Đề xuất', border: OutlineInputBorder())),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
          const SizedBox(height: 14),
          FilledButton(onPressed: _busy ? null : _save, child: Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: _busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Lưu báo cáo'))),
        ]),
      ),
    );
  }
}

Future<void> _flowSheet(BuildContext context, WidgetRef ref, TaskDetail task) async {
  final action = await showModalBottomSheet<WorkflowAction>(
    context: context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Padding(padding: EdgeInsets.fromLTRB(16, 0, 16, 8), child: Align(alignment: Alignment.centerLeft, child: Text('Chuyển bước quy trình', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)))),
        for (final a in task.actions) ListTile(leading: const Icon(Icons.arrow_forward), title: Text(a.name), subtitle: a.requiresComment ? const Text('Cần nhập lý do / nhận xét') : null, onTap: () => Navigator.pop(context, a)),
        const SizedBox(height: 8),
      ]),
    ),
  );
  if (action == null || !context.mounted) return;
  final comment = await showDialog<String>(context: context, builder: (_) => _CommentDialog(action: action));
  if (comment == null || !context.mounted) return;
  try {
    await ref.read(apiProvider)!.workflowAction(task.id, code: action.code, comment: comment, rowVersion: task.rowVersion);
    if (!context.mounted) return;
    _refreshAfterChange(ref, task.id);
    showSnack(context, 'Đã thực hiện: ${action.name}.');
  } catch (e) {
    if (context.mounted) showSnack(context, errorText(e), error: true);
  }
}

class _CommentDialog extends StatefulWidget {
  const _CommentDialog({required this.action});
  final WorkflowAction action;
  @override
  State<_CommentDialog> createState() => _CommentDialogState();
}

class _CommentDialogState extends State<_CommentDialog> {
  final _c = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.action.name),
      content: TextField(
        controller: _c,
        autofocus: true,
        minLines: 2,
        maxLines: 4,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: widget.action.requiresComment ? 'Lý do / nhận xét (bắt buộc)' : 'Nhận xét (không bắt buộc)', errorText: _error, border: const OutlineInputBorder()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        FilledButton(
          onPressed: () {
            if (widget.action.requiresComment && _c.text.trim().isEmpty) {
              setState(() => _error = 'Vui lòng nhập nội dung.');
              return;
            }
            Navigator.pop(context, _c.text.trim());
          },
          child: const Text('Xác nhận'),
        ),
      ],
    );
  }
}
