import 'package:flutter_test/flutter_test.dart';
import 'package:ishtirakati/models/subscription.dart';
import 'package:ishtirakati/services/notification_planner.dart';

void main() {
  final now = DateTime(2026, 1, 1, 8);

  Subscription subscription({
    String id = 'one',
    bool autoRenews = true,
    DateTime? trialEnd,
  }) => Subscription(
    id: id,
    name: 'خدمة خاصة',
    emoji: 'خ',
    price: 50,
    currency: 'SAR',
    cycle: BillingCycle.monthly,
    anchorDate: DateTime(2026, 1, 10),
    category: 'أخرى',
    reminderDays: 3,
    trialEndDate: trialEnd,
    autoRenews: autoRenews,
  );

  test('لا يجدول تجديدًا عند إيقاف التجديد التلقائي', () {
    final result = NotificationPlanner.build([
      subscription(autoRenews: false),
    ], now: now);

    expect(result, isEmpty);
  });

  test('المحتوى الخاص لا يكشف الاسم أو المبلغ', () {
    final result = NotificationPlanner.build([subscription()], now: now);

    expect(result, hasLength(1));
    expect(result.single.title, isNot(contains('خدمة خاصة')));
    expect(result.single.body, isNot(contains('50')));
  });

  test('التجربة لها تنبيه مستقل وأولوية أعلى', () {
    final result = NotificationPlanner.build(
      [subscription(trialEnd: DateTime(2026, 1, 8))],
      now: now,
      privateContent: false,
    );

    expect(result, hasLength(2));
    expect(
      result.map((item) => item.priority).reduce((a, b) => a > b ? a : b),
      120,
    );
  });

  test('لا يتجاوز حد iOS الآمن', () {
    final items = List.generate(80, (index) => subscription(id: '$index'));
    final result = NotificationPlanner.build(items, now: now);

    expect(result, hasLength(60));
  });
}
