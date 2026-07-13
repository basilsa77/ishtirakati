import 'package:flutter_test/flutter_test.dart';
import 'package:ishtirakati/models/subscription.dart';
import 'package:ishtirakati/services/financial_assistant.dart';

Subscription sub({
  required String id,
  required String name,
  required double price,
  BillingCycle cycle = BillingCycle.monthly,
  int usageCount = 1,
  bool essential = false,
  bool autoRenews = true,
  String manageUrl = '',
  int? installments,
}) {
  return Subscription(
    id: id,
    name: name,
    emoji: 'S',
    price: price,
    currency: 'SAR',
    cycle: cycle,
    anchorDate: DateTime(2026, 1, 15),
    category: 'أخرى',
    usageCount: usageCount,
    isEssential: essential,
    autoRenews: autoRenews,
    manageUrl: manageUrl,
    kind: installments == null
        ? PaymentKind.subscription
        : PaymentKind.installment,
    totalInstallments: installments,
  );
}

void main() {
  test('توقع 12 شهرًا يحسب الدفعات الأسبوعية ويوقف الأقساط المنتهية', () {
    final weekly = sub(
      id: 'weekly',
      name: 'أسبوعي',
      price: 10,
      cycle: BillingCycle.weekly,
    );
    final installment = sub(
      id: 'installment',
      name: 'قسط',
      price: 100,
      installments: 2,
    );
    final result = FinancialAssistant.analyze(
      [weekly, installment],
      currency: 'SAR',
      now: DateTime(2026, 1, 1),
    );

    expect(result.forecast, hasLength(12));
    expect(result.forecast.first.total, 130);
    expect(result.forecast[1].total, 140);
    expect(result.forecast[2].total, 40);
  });

  test('يكشف الخطط المكررة ويحسب الوفر دون احتساب الاشتراك مرتين', () {
    final result = FinancialAssistant.analyze(
      [
        sub(id: 'one', name: 'Netflix Basic', price: 30, usageCount: 0),
        sub(id: 'two', name: 'Netflix Premium', price: 60, usageCount: 0),
      ],
      currency: 'SAR',
      now: DateTime(2026, 7, 1),
    );

    expect(result.duplicateGroups, hasLength(1));
    expect(result.duplicateGroups.single.avoidableMonthlyCost, 60);
    expect(result.potentialMonthlySavings, 90);
    expect(
      result.reviewItems.where(
        (item) => item.reason == FinancialReviewReason.duplicate,
      ),
      hasLength(1),
    );
  });

  test('لا يقترح إلغاء خدمة أساسية منخفضة الاستخدام', () {
    final result = FinancialAssistant.analyze(
      [sub(id: 'essential', name: 'خدمة أساسية', price: 80, usageCount: 0, essential: true)],
      currency: 'SAR',
      now: DateTime(2026, 7, 1),
    );
    expect(result.potentialMonthlySavings, 0);
    expect(result.reviewItems, isEmpty);
  });

  test('مقارنة الخطط توحد الدورات إلى تكلفة شهرية وسنوية', () {
    final current = sub(id: 'current', name: 'خطة حالية', price: 50);
    final comparison = FinancialAssistant.comparePlans(
      current,
      alternativePrice: 480,
      alternativeCycle: BillingCycle.yearly,
    );
    expect(comparison.currentMonthlyCost, 50);
    expect(comparison.alternativeMonthlyCost, 40);
    expect(comparison.monthlyDifference, -10);
    expect(comparison.annualDifference, -120);
    expect(comparison.alternativeSavesMoney, isTrue);
  });
}
