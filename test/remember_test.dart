import 'package:dtask_app/core/models.dart';
import 'package:dtask_app/core/remember.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<RememberStore> newStore() async {
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({});
  return RememberStore(await SharedPreferences.getInstance());
}

void main() {
  test('gợi ý mã đơn vị và tên đăng nhập, mới nhất trước, không trùng', () async {
    final s = await newStore();
    await s.recordSuccess('bvta', 'an');
    await s.recordSuccess('BVMA', 'binh');
    await s.recordSuccess('BVTA', 'AN');
    expect(s.recentCodes(), ['BVTA', 'BVMA']);
    await s.recordSuccess('BVTA', 'cuong');
    expect(s.recentUsers('bvta'), ['cuong', 'AN']);
    expect(s.recentUsers('BVMA'), ['binh']);
  });

  test('cùng tên đăng nhập ở hai đơn vị là hai mục riêng, mật khẩu cũng riêng', () async {
    final s = await newStore();
    await s.recordSuccess('BVTA', 'an', tenantName: 'Bệnh viện Thiên An');
    await s.recordSuccess('BVMA', 'an', tenantName: 'Bệnh viện Minh An');
    await s.savePassword('BVTA', 'an', 'mk-thien-an');
    await s.savePassword('BVMA', 'an', 'mk-minh-an');
    final logins = s.recentLogins();
    expect(logins.map((l) => '${l.code}/${l.username}'), ['BVMA/an', 'BVTA/an']);
    expect(logins.first.tenantName, 'Bệnh viện Minh An');
    expect(s.recentUsers('BVTA'), ['an']);
    expect(await s.password('BVTA', 'an'), 'mk-thien-an');
    expect(await s.password('BVMA', 'an'), 'mk-minh-an');
    await s.forgetUser('BVMA', 'an');
    expect(s.recentLogins().map((l) => l.code), ['BVTA']);
    expect(await s.password('BVTA', 'an'), 'mk-thien-an');
  });

  test('ghi lại lần đăng nhập không có tên đơn vị thì giữ tên đã biết', () async {
    final s = await newStore();
    await s.recordSuccess('BVTA', 'an', tenantName: 'Bệnh viện Thiên An');
    await s.recordSuccess('BVTA', 'an');
    expect(s.recentLogins().single.tenantName, 'Bệnh viện Thiên An');
  });

  test('chỉ giữ tối đa 5 gợi ý', () async {
    final s = await newStore();
    for (var i = 0; i < 8; i++) {
      await s.recordSuccess('C$i', 'u$i');
    }
    expect(s.recentCodes().length, RememberStore.maxItems);
    expect(s.recentCodes().first, 'C7');
  });

  test('ghi nhớ mật khẩu theo từng đơn vị và tên, không phân biệt hoa thường tên', () async {
    final s = await newStore();
    await s.savePassword('BVTA', 'An', 'mk-1');
    expect(await s.password('bvta', 'an'), 'mk-1');
    expect(await s.password('BVMA', 'an'), isNull);
    await s.clearPassword('BVTA', 'AN');
    expect(await s.password('BVTA', 'an'), isNull);
  });

  test('quên một tên đăng nhập thì xóa luôn mật khẩu đã lưu', () async {
    final s = await newStore();
    await s.recordSuccess('BVTA', 'an');
    await s.savePassword('BVTA', 'an', 'mk');
    await s.forgetUser('BVTA', 'AN');
    expect(s.recentUsers('BVTA'), isEmpty);
    expect(await s.hasPassword('BVTA', 'an'), isFalse);
  });

  test('chọn bản có số phiên bản lớn nhất dù máy chủ trả theo thứ tự nào', () {
    DocumentItem parse(List<Map<String, dynamic>> versions) => DocumentItem.fromJson({
          'id': 1,
          'title': 't',
          'status': 'IN_SIGNING',
          'round': 1,
          'steps': [],
          'versions': versions,
        });
    final newestFirst = parse([
      {'id': 30, 'versionNo': 3, 'kind': 'SIGNED', 'fileName': 'a-signed.pdf'},
      {'id': 20, 'versionNo': 2, 'kind': 'SIGNED', 'fileName': 'a-signed.pdf'},
      {'id': 10, 'versionNo': 1, 'kind': 'UPLOAD', 'fileName': 'a.pdf'},
    ]);
    expect(newestFirst.versionId, 30);
    expect(newestFirst.signedVersion, isTrue);
    expect(newestFirst.fileName, 'a-signed.pdf');
    final oldestFirst = parse([
      {'id': 10, 'versionNo': 1, 'kind': 'UPLOAD', 'fileName': 'a.pdf'},
      {'id': 30, 'versionNo': 3, 'kind': 'SIGNED', 'fileName': 'a-signed.pdf'},
    ]);
    expect(oldestFirst.versionId, 30);
  });
}
