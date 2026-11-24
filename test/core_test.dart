import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dtask_app/core/api.dart';
import 'package:dtask_app/core/config.dart';
import 'package:dtask_app/core/models.dart';
import 'package:dtask_app/core/push.dart';

void main() {
  group('isVersionBelow', () {
    test('không yêu cầu tối thiểu thì không chặn', () {
      expect(isVersionBelow('1.0.0', null), isFalse);
      expect(isVersionBelow('1.0.0', ''), isFalse);
    });
    test('so sánh từng thành phần theo số, không theo chuỗi', () {
      expect(isVersionBelow('1.2.0', '1.10.0'), isTrue);
      expect(isVersionBelow('1.10.0', '1.2.0'), isFalse);
      expect(isVersionBelow('2.0.0', '1.9.9'), isFalse);
      expect(isVersionBelow('1.0.0', '1.0.0'), isFalse);
    });
    test('bỏ phần build và chấp nhận thiếu thành phần', () {
      expect(isVersionBelow('1.0.0+5', '1.0.1'), isTrue);
      expect(isVersionBelow('1.2', '1.2.0'), isFalse);
      expect(isVersionBelow('1.2', '1.2.1'), isTrue);
    });
  });

  group('Tenant', () {
    final json = {
      'code': 'BVTA',
      'name': 'Bệnh viện Thiên An',
      'apiBaseUrl': 'https://api.bvta.vn///',
      'primaryColor': '#087580',
      'pushEnabled': true,
      'features': {'DOC_SIGN': true, 'TASK_CREATE': false},
    };

    test('chuẩn hóa địa chỉ API và đọc cờ tính năng', () {
      final t = Tenant.fromJson(json);
      expect(t.apiBaseUrl, 'https://api.bvta.vn');
      expect(t.hasFeature('DOC_SIGN'), isTrue);
      expect(t.hasFeature('TASK_CREATE'), isFalse);
    });
    test('tính năng không có trong bản đồ coi là tắt', () {
      expect(Tenant.fromJson(json).hasFeature('MOT_TINH_NANG_MOI'), isFalse);
      expect(Tenant.fromJson({...json}..remove('features')).hasFeature('DOC_SIGN'), isFalse);
    });
    test('lưu rồi đọc lại không mất dữ liệu', () {
      final back = Tenant.fromJson(Tenant.fromJson(json).toJson());
      expect(back.code, 'BVTA');
      expect(back.features['DOC_SIGN'], isTrue);
    });
  });

  group('TaskDetail.fromJson', () {
    test('đọc hành động quy trình, người tham gia và sắp xếp lịch sử mới nhất trước', () {
      final d = TaskDetail.fromJson({
        'id': 7,
        'code': 'CV-1',
        'title': 'Việc thử',
        'taskTypeName': 'Loại',
        'workspaceName': 'KG',
        'ownerDepartmentName': 'Phòng A',
        'priority': 'HIGH',
        'currentDueAt': '2026-01-01T00:00:00Z',
        'completedAt': null,
        'progressPercent': 40,
        'rowVersion': 3,
        'workflow': {'currentStateDisplayName': 'Đang xử lý'},
        'assignments': [
          {'assignmentRoleName': 'Phụ trách', 'personnelName': 'An'}
        ],
        'availableActions': [
          {'transitionCode': 'DONE', 'displayName': 'Hoàn thành', 'requiresComment': false, 'requiresReason': true}
        ],
        'progressUpdates': [
          {'progressPercent': 10, 'createdAt': '2026-01-02T00:00:00Z'},
          {'progressPercent': 40, 'createdAt': '2026-01-03T00:00:00Z', 'content': 'Xong một nửa'},
        ],
        'statusHistories': [],
      });
      expect(d.stateName, 'Đang xử lý');
      expect(d.actions.single.requiresComment, isTrue);
      expect(d.assignments.single.personName, 'An');
      expect(d.progressUpdates.first.percent, 40);
      expect(d.isDone, isFalse);
      expect(d.rowVersion, 3);
    });
  });

  group('toApiError', () {
    DioException err(int? status, [Object? data]) => DioException(
          requestOptions: RequestOptions(path: '/x'),
          response: status == null ? null : Response(requestOptions: RequestOptions(path: '/x'), statusCode: status, data: data),
        );

    test('không có phản hồi nghĩa là mất mạng', () {
      expect(toApiError(err(null)).message, contains('Không kết nối'));
    });
    test('lấy nguyên văn thông báo máy chủ trả về dạng chuỗi', () {
      expect(toApiError(err(400, 'Mật khẩu không đúng.')).message, 'Mật khẩu không đúng.');
    });
    test('mã trạng thái không kèm thông báo thì dùng câu mặc định', () {
      expect(toApiError(err(403)).message, contains('không có quyền'));
      expect(toApiError(err(409)).message, contains('thay đổi'));
    });
  });

  group('pushMatchesTenant', () {
    test('chỉ nhận tin đúng đơn vị đang đăng nhập, không phân biệt hoa thường', () {
      expect(pushMatchesTenant({'tenant': 'BVTA'}, 'bvta'), isTrue);
      expect(pushMatchesTenant({'tenant': 'BVMA'}, 'BVTA'), isFalse);
    });
    test('tin không gắn mã đơn vị hoặc chưa đăng nhập thì không chặn', () {
      expect(pushMatchesTenant({}, 'BVTA'), isTrue);
      expect(pushMatchesTenant({'tenant': 'BVTA'}, null), isTrue);
    });
  });

  group('routeForPush', () {
    test('thông báo văn bản mở hộp văn bản', () {
      expect(routeForPush({'type': 'DOC_SIGN_REQUEST', 'entityId': '5'}), '/documents');
    });
    test('thông báo công việc mở đúng công việc', () {
      expect(routeForPush({'type': 'TASK_OVERDUE', 'entityId': '47'}), '/task/47');
    });
    test('thiếu mã thì mở hộp thông báo', () {
      expect(routeForPush({'type': 'TASK_OVERDUE'}), '/notifications');
      expect(routeForPush({}), '/notifications');
    });
  });
}
