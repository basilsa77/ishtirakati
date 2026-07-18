import 'package:flutter_test/flutter_test.dart';
import 'package:ishtirakati/models/subscription.dart';
import 'package:ishtirakati/models/subscription_schema.dart';

void main() {
  test('ترحيل v12 إلى v13 يحفظ جميع بيانات المستخدم ويضيف افتراضات محافظة', () {
    final v12 = <String, dynamic>{
      'schemaVersion': 12,
      'id': 'v12-production-record',
      'name': 'Netflix',
      'emoji': 'N',
      'price': 55.99,
      'currency': 'SAR',
      'cycle': BillingCycle.monthly.index,
      'anchor': '2026-01-31T00:00:00.000',
      'category': 'ترفيه ومشاهدة',
      'notes': 'حساب العائلة',
      'paused': false,
      'payMethod': 'بطاقة ائتمانية',
      'manageUrl': 'https://example.com/manage',
      'reminderDays': 5,
      'trialEnd': '2026-08-01T00:00:00.000',
      'priceHistory': [
        {'p': 49.99, 'd': '2026-01-01T00:00:00.000'},
      ],
      'isFamily': true,
      'familyMembers': 4,
      'usageCount': 8,
      'lastUsedAt': '2026-07-10T00:00:00.000',
      'iconUrl': 'https://example.com/icon.png',
      'kind': PaymentKind.subscription.index,
      'totalInstallments': null,
      'unknownFutureSafeField': 'preserved',
    };

    final migrated = SubscriptionSchema.migrateToV13(v12);
    final subscription = Subscription.fromJson(migrated);
    final encoded = subscription.toJson();

    expect(migrated['schemaVersion'], 13);
    expect(migrated['unknownFutureSafeField'], 'preserved');
    expect(subscription.id, 'v12-production-record');
    expect(subscription.name, 'Netflix');
    expect(subscription.price, 55.99);
    expect(subscription.notes, 'حساب العائلة');
    expect(subscription.reminderDays, 5);
    expect(subscription.priceHistory.single.oldPrice, 49.99);
    expect(subscription.isFamily, isTrue);
    expect(subscription.familyMembers, 4);
    expect(subscription.usageCount, 8);
    expect(subscription.autoRenews, isTrue);
    expect(subscription.isEssential, isFalse);
    expect(subscription.planName, isEmpty);
    expect(subscription.lastReviewedAt, isNull);
    expect(encoded['schemaVersion'], 14);
    expect(encoded['ignoredDuplicateGroupKeys'], isEmpty);
  });

  test('ترحيل v13 لا يغيّر قيم الحقول الجديدة الموجودة', () {
    final record = <String, dynamic>{
      'schemaVersion': 13,
      'id': 'reviewed',
      'name': 'خدمة عمل',
      'price': 25,
      'currency': 'SAR',
      'cycle': BillingCycle.monthly.index,
      'anchor': '2026-01-01',
      'category': 'إنتاجية وذكاء اصطناعي',
      'autoRenews': false,
      'isEssential': true,
      'planName': 'الخطة الاحترافية',
      'lastReviewedAt': '2026-07-01T00:00:00.000',
    };

    final subscription = Subscription.fromJson(record);
    expect(subscription.autoRenews, isFalse);
    expect(subscription.isEssential, isTrue);
    expect(subscription.planName, 'الخطة الاحترافية');
    expect(subscription.lastReviewedAt, DateTime(2026, 7, 1));
  });

  test('سجل من إصدار مستقبلي لا يُخفض أو يعاد تشكيله', () {
    final future = <String, dynamic>{
      'schemaVersion': 99,
      'id': 'future',
      'futureOnly': true,
    };
    expect(SubscriptionSchema.migrateToV13(future), future);
  });
}
