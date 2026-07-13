import 'package:flutter_test/flutter_test.dart';
import 'package:ishtirakati/services/device_greeting.dart';

void main() {
  test('يعرض صباح الخير قبل الظهر', () {
    expect(deviceGreeting(DateTime(2026, 7, 14, 0)), 'صباح الخير');
    expect(deviceGreeting(DateTime(2026, 7, 14, 11, 59)), 'صباح الخير');
  });

  test('يعرض مساء الخير من الظهر حتى نهاية اليوم', () {
    expect(deviceGreeting(DateTime(2026, 7, 14, 12)), 'مساء الخير');
    expect(deviceGreeting(DateTime(2026, 7, 14, 23, 59)), 'مساء الخير');
  });
}
