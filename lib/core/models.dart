// Các mô hình dữ liệu đọc từ gateway và D Task API. Chỉ giữ trường app dùng.

DateTime? _date(dynamic v) => v == null ? null : DateTime.parse(v as String).toLocal();
double _num(dynamic v) => v == null ? 0 : (v as num).toDouble();

/// Thông tin kết nối một đơn vị do gateway trả về.
class Tenant {
  Tenant({
    required this.code,
    required this.name,
    required this.apiBaseUrl,
    required this.primaryColor,
    this.logoUrl,
    this.webUrl,
    this.minAppVersion,
    this.pushEnabled = false,
    this.features = const {},
  });

  final String code;
  final String name;
  final String apiBaseUrl;
  final String primaryColor;
  final String? logoUrl;
  final String? webUrl;
  final String? minAppVersion;
  final bool pushEnabled;
  final Map<String, bool> features;

  /// Mã không có trong bản đồ coi là tắt (gateway mới có thêm tính năng app cũ chưa biết).
  bool hasFeature(String code) => features[code] ?? false;

  factory Tenant.fromJson(Map<String, dynamic> j) => Tenant(
        code: j['code'] as String,
        name: j['name'] as String,
        apiBaseUrl: (j['apiBaseUrl'] as String).replaceAll(RegExp(r'/+$'), ''),
        primaryColor: (j['primaryColor'] as String?) ?? '#087580',
        logoUrl: j['logoUrl'] as String?,
        webUrl: j['webUrl'] as String?,
        minAppVersion: j['minAppVersion'] as String?,
        pushEnabled: (j['pushEnabled'] as bool?) ?? false,
        features: {for (final e in ((j['features'] as Map?) ?? {}).entries) e.key as String: e.value == true},
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'apiBaseUrl': apiBaseUrl,
        'primaryColor': primaryColor,
        'logoUrl': logoUrl,
        'webUrl': webUrl,
        'minAppVersion': minAppVersion,
        'pushEnabled': pushEnabled,
        'features': features,
      };
}

class AppUser {
  AppUser({required this.fullName, required this.username, required this.department, required this.permissions, this.avatarUrl});

  final String fullName;
  final String username;
  final String department;
  final String? avatarUrl;
  final List<String> permissions;

  bool can(String permission) => permissions.contains(permission);

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        fullName: j['fullName'] as String,
        username: j['username'] as String,
        department: (j['department'] as String?) ?? '',
        avatarUrl: j['avatarThumbnailUrl'] as String?,
        permissions: ((j['permissions'] as List?) ?? const []).cast<String>(),
      );

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'username': username,
        'department': department,
        'avatarThumbnailUrl': avatarUrl,
        'permissions': permissions,
      };
}

class HomeCounts {
  HomeCounts({required this.openTasks, required this.overdue, required this.dueSoon, required this.pendingSign, required this.unread});
  final int openTasks, overdue, dueSoon, pendingSign, unread;
  factory HomeCounts.fromJson(Map<String, dynamic> j) => HomeCounts(
        openTasks: j['openTasks'] as int,
        overdue: j['overdue'] as int,
        dueSoon: j['dueSoon'] as int,
        pendingSign: j['pendingSign'] as int,
        unread: j['unreadNotifications'] as int,
      );
}

class AppTask {
  AppTask({
    required this.id,
    required this.code,
    required this.title,
    required this.taskTypeName,
    required this.priority,
    required this.progress,
    required this.dueAt,
    required this.isOverdue,
    this.stateName,
    this.ownerName,
    this.myRoles = const [],
  });

  final int id;
  final String code, title, taskTypeName, priority;
  final double progress;
  final DateTime dueAt;
  final bool isOverdue;
  final String? stateName, ownerName;
  final List<String> myRoles;

  factory AppTask.fromJson(Map<String, dynamic> j) => AppTask(
        id: j['id'] as int,
        code: j['code'] as String,
        title: j['title'] as String,
        taskTypeName: (j['taskTypeName'] as String?) ?? '',
        priority: (j['priority'] as String?) ?? 'NORMAL',
        progress: _num(j['progressPercent']),
        dueAt: _date(j['currentDueAt'])!,
        isOverdue: j['isOverdue'] == true,
        stateName: j['stateDisplayName'] as String?,
        ownerName: j['ownerName'] as String?,
        myRoles: ((j['myRoles'] as List?) ?? const []).cast<String>(),
      );
}

class TaskPage {
  TaskPage(this.items, this.total);
  final List<AppTask> items;
  final int total;
}

class HomeData {
  HomeData(this.counts, this.tasks);
  final HomeCounts counts;
  final List<AppTask> tasks;
}

