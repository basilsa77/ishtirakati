import 'package:flutter_test/flutter_test.dart';
import 'package:ishtirakati/models/subscription.dart';
import 'package:ishtirakati/services/email_import_service.dart';

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
  group('تقويم التجديدات', () {
    test('شهري من 31 يناير: يظهر في 28 فبراير و31 مارس', () {
      final s = _sub(
        cycle: BillingCycle.monthly,
        anchor: DateTime(2026, 1, 31),
      );
      expect(s.renewalsInMonth(2026, 2), [DateTime(2026, 2, 28)]);
      expect(s.renewalsInMonth(2026, 3), [DateTime(2026, 3, 31)]);
    });

    test('أسبوعي: 4-5 مرات في الشهر', () {
      final s = _sub(
        cycle: BillingCycle.weekly,
        anchor: DateTime(2026, 7, 1),
      );
      final n = s.renewalsInMonth(2026, 8).length;
      expect(n >= 4 && n <= 5, isTrue);
    });

    test('قبل بداية الاشتراك: لا تجديدات', () {
      final s = _sub(
        cycle: BillingCycle.monthly,
        anchor: DateTime(2026, 7, 15),
      );
      expect(s.renewalsInMonth(2026, 6), isEmpty);
    });
  });

  group('سجل الأسعار', () {
    test('roundtrip JSON يحفظ السجل ونسبة التغير صحيحة', () {
      final s = _sub(
        cycle: BillingCycle.monthly,
        anchor: DateTime(2026, 1, 1),
        price: 60,
      );
      s.priceHistory = [
        PriceChange(oldPrice: 50, changedAt: DateTime(2026, 3, 1)),
      ];
      final back = Subscription.fromJson(s.toJson());
      expect(back.priceHistory.length, 1);
      expect(back.priceHistory.first.oldPrice, closeTo(50, 0.001));
      expect(back.priceChangePercent, closeTo(20, 0.001));
    });
  });

  group('تصدير CSV', () {
    test('يبني رأسًا وصفًا لكل اشتراك مع تهريب الفواصل', () {
      final s = _sub(
        cycle: BillingCycle.monthly,
        anchor: DateTime(2026, 1, 1),
        price: 19.99,
      )..notes = 'ملاحظة، فيها فاصلة';
      final csv = buildCsv([s]);
      final lines = csv.trim().split('\n');
      expect(lines.length, 2);
      expect(lines.first.contains('الاسم'), isTrue);
      expect(lines[1].contains('19.99'), isTrue);
      expect(lines[1].contains('"ملاحظة، فيها فاصلة"'), isTrue);
    });
  });

  group('فلتر رسائل الفواتير', () {
    test('يميز الإيصالات من الرسائل العادية', () {
      expect(
        looksLikeBillingEmail('إيصالك من Apple', 'no_reply@email.apple.com'),
        isTrue,
      );
      expect(
        looksLikeBillingEmail('Your Netflix receipt', 'info@netflix.com'),
        isTrue,
      );
      expect(
        looksLikeBillingEmail('اجتماع الغد', 'friend@example.com'),
        isFalse,
      );
    });
  });

  group('الاشتراك العائلي', () {
    test('roundtrip JSON ونصيب الفرد', () {
      final s = _sub(
        cycle: BillingCycle.monthly,
        anchor: DateTime(2026, 1, 1),
        price: 60,
      )
        ..isFamily = true
        ..familyMembers = 4;
      expect(s.pricePerMember, closeTo(15, 0.001));
      final back = Subscription.fromJson(s.toJson());
      expect(back.isFamily, isTrue);
      expect(back.familyMembers, 4);
    });
  });
}
