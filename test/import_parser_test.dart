import 'package:flutter_test/flutter_test.dart';
import 'package:ishtirakati/models/subscription.dart';
import 'package:ishtirakati/services/import_parser.dart';

void main() {
  test('يقرأ المبلغ ذي فاصل الآلاف دون تحويله إلى مبلغ أصغر', () {
    final result = parseSubscriptionsText('Netflix 1,299.00 SAR شهري');
    expect(result.single.price, 1299);
    expect(result.single.currency, 'SAR');
  });

  test('يتجاهل التاريخ غير الموجود في التقويم', () {
    final result = parseSubscriptionsText('Netflix 59 SAR\nالتاريخ: 2026-02-31');
    expect(result.single.anchor, isNull);
  });

  group('الاستيراد الذكي', () {
    test('رسالة بنك سعودية: نتفلكس بالريال مع التاريخ', () {
      const sms = 'شراء إنترنت\n'
          'بطاقة: مدى 1234*\n'
          'من: NETFLIX.COM\n'
          'مبلغ: 55.99 ر.س\n'
          'في: 2026-06-15';
      final r = parseSubscriptionsText(sms);
      expect(r.length, 1);
      expect(r.first.name, 'Netflix');
      expect(r.first.price, closeTo(55.99, 0.001));
      expect(r.first.currency, 'SAR');
      expect(r.first.anchor, DateTime(2026, 6, 15));
    });

    test('إيصال Apple بأرقام عربية', () {
      const receipt = 'إيصالك من Apple\n'
          'iCloud+ ٥٠ جيجا — ١٣.٩٩ ر.س شهريًا';
      final r = parseSubscriptionsText(receipt);
      final icloud = r.firstWhere((c) => c.name == 'iCloud+');
      expect(icloud.price, closeTo(13.99, 0.001));
      expect(icloud.cycle, BillingCycle.monthly);
    });

    test('اشتراك سنوي يُكتشف كدورة سنوية', () {
      const text = 'Duolingo Super خطة سنوية 219 ر.س';
      final r = parseSubscriptionsText(text);
      expect(r.length, 1);
      expect(r.first.cycle, BillingCycle.yearly);
      expect(r.first.price, closeTo(219, 0.001));
    });

    test('عدة خدمات في نص واحد بدون تكرار', () {
      const text = 'spotify 21.99 SAR\n'
          'netflix 55.99 SAR\n'
          'NETFLIX.COM مرة أخرى 55.99';
      final r = parseSubscriptionsText(text);
      expect(r.length, 2);
    });

    test('نص بلا اشتراكات يعيد قائمة فارغة', () {
      const text = 'مرحبا كيف حالك؟ موعدنا غدا الساعة 5';
      final r = parseSubscriptionsText(text);
      expect(r, isEmpty);
    });
  });
}