class Assignment {
  Assignment({required this.roleName, required this.personName});
  final String roleName, personName;
}

class WorkflowAction {
  WorkflowAction({required this.code, required this.name, required this.requiresComment});
  final String code, name;
  final bool requiresComment;
}

class ProgressEntry {
  ProgressEntry({required this.percent, required this.createdAt, this.content, this.risks, this.proposal});
  final double percent;
  final DateTime createdAt;
  final String? content, risks, proposal;
}

class HistoryEntry {
  HistoryEntry({required this.stateName, required this.createdAt, this.comment});
  final String stateName;
  final DateTime createdAt;
  final String? comment;
}

class TaskDetail {
  TaskDetail({
    required this.id,
    required this.code,
    required this.title,
    required this.typeName,
    required this.workspaceName,
    required this.departmentName,
    required this.priority,
    required this.dueAt,
    required this.progress,
    required this.stateName,
    required this.rowVersion,
    required this.assignments,
    required this.actions,
    required this.progressUpdates,
    required this.history,
    this.confidentiality = 'INTERNAL',
    this.requiresResponse = false,
    this.description,
    this.completedAt,
  });

  final int id, rowVersion;
  final String code, title, typeName, workspaceName, departmentName, priority, stateName;
  final String? description;
  final String confidentiality;
  final bool requiresResponse;
  final DateTime dueAt;
  final DateTime? completedAt;
  final double progress;
  final List<Assignment> assignments;
  final List<WorkflowAction> actions;
  final List<ProgressEntry> progressUpdates;
  final List<HistoryEntry> history;

  bool get isDone => completedAt != null;
  bool get isOverdue => !isDone && dueAt.isBefore(DateTime.now());

  factory TaskDetail.fromJson(Map<String, dynamic> j) {
    List<Map<String, dynamic>> list(String key) => ((j[key] as List?) ?? const []).cast<Map<String, dynamic>>();
    final updates = list('progressUpdates').map((u) => ProgressEntry(
          percent: _num(u['progressPercent']),
          createdAt: _date(u['createdAt'])!,
          content: u['content'] as String?,
          risks: u['risks'] as String?,
          proposal: u['proposal'] as String?,
        )).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final history = list('statusHistories').map((h) => HistoryEntry(
          stateName: (h['toStateDisplayName'] as String?) ?? (h['toStateCode'] as String),
          createdAt: _date(h['createdAt'])!,
          comment: h['comment'] as String?,
        )).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final workflow = (j['workflow'] as Map?)?.cast<String, dynamic>();
    return TaskDetail(
      id: j['id'] as int,
      code: j['code'] as String,
      title: j['title'] as String,
      typeName: (j['taskTypeName'] as String?) ?? '',
      workspaceName: (j['workspaceName'] as String?) ?? '',
      departmentName: (j['ownerDepartmentName'] as String?) ?? '',
      priority: (j['priority'] as String?) ?? 'NORMAL',
      description: j['description'] as String?,
      confidentiality: (j['confidentiality'] as String?) ?? 'INTERNAL',
      requiresResponse: j['requiresResponseDocument'] == true,
      dueAt: _date(j['currentDueAt'])!,
      completedAt: _date(j['completedAt']),
      progress: _num(j['progressPercent']),
      stateName: (workflow?['currentStateDisplayName'] as String?) ?? '',
      rowVersion: j['rowVersion'] as int,
      assignments: list('assignments').map((a) => Assignment(roleName: a['assignmentRoleName'] as String, personName: a['personnelName'] as String)).toList(),
      actions: list('availableActions').map((a) => WorkflowAction(code: a['transitionCode'] as String, name: a['displayName'] as String, requiresComment: a['requiresComment'] == true || a['requiresReason'] == true)).toList(),
      progressUpdates: updates,
      history: history,
    );
  }
}

class NotificationItem {
  NotificationItem({required this.id, required this.type, required this.title, required this.createdAt, this.body, this.entityType, this.entityId, this.readAt, this.actorName});
  final int id;
  final String type, title;
  final String? body, entityType, actorName;
  final int? entityId;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  factory NotificationItem.fromJson(Map<String, dynamic> j) => NotificationItem(
        id: j['id'] as int,
        type: j['type'] as String,
        title: j['title'] as String,
        body: (j['message'] as String?) ?? (j['body'] as String?),
        entityType: j['entityType'] as String?,
        entityId: j['entityId'] as int?,
        createdAt: _date(j['createdAt'])!,
        readAt: _date(j['readAt']),
        actorName: (j['actor'] as Map?)?['name'] as String?,
      );
}

