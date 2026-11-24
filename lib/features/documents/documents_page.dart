import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/models.dart';
import '../../core/remember.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../shared/brand.dart';
import '../../shared/user_menu.dart';
import '../../shared/widgets.dart';
import '../home/home_page.dart';

const docScopes = [
  ('pending', 'Chờ tôi xử lý'),
  ('submitted', 'Văn bản của tôi'),
  ('done', 'Đã xử lý'),
  ('all', 'Tất cả'),
];

const docStatusLabels = {
  'DRAFT': 'Nháp',
  'IN_SIGNING': 'Đang ký',
  'REJECTED': 'Bị từ chối',
  'COMPLETED': 'Hoàn tất',
  'CANCELLED': 'Đã hủy',
};

Color docStatusColor(String s) => switch (s) {
      'COMPLETED' => Brand.ok,
      'REJECTED' => Brand.bad,
      'IN_SIGNING' => Brand.warn,
      _ => const Color(0xFF8C9BB0),
    };

final documentInboxProvider = FutureProvider.autoDispose.family<DocumentInbox, String>((ref, scope) => ref.watch(apiProvider)!.documents(scope: scope));
final taskDocumentsProvider = FutureProvider.autoDispose.family<List<DocumentItem>, int>((ref, taskId) => ref.watch(apiProvider)!.taskDocuments(taskId));
final documentProvider = FutureProvider.autoDispose.family<DocumentItem, int>((ref, id) => ref.watch(apiProvider)!.document(id));

class DocumentsPage extends ConsumerStatefulWidget {
  const DocumentsPage({super.key});
  @override
  ConsumerState<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends ConsumerState<DocumentsPage> {
  String _scope = 'pending';

  @override
  Widget build(BuildContext context) {
    final inbox = ref.watch(documentInboxProvider(_scope));
    final counts = inbox.value;
    int? countOf(String scope) => switch (scope) {
          'pending' => counts?.pending,
          'submitted' => counts?.submitted,
          'done' => counts?.done,
          _ => counts?.all,
        };
    return Scaffold(
      appBar: AppBar(
        leading: const MenuButton(),
        title: const Text('Văn bản'),
        actions: const [UserMenuButton()],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: SizedBox(
            height: 46,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 10), children: [
              for (final s in docScopes)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
                  child: ChoiceChip(
                    label: Text(countOf(s.$1) == null ? s.$2 : '${s.$2} (${countOf(s.$1)})'),
                    selected: _scope == s.$1,
                    onSelected: (_) => setState(() => _scope = s.$1),
                  ),
                ),
            ]),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(documentInboxProvider(_scope).future),
        child: AsyncView<DocumentInbox>(
          value: inbox,
          onRetry: () => ref.invalidate(documentInboxProvider(_scope)),
          builder: (data) => data.items.isEmpty
              ? EmptyView(icon: Icons.description_outlined, text: _scope == 'pending' ? 'Không có văn bản nào đang chờ bạn ký.' : 'Không có văn bản nào.')
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(top: 10, bottom: 24),
                  itemCount: data.items.length,
                  itemBuilder: (_, i) => DocumentTile(doc: data.items[i]),
                ),
        ),
      ),
    );
  }
}

/// Một dòng văn bản dùng ở danh sách và trang chủ.
class DocumentTile extends StatelessWidget {
  const DocumentTile({super.key, required this.doc});
  final DocumentItem doc;

