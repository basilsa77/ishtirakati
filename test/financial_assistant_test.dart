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
  DateTime? anchorDate,
  DateTime? lastReviewedAt,
  String planName = '',
  String paymentMethod = 'غير محدد',
}) {
  return Subscription(
    id: id,
    name: name,
    emoji: 'S',
    price: price,
    currency: 'SAR',
    cycle: cycle,
    anchorDate: anchorDate ?? DateTime(2026, 1, 15),
    category: 'أخرى',
    usageCount: usageCount,
    isEssential: essential,
    autoRenews: autoRenews,
    manageUrl: manageUrl,
    kind:
        installments == null
            ? PaymentKind.subscription
            : PaymentKind.installment,
    totalInstallments: installments,
    lastReviewedAt: lastReviewedAt,
    planName: planName,
    paymentMethod: paymentMethod,
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

  test('توقع 12 شهرًا يستخدم فترة متحركة كاملة لا شهرًا أول جزئيًا', () {
    final monthly = sub(
      id: 'monthly',
      name: 'خدمة شهرية',
      price: 100,
      anchorDate: DateTime(2025, 1, 15),
    );
    final result = FinancialAssistant.analyze(
      [monthly],
      currency: 'SAR',
      now: DateTime(2026, 1, 20),
    );

    expect(result.forecast, hasLength(12));
    expect(result.forecast.every((period) => period.paymentCount == 1), isTrue);
    expect(result.next12MonthsForecast, 1200);
    expect(result.next12MonthsForecast, monthly.yearlyCost);
  });

  test('اختلاف التوقع الأسبوعي ناتج عن عدد الدفعات الفعلي', () {
    final weekly = sub(
      id: 'weekly-only',
      name: 'خدمة أسبوعية',
      price: 73.99,
      cycle: BillingCycle.weekly,
      anchorDate: DateTime(2025, 1, 1),
    );
    final result = FinancialAssistant.analyze(
      [weekly],
      currency: 'SAR',
      now: DateTime(2026, 1, 1),
    );

    for (final period in result.forecast) {
      expect(period.total, closeTo(period.paymentCount * weekly.price, .001));
      expect(period.paymentCount, anyOf(4, 5));
    }
    expect(
      result.forecast.map((period) => period.paymentCount).toSet(),
      containsAll(<int>{4, 5}),
    );
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
    expect(result.duplicateCandidateCount, 1);
    expect(result.potentialMonthlySavings, 60);
    expect(
      result.reviewItems.where(
        (item) => item.reason == FinancialReviewReason.duplicate,
      ),
      hasLength(1),
    );
  });

  test('لا يعتبر روابط متاجر التطبيقات العامة دليلاً على التكرار', () {
    final result = FinancialAssistant.analyze(
      [
        sub(
          id: 'netflix',
          name: 'Netflix',
          price: 55,
          manageUrl: 'https://apps.apple.com/app/netflix/id363590051',
        ),
        sub(
          id: 'spotify',
          name: 'Spotify',
          price: 22,
          manageUrl: 'https://apps.apple.com/app/spotify/id324684580',
        ),
      ],
      currency: 'SAR',
      now: DateTime(2026, 7, 1),
    );

    expect(result.duplicateGroups, isEmpty);
  });

  test('السجل القديم بلا تاريخ مراجعة لا يصنف تلقائيًا كمشكلة', () {
    final result = FinancialAssistant.analyze(
      [sub(id: 'legacy', name: 'خدمة مستخدمة', price: 50)],
      currency: 'SAR',
      now: DateTime(2026, 7, 1),
    );
    expect(result.reviewItems, isEmpty);
  });

  test('يظهر تنبيه عدم الاستخدام بعد فترة قياس فعلية فقط', () {
    final result = FinancialAssistant.analyze(
      [
        sub(
          id: 'measured-unused',
          name: 'خدمة تحت القياس',
          price: 50,
          usageCount: 0,
          lastReviewedAt: DateTime(2026, 5, 1),
        ),
      ],
      currency: 'SAR',
      now: DateTime(2026, 7, 1),
    );

    expect(result.reviewItems, hasLength(1));
    expect(
      result.reviewItems.single.reason,
      FinancialReviewReason.unusedAutoRenewal,
    );
  });

  test('يعرض المراجعة المتأخرة فقط بعد وجود تاريخ مراجعة فعلي', () {
    final result = FinancialAssistant.analyze(
      [
        sub(
          id: 'reviewed',
          name: 'خدمة قديمة المراجعة',
          price: 50,
          lastReviewedAt: DateTime(2025, 1, 1),
        ),
      ],
      currency: 'SAR',
      now: DateTime(2026, 7, 1),
    );
    expect(result.reviewItems, hasLength(1));
    expect(
      result.reviewItems.single.reason,
      FinancialReviewReason.overdueReview,
    );
  });

  test('وصف السجل يميز خطتين تحملان الاسم نفسه', () {
    final personal = sub(
      id: 'personal',
      name: 'AlRajhi Mobile',
      price: 1565,
      planName: 'الحساب الشخصي',
    );
    final business = sub(
      id: 'business',
      name: 'AlRajhi Mobile',
      price: 1985,
      planName: 'حساب المنشأة',
    );

    expect(personal.displayQualifier, contains('الحساب الشخصي'));
    expect(business.displayQualifier, contains('حساب المنشأة'));
    expect(personal.displayQualifier, isNot(business.displayQualifier));
  });

  test('لا يقترح إلغاء خدمة أساسية منخفضة الاستخدام', () {
    final result = FinancialAssistant.analyze(
      [
        sub(
          id: 'essential',
          name: 'خدمة أساسية',
          price: 80,
          usageCount: 0,
          essential: true,
        ),
      ],
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
