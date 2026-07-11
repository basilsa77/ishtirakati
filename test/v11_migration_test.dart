import 'package:flutter_test/flutter_test.dart';
import 'package:ishtirakati/models/subscription.dart';

void main() {
  test('v11 يقرأ سجلًا قديمًا دون الحقول الحديثة ويحافظ على هويته', () {
    final legacy = <String, dynamic>{
      'id': 'legacy-1',
      'name': 'اشتراك قديم',
      'emoji': '🔖',
      'price': 29.99,
      'currency': 'SAR',
      'cycle': BillingCycle.monthly.index,
      'anchor': '2025-01-31T00:00:00.000',
      'category': 'ترفيه ومشاهدة',
    };

    final subscription = Subscription.fromJson(legacy);
    expect(subscription.id, 'legacy-1');
    expect(subscription.kind, PaymentKind.subscription);
    expect(subscription.usageCount, 0);
    expect(subscription.isFamily, isFalse);
    expect(subscription.reminderDays, 3);

    final encoded = subscription.toJson();
    expect(encoded['id'], 'legacy-1');
    expect(encoded['price'], 29.99);
    expect(encoded['kind'], PaymentKind.subscription.index);
  });

  test('v11 يطبع قيم الحقول المقيدة في السجل المستورد', () {
    final record = <String, dynamic>{
      'id': 'bounded',
      'name': 'اختبار الحدود',
      'price': 10,
      'currency': 'SAR',
      'cycle': 999,
      'kind': 999,
      'anchor': '2026-01-01',
      'category': 'أخرى',
      'familyMembers': 999,
      'usageCount': -50,
    };

    final subscription = Subscription.fromJson(record);
    expect(subscription.cycle, BillingCycle.yearly);
    expect(subscription.kind, PaymentKind.bill);
    expect(subscription.familyMembers, 20);
    expect(subscription.usageCount, 0);
  });
}