  @override
  Widget build(BuildContext context) {
    final color = docStatusColor(doc.status);
    final place = doc.isStandalone ? 'Dự án: ${doc.workspaceName.isEmpty ? '—' : doc.workspaceName}' : '${doc.taskCode} · ${doc.taskTitle}';
    return AppCard(
      onTap: () => context.push('/document/${doc.id}'),
      accent: doc.canAct ? Brand.blue : null,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        IconBadge(icon: doc.canAct ? Icons.draw_rounded : Icons.description_rounded, color: doc.canAct ? Brand.blue : color, solid: doc.canAct),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Pill(docStatusLabels[doc.status] ?? doc.status, color: color),
              if (doc.canAct) const Pill('Đến lượt bạn', color: Brand.blue, icon: Icons.bolt_rounded),
            ]),
            const SizedBox(height: 6),
            Text(doc.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, height: 1.3)),
            const SizedBox(height: 4),
            Text([if (doc.typeName.isNotEmpty) doc.typeName, place].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: Brand.mute)),
            if (doc.submittedAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(children: [
                  const Icon(Icons.schedule_rounded, size: 13, color: Brand.mute),
                  const SizedBox(width: 4),
                  Flexible(child: Text('Gửi ${fmtDateTime(doc.submittedAt!)}${doc.createdBy == null ? '' : ' · ${doc.createdBy}'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Brand.mute))),
                ]),
              ),
          ]),
        ),
        const Icon(Icons.chevron_right_rounded, color: Color(0xFFB4C1D4)),
      ]),
    );
  }
}

class DocumentDetailPage extends ConsumerWidget {
  const DocumentDetailPage({super.key, required this.id});
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doc = ref.watch(documentProvider(id));
    return Scaffold(
      appBar: AppBar(title: const Text('Văn bản')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(documentProvider(id).future),
        child: AsyncView<DocumentItem>(value: doc, onRetry: () => ref.invalidate(documentProvider(id)), builder: (d) => _DocBody(doc: d)),
      ),
      bottomNavigationBar: doc.value?.canAct == true ? _SignBar(doc: doc.requireValue) : null,
    );
  }
}

class _DocBody extends StatelessWidget {
  const _DocBody({required this.doc});
  final DocumentItem doc;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text(doc.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          Pill(docStatusLabels[doc.status] ?? doc.status, color: docStatusColor(doc.status)),
          if (doc.typeName.isNotEmpty) Pill(doc.typeName, color: scheme.primary),
          if (doc.confidentiality == 'CONFIDENTIAL') const Pill('Bảo mật', color: Color(0xFFC43838)),
        ]),
        const SizedBox(height: 14),
        if (doc.documentNo != null) _Row('Số văn bản', doc.documentNo!),
        if (doc.workspaceName.isNotEmpty) _Row('Dự án', doc.workspaceName),
        _Row('Công việc', doc.isStandalone ? 'Không thuộc công việc nào (văn bản độc lập)' : '${doc.taskCode} · ${doc.taskTitle}'),
        if (doc.fileName.isNotEmpty)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              leading: Icon(doc.fileName.toLowerCase().endsWith('.pdf') ? Icons.picture_as_pdf_outlined : Icons.insert_drive_file_outlined, color: scheme.primary, size: 32),
              title: Text(doc.fileName, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text(doc.signedVersion ? 'Bản đã ký (phiên bản ${doc.versionNo}) · chạm để xem' : 'Bản gốc · chạm để xem'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/document/${doc.id}/view?${Uri(queryParameters: {'name': doc.fileName, if (doc.versionId != null) 'v': '${doc.versionId}'}).query}'),
            ),
          ),
        if (doc.createdBy != null) _Row('Người tạo', doc.createdBy!),
        if (doc.submittedAt != null) _Row('Gửi ký lúc', fmtDateTime(doc.submittedAt!)),
        if (doc.note != null && doc.note!.trim().isNotEmpty) _Row('Ghi chú', doc.note!),
        if (doc.signatures.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('Chữ ký số', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          for (final x in doc.signatures) _SignatureTile(sig: x),
        ],
        const SizedBox(height: 8),
        const Text('Tiến trình ký', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 6),
        if (doc.steps.isEmpty) Text('Văn bản này không có quy trình ký.', style: TextStyle(color: scheme.outline)),
        for (final s in doc.steps) _StepTile(step: s),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 100, child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.outline))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ]),
      );
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.step});
  final DocStep step;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (step.status) {
      'DONE' => (Icons.check_circle, const Color(0xFF237804), 'Đã ${step.action.isEmpty ? 'xử lý' : step.action.toLowerCase()}'),
      'REJECTED' => (Icons.cancel, const Color(0xFFC43838), 'Từ chối'),
      'PENDING' => (Icons.hourglass_top, const Color(0xFFD46B08), 'Đang chờ'),
      'SKIPPED' => (Icons.remove_circle_outline, const Color(0xFF8C8C8C), 'Bỏ qua'),
      _ => (Icons.radio_button_unchecked, const Color(0xFF8C8C8C), 'Chưa đến lượt'),
    };
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text('${step.no}. ${step.name}${step.isDigital ? ' · Ký số' : ''}${step.isMine ? ' (bạn)' : ''}'),
      subtitle: Text([
        step.signer,
        if (step.actedBy != null) '${step.actedBy}${step.actedAt == null ? '' : ' · ${fmtDateTime(step.actedAt!)}'}',
        if (step.comment != null) '“${step.comment}”',
      ].where((e) => e.isNotEmpty).join('\n')),
      trailing: Text(label, style: TextStyle(color: color, fontSize: 12)),
    );
  }
}

