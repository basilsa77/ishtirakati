import 'package:flutter_test/flutter_test.dart';
import 'package:ishtirakati/models/subscription.dart';
import 'package:ishtirakati/models/subscription_schema.dart';
import 'package:ishtirakati/services/financial_leakage.dart';

void main() {
  test('ترحيل v11 إلى v12 يحفظ الهوية والقيمة ويضيف الحقول فقط', () {
    final legacy = <String, dynamic>{
      'id': 'v11-record',
      'name': 'خدمة قديمة',
      'emoji': 'S',
      'price': 39.5,
      'currency': 'SAR',
      'cycle': BillingCycle.monthly.index,
      'anchor': '2025-01-31T00:00:00.000',
      'category': 'إنتاجية وذكاء اصطناعي',
      'notes': 'تبقى كما هي',
    };

    final migrated = SubscriptionSchema.migrateToV12(legacy);
    final subscription = Subscription.fromJson(migrated);

    expect(migrated['schemaVersion'], 12);
    expect(subscription.id, 'v11-record');
    expect(subscription.name, 'خدمة قديمة');
    expect(subscription.price, 39.5);
    expect(subscription.notes, 'تبقى كما هي');
    expect(subscription.usageCount, 0);
    expect(subscription.toJson()['schemaVersion'], 12);
  });

  test('لوحة التسرّب تحسب التعرض السنوي وتقسيم العائلة بدقة', () {
    final items = [
      Subscription(
        id: 'unused',
        name: 'غير مستخدم',
        emoji: 'U',
        price: 50,
        currency: 'SAR',
        cycle: BillingCycle.monthly,
        anchorDate: DateTime(2025),
        category: 'أخرى',
      ),
      Subscription(
        id: 'family',
        name: 'عائلي',
        emoji: 'F',
        price: 120,
        currency: 'SAR',
        cycle: BillingCycle.monthly,
        anchorDate: DateTime(2025),
        category: 'ترفيه ومشاهدة',
        usageCount: 3,
        isFamily: true,
        familyMembers: 4,
      ),
    ];

    final result = FinancialLeakage.calculate(items, currency: 'SAR');
    expect(result.monthlyCommitment, 170);
    expect(result.annualCommitment, 2040);
    expect(result.unusedAnnualExposure, 600);
    expect(result.familyMonthlyShare, 30);
    expect(result.mostExpensive?.id, 'family');
  });
}