class DocSignature {
  DocSignature({required this.signerName, required this.signedAt, this.verifyStatus});
  final String signerName;
  final DateTime signedAt;
  /// VALID | INVALID | UNKNOWN; null khi chưa kiểm tra xong.
  final String? verifyStatus;
}

class DocStep {
  DocStep({required this.no, required this.name, required this.action, required this.signer, required this.status, required this.isMine, this.actedBy, this.actedAt, this.comment, this.signMethod = 'STAMP'});
  final int no;
  final String name, action, signer, status, signMethod;
  bool get isDigital => action == 'SIGN' && signMethod == 'DIGITAL';
  final bool isMine;
  final String? actedBy, comment;
  final DateTime? actedAt;
}

class DocumentItem {
  DocumentItem({
    required this.id,
    required this.taskCode,
    required this.taskTitle,
    required this.typeName,
    required this.title,
    required this.status,
    required this.canAct,
    required this.steps,
    required this.fileName,
    this.workspaceName = '',
    this.signatures = const [],
    this.confidentiality = 'INTERNAL',
    this.versionId,
    this.versionNo = 1,
    this.signedVersion = false,
    this.documentNo,
    this.note,
    this.createdBy,
    this.submittedAt,
  });

  final int id;
  final int? versionId; // phiên bản mới nhất (sau khi ký là bản có dấu ký)
  final int versionNo;
  final bool signedVersion;
  final String taskCode, taskTitle, typeName, title, status, fileName;
  final String? documentNo, note, createdBy;
  final DateTime? submittedAt;
  final bool canAct;
  final List<DocStep> steps;
  final String workspaceName, confidentiality;
  final List<DocSignature> signatures;
  /// Văn bản độc lập: không thuộc công việc nào, chỉ thuộc một dự án.
  bool get isStandalone => taskCode.isEmpty;
  /// Bước đang chờ của tôi (nếu có), để biết đây là ký, duyệt hay kiểm tra.
  DocStep? get myStep { for (final s in steps) { if (s.isMine) return s; } return null; }

  factory DocumentItem.fromJson(Map<String, dynamic> j) {
    // Máy chủ trả phiên bản mới nhất trước; không dựa vào thứ tự mà chọn theo số phiên bản lớn nhất.
    final versions = ((j['versions'] as List?) ?? const []).cast<Map<String, dynamic>>().toList()..sort((a, b) => (a['versionNo'] as int).compareTo(b['versionNo'] as int));
    final round = j['round'] as int? ?? 1;
    final steps = ((j['steps'] as List?) ?? const []).cast<Map<String, dynamic>>().where((s) => (s['round'] as int? ?? round) == round).map((s) => DocStep(
          no: s['stepNo'] as int,
          name: s['name'] as String,
          action: (s['action'] as String?) ?? '',
          signer: (s['signerLabel'] as String?) ?? '',
          status: s['status'] as String,
          isMine: s['isMine'] == true,
          actedBy: s['actedByName'] as String?,
          actedAt: _date(s['actedAt']),
          comment: s['comment'] as String?,
          signMethod: (s['signMethod'] as String?) ?? 'STAMP',
        )).toList()
      ..sort((a, b) => a.no.compareTo(b.no));
    return DocumentItem(
      id: j['id'] as int,
      taskCode: (j['taskCode'] as String?) ?? '',
      taskTitle: (j['taskTitle'] as String?) ?? '',
      typeName: (j['documentTypeName'] as String?) ?? '',
      title: j['title'] as String,
      documentNo: j['documentNo'] as String?,
      note: j['note'] as String?,
      status: j['status'] as String,
      createdBy: j['createdByName'] as String?,
      submittedAt: _date(j['submittedAt']),
      canAct: j['canAct'] == true,
      fileName: versions.isEmpty ? '' : (versions.last['fileName'] as String? ?? ''),
      versionId: versions.isEmpty ? null : versions.last['id'] as int?,
      versionNo: versions.isEmpty ? 1 : versions.last['versionNo'] as int,
      signedVersion: versions.isNotEmpty && versions.last['kind'] == 'SIGNED',
      workspaceName: (j['workspaceName'] as String?) ?? '',
      confidentiality: (j['confidentiality'] as String?) ?? 'INTERNAL',
      signatures: ((j['signatures'] as List?) ?? const []).cast<Map<String, dynamic>>().map((x) => DocSignature(
            signerName: (x['signerName'] as String?) ?? '',
            signedAt: _date(x['signedAt']) ?? DateTime.now(),
            verifyStatus: x['verifyStatus'] as String?)).toList(),
      steps: steps,
    );
  }
}

class DocumentInbox {
  DocumentInbox({required this.items, required this.pending, required this.submitted, required this.done, required this.all});
  final List<DocumentItem> items;
  final int pending, submitted, done, all;
}