class _SignatureTile extends StatelessWidget {
  const _SignatureTile({required this.sig});
  final DocSignature sig;
  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (sig.verifyStatus) {
      'VALID' => (Icons.verified_outlined, const Color(0xFF237804), 'Hợp lệ'),
      'INVALID' => (Icons.gpp_bad_outlined, const Color(0xFFC43838), 'Không hợp lệ'),
      'UNKNOWN' => (Icons.help_outline, const Color(0xFFD46B08), 'Chưa xác định'),
      _ => (Icons.hourglass_empty, const Color(0xFF8C8C8C), 'Đang kiểm tra'),
    };
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(sig.signerName),
      subtitle: Text(fmtDateTime(sig.signedAt)),
      trailing: Text(label, style: TextStyle(color: color, fontSize: 12)),
    );
  }
}

/// Nút Duyệt / Từ chối cho người đang đến lượt ký.
class _SignBar extends ConsumerWidget {
  const _SignBar({required this.doc});
  final DocumentItem doc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allowed = ref.watch(sessionProvider.select((s) => s.hasFeature('DOC_SIGN')));
    if (!allowed) {
      return const SafeArea(child: Padding(padding: EdgeInsets.all(16), child: Text('Đơn vị chưa bật ký văn bản trên app. Vui lòng ký trên web.', textAlign: TextAlign.center)));
    }
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFC43838)),
              onPressed: () => _act(context, ref, 'REJECT'),
              icon: const Icon(Icons.close),
              label: const Text('Từ chối'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: FilledButton.icon(onPressed: () => _act(context, ref, 'APPROVE'), icon: const Icon(Icons.draw), label: Text(_approveLabel))),
        ]),
      ),
    );
  }

  String get _approveLabel => switch (doc.myStep?.action) { 'SIGN' => doc.myStep!.isDigital ? 'Ký số' : 'Ký', 'REVIEW' => 'Kiểm tra', 'APPROVE' => 'Phê duyệt', _ => 'Duyệt / Ký' };

  /// Nhà cung cấp ký số có thể đòi mã OTP: hỏi người dùng rồi gửi lại cùng mã giao dịch.
  Future<String?> _askOtp(BuildContext context, String message) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nhập mã xác thực (OTP)'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(message),
          const SizedBox(height: 10),
          TextField(controller: c, autofocus: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Mã OTP', border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('Xác nhận')),
        ],
      ),
    );
  }

  Future<void> _act(BuildContext context, WidgetRef ref, String decision) async {
    final session = ref.read(sessionProvider);
    final store = ref.read(rememberProvider);
    final code = session.tenant!.code;
    final username = session.user?.username ?? '';
    // Mật khẩu đã ghi nhớ (nếu có) được điền sẵn vào hộp thoại ký.
    final saved = decision == 'APPROVE' ? await store.password(code, username) : null;
    if (!context.mounted) return;
    final result = await showDialog<({String comment, String password, bool remember})>(
      context: context,
      builder: (_) => SignDialog(decision: decision, docTitle: doc.title, initialPassword: saved, digital: doc.myStep?.isDigital == true),
    );
    if (result == null || !context.mounted) return;
    final api = ref.read(apiProvider)!;
    try {
      String? otp, tx;
      while (true) {
        try {
          await api.actOnDocument(doc.id, decision: decision, comment: result.comment, password: decision == 'APPROVE' ? result.password : null, otp: otp, otpTransactionId: tx);
          break;
        } on ApiError catch (e) {
          if (!e.needsOtp || !context.mounted) rethrow;
          final code = await _askOtp(context, e.message);
          if (code == null || code.isEmpty) return;
          otp = code;
          tx = e.otpTransactionId ?? tx;
        }
      }
      if (decision == 'APPROVE') {
        if (result.remember) {
          await store.savePassword(code, username, result.password);
        } else if (saved != null) {
          await store.clearPassword(code, username);
        }
      }
      ref.invalidate(documentProvider(doc.id));
      ref.invalidate(documentInboxProvider);
      ref.invalidate(homeProvider);
      if (context.mounted) showSnack(context, decision == 'APPROVE' ? 'Đã ký duyệt văn bản.' : 'Đã từ chối văn bản.');
    } catch (e) {
      // Mật khẩu đã lưu không còn đúng (đã đổi mật khẩu): bỏ đi để lần sau không điền sai.
      if (saved != null && result.password == saved && e is ApiError && e.status == 403) await store.clearPassword(code, username);
      if (context.mounted) showSnack(context, errorText(e), error: true);
    }
  }
}

