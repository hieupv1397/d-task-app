import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models.dart';
import '../../core/session.dart';
import '../../shared/user_menu.dart';
import '../../shared/widgets.dart';

const _scopes = [
  ('ASSIGNED', 'Của tôi'),
  ('OWNER', 'Tôi phụ trách'),
  ('FOLLOWING', 'Tôi tham gia'),
  ('OVERDUE', 'Quá hạn'),
  ('DONE', 'Đã xong'),
];

class TasksPage extends ConsumerStatefulWidget {
  const TasksPage({super.key, this.initialScope});
  final String? initialScope;

  @override
  ConsumerState<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends ConsumerState<TasksPage> {
  static const _pageSize = 20;
  late String _scope = _scopes.any((s) => s.$1 == widget.initialScope) ? widget.initialScope! : 'ASSIGNED';
  final _search = TextEditingController();
  Timer? _debounce;
  final List<AppTask> _items = [];
  int _total = 0;
  int _page = 0;
  bool _loading = false;
  int _seq = 0; // số thứ tự yêu cầu mới nhất; kết quả của yêu cầu cũ bị bỏ
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void didUpdateWidget(TasksPage old) {
    super.didUpdateWidget(old);
    final s = widget.initialScope;
    if (s != old.initialScope && s != null && _scopes.any((x) => x.$1 == s) && s != _scope) {
      _scope = s;
      _load(reset: true);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading && !reset) return;
    final api = ref.read(apiProvider);
    if (api == null) return;
    final seq = ++_seq;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _items.clear();
        _page = 0;
      }
    });
    try {
      final r = await api.tasks(scope: _scope, keyword: _search.text, page: _page + 1, pageSize: _pageSize);
      if (!mounted || seq != _seq) return;
      setState(() {
        _items.addAll(r.items);
        _total = r.total;
        _page++;
      });
    } catch (e) {
      if (mounted && seq == _seq) setState(() => _error = errorText(e));
    } finally {
      if (mounted && seq == _seq) setState(() => _loading = false);
    }
  }

  void _setScope(String scope) {
    if (scope == _scope) return;
    setState(() => _scope = scope);
    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final hasMore = _items.length < _total;
    return Scaffold(
      appBar: AppBar(
        leading: const MenuButton(),
        title: const Text('Công việc'),
        actions: const [UserMenuButton()],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onChanged: (_) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 400), () => _load(reset: true));
                },
                decoration: InputDecoration(
                  hintText: 'Tìm theo mã hoặc tiêu đề',
                  isDense: true,
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                  filled: true,
                ),
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: [
                  for (final s in _scopes)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
                      child: ChoiceChip(label: Text(s.$2), selected: _scope == s.$1, onSelected: (_) => _setScope(s.$1)),
                    ),
                ],
              ),
            ),
          ]),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: _body(hasMore),
      ),
    );
  }

  Widget _body(bool hasMore) {
    if (_items.isEmpty) {
      if (_loading) return const Center(child: CircularProgressIndicator());
      if (_error != null) return ErrorView(message: _error!, onRetry: () => _load(reset: true));
      return const EmptyView(icon: Icons.inbox_outlined, text: 'Không có công việc nào.');
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 6, bottom: 24),
      itemCount: _items.length + 1,
      itemBuilder: (context, i) {
        if (i < _items.length) return TaskTile(task: _items[i], onTap: () => context.push('/task/${_items[i].id}'));
        if (_error != null) return Padding(padding: const EdgeInsets.all(16), child: Center(child: TextButton(onPressed: _load, child: Text('$_error Thử lại'))));
        if (_loading) return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
        if (hasMore) return Padding(padding: const EdgeInsets.all(8), child: Center(child: TextButton(onPressed: _load, child: Text('Tải thêm (${_items.length}/$_total)'))));
        return Padding(padding: const EdgeInsets.all(16), child: Center(child: Text('Đã hiển thị $_total việc', style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12))));
      },
    );
  }
}
