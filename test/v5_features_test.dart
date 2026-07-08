import 'package:flutter_test/flutter_test.dart';
import 'package:ishtirakati/models/subscription.dart';
import 'package:ishtirakati/services/itunes_search.dart';
import 'package:ishtirakati/services/update_checker.dart';

void main() {
  group('فاحص التحديثات', () {
    test('يستخرج النسخة من pubspec', () {
      const content = 'name: ishtirakati\nversion: 5.1.0+8\nenvironment:';
      expect(extractVersion(content), '5.1.0');
      expect(extractVersion('لا نسخة هنا'), isNull);
    });

    test('مقارنة النسخ صحيحة', () {
      expect(isNewerVersion('5.2.0', '5.1.0'), isTrue);
      expect(isNewerVersion('6.0.0', '5.9.9'), isTrue);
      expect(isNewerVersion('5.1.0', '5.1.0'), isFalse);
      expect(isNewerVersion('5.0.9', '5.1.0'), isFalse);
    });
  });

  group('بحث iTunes', () {
    test('يحلل نتائج صالحة ويتجاهل المكرر', () {
      const raw = '{"resultCount":2,"results":['
          '{"trackName":"Netflix","artworkUrl100":"https://a/icon.png",'
          '"sellerName":"Netflix, Inc."},'
          '{"trackName":"Netflix","artworkUrl100":"https://b/icon2.png"}]}';
      final r = parseItunesResults(raw);
      expect(r.length, 1);
      expect(r.first.name, 'Netflix');
      expect(r.first.iconUrl, 'https://a/icon.png');
      expect(r.first.seller, 'Netflix, Inc.');
    });

    test('رد تالف يعيد قائمة فارغة', () {
      expect(parseItunesResults('غير صالح'), isEmpty);
      expect(parseItunesResults('{"results": 5}'), isEmpty);
    });
  });

  group('شعار مخصص', () {
    test('iconUrl يُحفظ ويُسترجع', () {
      final s = Subscription(
        id: 'x',
        name: 'تطبيق',
        emoji: '🔖',
        price: 10,
        currency: 'SAR',
        cycle: BillingCycle.monthly,
        anchorDate: DateTime(2026, 1, 1),
        category: 'أخرى',
        iconUrl: 'https://a/icon.png',
      );
      expect(
        Subscription.fromJson(s.toJson()).iconUrl,
        'https://a/icon.png',
      );
    });
  });
}
