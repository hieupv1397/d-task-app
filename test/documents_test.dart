import 'package:dio/dio.dart';
import 'package:dtask_app/core/api.dart';
import 'package:dtask_app/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> doc({String taskCode = '', String? method}) => {
        'id': 7,
        'taskCode': taskCode,
        'taskTitle': 'Văn bản độc lập',
        'workspaceName': 'Dự án A',
        'documentTypeName': 'Công văn',
        'title': 'Công văn gửi Sở',
        'status': 'IN_SIGNING',
        'canAct': true,
        'round': 1,
        'versions': [
          {'id': 1, 'versionNo': 1, 'kind': 'UPLOAD', 'fileName': 'cv.docx'}
        ],
        'steps': [
          {'stepNo': 1, 'round': 1, 'name': 'Lãnh đạo ký', 'action': 'SIGN', 'signerLabel': 'Giám đốc', 'status': 'PENDING', 'isMine': true, 'signMethod': method ?? 'STAMP'},
        ],
        'signatures': [
          {'signerName': 'Trần Chủ Trì', 'signedAt': '2026-11-20T03:00:00Z', 'verifyStatus': 'VALID'}
        ],
      };

  test('văn bản độc lập hiện dự án và nhận ra bước ký số của tôi', () {
    final d = DocumentItem.fromJson(doc(method: 'DIGITAL'));
    expect(d.isStandalone, isTrue);
    expect(d.workspaceName, 'Dự án A');
    expect(d.myStep?.isDigital, isTrue);
    expect(d.signatures.single.verifyStatus, 'VALID');
  });

  test('văn bản thuộc công việc, ký đóng dấu thường không phải ký số', () {
    final d = DocumentItem.fromJson(doc(taskCode: 'CV-1'));
    expect(d.isStandalone, isFalse);
    expect(d.myStep?.isDigital, isFalse);
  });

  test('lỗi OTP của máy chủ giữ lại mã giao dịch để gửi lại', () {
    final e = toApiError(DioException(
      requestOptions: RequestOptions(path: '/x'),
      response: Response(requestOptions: RequestOptions(path: '/x'), statusCode: 428, data: {'code': 'OTP_REQUIRED', 'message': 'Nhập mã OTP.', 'otpTransactionId': 'tx-9'}),
    ));
    expect(e.needsOtp, isTrue);
    expect(e.otpTransactionId, 'tx-9');
    expect(e.message, 'Nhập mã OTP.');
  });
}
