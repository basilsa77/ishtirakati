import 'package:flutter_test/flutter_test.dart';
import 'package:ishtirakati/services/remote_announcements.dart';

void main() {
  test('يحلل إعلانات صالحة ويتجاهل الناقص والروابط غير الآمنة', () {
    final parsed = parseAnnouncements('''
{
  "version": 3,
  "announcements": [
    {"id":"ann-1","title":"الإصدار 17","body":"متاح الآن","link":"https://example.com","publishedAt":"2026-07-19"},
    {"id":"ann-2","title":"تنبيه","body":"نص","link":"http://insecure.example","publishedAt":"2026-07-18"},
    {"id":"","title":"بلا معرف","body":"يُتجاهل"},
    {"id":"ann-3","title":"  ","body":"عنوان فارغ يُتجاهل"},
    {"id":"ann-4","title":"بلا نص","body":""}
  ]
}
''');
    expect(parsed.length, 2);
    expect(parsed[0].id, 'ann-1');
    expect(parsed[0].link, 'https://example.com');
    expect(parsed[1].id, 'ann-2');
    expect(parsed[1].link, isNull); // http يُرفض
  });

  test('يعيد قائمة فارغة لأي مدخل تالف دون رمي استثناء', () {
    expect(parseAnnouncements(''), isEmpty);
    expect(parseAnnouncements('not json'), isEmpty);
    expect(parseAnnouncements('[]'), isEmpty);
    expect(parseAnnouncements('{"announcements": {}}'), isEmpty);
    expect(parseAnnouncements('{"announcements": [42, null]}'), isEmpty);
  });

  test('يحدّ النتائج إلى 20 إعلانًا', () {
    final many = List.generate(
      30,
      (i) => '{"id":"a$i","title":"t$i","body":"b$i"}',
    ).join(',');
    expect(parseAnnouncements('{"announcements":[$many]}').length, 20);
  });
}