/// Hộp thoại xác nhận: duyệt cần nhập lại mật khẩu, từ chối bắt buộc có lý do.
class SignDialog extends StatefulWidget {
  const SignDialog({super.key, required this.decision, required this.docTitle, this.initialPassword, this.digital = false});
  final bool digital;
  final String decision;
  final String docTitle;
  final String? initialPassword;

  @override
  State<SignDialog> createState() => _SignDialogState();
}

class _SignDialogState extends State<SignDialog> {
  final _comment = TextEditingController();
  late final _password = TextEditingController(text: widget.initialPassword);
  late bool _remember = widget.initialPassword != null;
  bool _hide = true;
  String? _error;

  bool get _approve => widget.decision == 'APPROVE';

  @override
  void dispose() {
    _comment.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (_approve && _password.text.isEmpty) {
      setState(() => _error = 'Vui lòng nhập mật khẩu để xác nhận chữ ký.');
      return;
    }
    if (!_approve && _comment.text.trim().isEmpty) {
      setState(() => _error = 'Vui lòng nhập lý do từ chối.');
      return;
    }
    Navigator.pop(context, (comment: _comment.text.trim(), password: _password.text, remember: _approve && _remember));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(!_approve ? 'Từ chối văn bản' : widget.digital ? 'Ký số văn bản' : 'Ký duyệt văn bản'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.docTitle, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
          if (_approve && widget.digital) Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Bước này ký số bằng chứng thư của bạn. Bạn cần đã liên kết tài khoản ký số ở bản web (Hồ sơ của tôi > Chữ ký số). Vị trí chữ ký theo cấu hình của văn bản; muốn kéo đổi vị trí hãy ký trên web.', style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.outline)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _comment,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: _approve ? 'Nhận xét (tùy chọn)' : 'Lý do từ chối (bắt buộc)', border: const OutlineInputBorder()),
          ),
          if (_approve) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: _hide,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Mật khẩu đăng nhập',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined), onPressed: () => setState(() => _hide = !_hide)),
              ),
            ),
            CheckboxListTile(
              value: _remember,
              onChanged: (v) => setState(() => _remember = v ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              title: const Text('Ghi nhớ mật khẩu trên thiết bị này'),
            ),
          ],
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        FilledButton(
          style: _approve ? null : FilledButton.styleFrom(backgroundColor: const Color(0xFFC43838)),
          onPressed: _submit,
          child: Text(_approve ? 'Ký duyệt' : 'Từ chối'),
        ),
      ],
    );
  }
}
