import 'package:flutter_test/flutter_test.dart';
import 'package:ishtirakati/models/subscription.dart';

Subscription _sub({
  required BillingCycle cycle,
  required DateTime anchor,
  double price = 100,
}) {
  return Subscription(
    id: 't1',
    name: 'اختبار',
    emoji: '🧪',
    price: price,
    currency: 'SAR',
    cycle: cycle,
    anchorDate: anchor,
    category: 'أخرى',
  );
}

void main() {
  group('حسابات التكلفة', () {
    test('السنوي 120 يعادل 10 شهريًا', () {
      final s = _sub(
        cycle: BillingCycle.yearly,
        anchor: DateTime(2026, 1, 1),
        price: 120,
      );
      expect(s.monthlyCost, closeTo(10, 0.001));
      expect(s.yearlyCost, closeTo(120, 0.001));
    });

    test('الأسبوعي 10 يعادل ~43.33 شهريًا', () {
      final s = _sub(
        cycle: BillingCycle.weekly,
        anchor: DateTime(2026, 1, 1),
        price: 10,
      );
      expect(s.monthlyCost, closeTo(10 * 52 / 12, 0.001));
    });
  });

  group('موعد التجديد القادم', () {
    test('اشتراك شهري بدأ 31 يناير يتجدد 28 فبراير ثم 31 مارس', () {
      final s = _sub(
        cycle: BillingCycle.monthly,
        anchor: DateTime(2026, 1, 31),
      );
      expect(
        s.nextRenewal(DateTime(2026, 2, 10)),
        DateTime(2026, 2, 28),
      );
      expect(
        s.nextRenewal(DateTime(2026, 3, 1)),
        DateTime(2026, 3, 31),
      );
    });

    test('التجديد اليوم يُحسب اليوم وليس الدورة القادمة', () {
      final s = _sub(
        cycle: BillingCycle.monthly,
        anchor: DateTime(2026, 1, 15),
      );
      expect(
        s.nextRenewal(DateTime(2026, 3, 15)),
        DateTime(2026, 3, 15),
      );
      expect(s.daysUntilRenewal(DateTime(2026, 3, 15)), 0);
    });

    test('تاريخ بداية في المستقبل يُعاد كما هو', () {
      final s = _sub(
        cycle: BillingCycle.monthly,
        anchor: DateTime(2027, 5, 1),
      );
      expect(
        s.nextRenewal(DateTime(2026, 7, 7)),
        DateTime(2027, 5, 1),
      );
    });

    test('أسبوعي: يقفز بمضاعفات ٧ أيام من نقطة البداية', () {
      final s = _sub(
        cycle: BillingCycle.weekly,
        anchor: DateTime(2026, 7, 1), // الأربعاء
      );
      expect(
        s.nextRenewal(DateTime(2026, 7, 7)),
        DateTime(2026, 7, 8),
      );
    });

    test('سنوي: من 2024-02-29 إلى 2025-02-28', () {
      final s = _sub(
        cycle: BillingCycle.yearly,
        anchor: DateTime(2024, 2, 29),
      );
      expect(
        s.nextRenewal(DateTime(2024, 6, 1)),
        DateTime(2025, 2, 28),
      );
    });
  });

  group('الترميز والاسترجاع JSON', () {
    test('roundtrip يحافظ على كل الحقول', () {
      final s = Subscription(
        id: 'abc',
        name: 'شاهد VIP',
        emoji: '🎬',
        price: 24.99,
        currency: 'SAR',
        cycle: BillingCycle.quarterly,
        anchorDate: DateTime(2026, 3, 10),
        category: 'ترفيه ومشاهدة',
        notes: 'حساب العائلة',
        isPaused: true,
      );
      final back = Subscription.fromJson(s.toJson());
      expect(back.id, s.id);
      expect(back.name, s.name);
      expect(back.emoji, s.emoji);
      expect(back.price, s.price);
      expect(back.currency, s.currency);
      expect(back.cycle, s.cycle);
      expect(back.anchorDate, s.anchorDate);
      expect(back.category, s.category);
      expect(back.notes, s.notes);
      expect(back.isPaused, s.isPaused);
    });

    test('إحصائية الاستخدام وتكلفة الاستخدام تحفظان في JSON', () {
      final s = _sub(
        cycle: BillingCycle.monthly,
        anchor: DateTime(2026, 1, 1),
        price: 30,
      )..usageCount = 3;
      final back = Subscription.fromJson(s.toJson());
      expect(back.usageCount, 3);
      expect(back.costPerUse, closeTo(10, 0.001));
    });
  });

  group('تنسيق المبالغ', () {
    test('يحذف الكسور الصفرية ويعرض المبلغ فقط', () {
      expect(fmtMoney(25.0, 'SAR'), '25');
      expect(fmtMoney(24.99, 'SAR'), '24.99');
    });
  });

  group('إجمالي المدفوع منذ البداية', () {
    test('شهري: 3 دفعات بين 15 يناير و20 مارس', () {
      final s = _sub(
        cycle: BillingCycle.monthly,
        anchor: DateTime(2026, 1, 15),
        price: 50,
      );
      expect(s.paymentsMade(DateTime(2026, 3, 20)), 3);
      expect(s.totalSpent(DateTime(2026, 3, 20)), closeTo(150, 0.001));
    });

    test('أسبوعي: دفعة واحدة قبل مرور أسبوع', () {
      final s = _sub(
        cycle: BillingCycle.weekly,
        anchor: DateTime(2026, 7, 1),
        price: 10,
      );
      expect(s.paymentsMade(DateTime(2026, 7, 7)), 1);
    });

    test('بداية مستقبلية: صفر دفعات', () {
      final s = _sub(
        cycle: BillingCycle.yearly,
        anchor: DateTime(2027, 1, 1),
      );
      expect(s.paymentsMade(DateTime(2026, 7, 7)), 0);
      expect(s.totalSpent(DateTime(2026, 7, 7)), 0);
    });
  });
}
