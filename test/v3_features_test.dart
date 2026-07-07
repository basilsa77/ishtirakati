import 'package:flutter_test/flutter_test.dart';
import 'package:ishtirakati/models/subscription.dart';
import 'package:ishtirakati/services/remote_catalog.dart';

Subscription _sub({
  required BillingCycle cycle,
  required DateTime anchor,
  double price = 100,
  DateTime? trialEnd,
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
    trialEndDate: trialEnd,
  );
}

void main() {
  group('سجل الإنفاق الشهري', () {
    test('شهري من 15 يناير: دفعة واحدة في مارس ولا شيء قبل البداية', () {
      final s = _sub(
        cycle: BillingCycle.monthly,
        anchor: DateTime(2026, 1, 15),
        price: 50,
      );
      expect(s.paymentsInMonth(2026, 3), 1);
      expect(s.paymentsInMonth(2025, 12), 0);
    });

    test('أسبوعي: 4-5 دفعات في الشهر', () {
      final s = _sub(
        cycle: BillingCycle.weekly,
        anchor: DateTime(2026, 1, 1),
        price: 10,
      );
      final n = s.paymentsInMonth(2026, 3);
      expect(n >= 4 && n <= 5, isTrue);
    });

    test('سنوي: دفعة في شهر الذكرى فقط', () {
      final s = _sub(
        cycle: BillingCycle.yearly,
        anchor: DateTime(2024, 5, 10),
      );
      expect(s.paymentsInMonth(2026, 5), 1);
      expect(s.paymentsInMonth(2026, 6), 0);
    });
  });

  group('التجارب المجانية', () {
    test('تجربة نشطة حتى تاريخ الانتهاء وتنطفئ بعده', () {
      final s = _sub(
        cycle: BillingCycle.monthly,
        anchor: DateTime(2026, 7, 1),
        trialEnd: DateTime(2026, 7, 10),
      );
      expect(s.isTrialActive(DateTime(2026, 7, 7)), isTrue);
      expect(s.isTrialActive(DateTime(2026, 7, 10)), isTrue);
      expect(s.isTrialActive(DateTime(2026, 7, 11)), isFalse);
    });

    test('roundtrip JSON يحفظ التجربة والتذكير', () {
      final s = _sub(
        cycle: BillingCycle.monthly,
        anchor: DateTime(2026, 7, 1),
        trialEnd: DateTime(2026, 7, 14),
      )..reminderDays = 7;
      final back = Subscription.fromJson(s.toJson());
      expect(back.trialEndDate, DateTime(2026, 7, 14));
      expect(back.reminderDays, 7);
      final noTrial = _sub(
        cycle: BillingCycle.monthly,
        anchor: DateTime(2026, 7, 1),
      );
      expect(
        Subscription.fromJson(noTrial.toJson()).trialEndDate,
        isNull,
      );
    });
  });

  group('قاعدة الخدمات عن بُعد', () {
    test('يحلل JSON صالحًا', () {
      const raw = '{"version":1,"services":['
          '{"name":"Netflix","emoji":"🍿","category":"ترفيه ومشاهدة",'
          '"domain":"netflix.com","manageUrl":"https://netflix.com/account",'
          '"priceHint":55.99},'
          '{"name":"بدون سعر","emoji":"🔖","category":"أخرى",'
          '"domain":"","manageUrl":""}'
          ']}';
      final list = parseCatalog(raw);
      expect(list.length, 2);
      expect(list.first.name, 'Netflix');
      expect(list.first.priceHint, closeTo(55.99, 0.001));
      expect(list.last.priceHint, isNull);
    });

    test('JSON تالف يعيد قائمة فارغة بدل الانهيار', () {
      expect(parseCatalog('ليس json'), isEmpty);
      expect(parseCatalog('{"services": "غلط"}'), isEmpty);
    });
  });
}
