import 'package:flutter_test/flutter_test.dart';
import 'package:ishtirakati/models/subscription.dart';
import 'package:ishtirakati/services/ai_extractor.dart';

void main() {
  test('يقرأ نص Gemini بأمان من استجابة صالحة أو تالفة', () {
    expect(
      extractGeminiResponseText({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': '[]'},
              ],
            },
          },
        ],
      }),
      '[]',
    );
    expect(extractGeminiResponseText({'candidates': []}), isEmpty);
    expect(extractGeminiResponseText('غير صالح'), isEmpty);
  });

  test('يقبل تصنيفات AI الجديدة ويرفض التصنيف غير المعروف', () {
    final result = parseAiCategories(
      '{"NordVPN":"اتصالات وإنترنت","X Premium":"أخبار ومجلات",'
      '"Unknown":"تصنيف غير موجود"}',
    );
    expect(result['NordVPN'], 'اتصالات وإنترنت');
    expect(result['X Premium'], 'أخبار ومجلات');
    expect(result.containsKey('Unknown'), isFalse);
  });
  group('تحليل رد الذكاء الاصطناعي', () {
    test('JSON نظيف مع كل الحقول', () {
      const raw = '''
[{"name":"Netflix","emoji":"🍿","category":"ترفيه ومشاهدة",
  "price":55.99,"currency":"SAR","cycle":"monthly",
  "lastChargeDate":"2026-06-15"},
 {"name":"خدمة غريبة","emoji":"","category":"تصنيف غير معروف",
  "price":-5,"currency":"XYZ","cycle":"yearly","lastChargeDate":null}]
''';
      final r = parseAiCandidates(raw);
      expect(r.length, 2);
      expect(r.first.name, 'Netflix');
      expect(r.first.price, closeTo(55.99, 0.001));
      expect(r.first.currency, 'SAR');
      expect(r.first.cycle, BillingCycle.monthly);
      expect(r.first.anchor, DateTime(2026, 6, 15));
      // الحقول غير الصالحة تُطبَّع بأمان
      expect(r.last.emoji, '🔖');
      expect(r.last.category, 'أخرى');
      expect(r.last.price, isNull);
      expect(r.last.currency, '');
      expect(r.last.cycle, BillingCycle.yearly);
    });

    test('JSON داخل أسوار كود ونص زائد', () {
      const raw = 'إليك النتيجة:\n```json\n'
          '[{"name":"Spotify","category":"موسيقى وبودكاست",'
          '"price":21.99,"currency":"SAR","cycle":"monthly"}]\n'
          '```\nانتهى.';
      final r = parseAiCandidates(raw);
      expect(r.length, 1);
      expect(r.first.name, 'Spotify');
    });

    test('رد تالف أو فارغ يعيد قائمة فارغة', () {
      expect(parseAiCandidates('لم أجد شيئًا'), isEmpty);
      expect(parseAiCandidates('[]'), isEmpty);
      expect(parseAiCandidates('{"غلط": true}'), isEmpty);
    });

    test('لا يكرر الخدمة الواحدة', () {
      const raw = '[{"name":"Netflix","cycle":"monthly"},'
          '{"name":"Netflix","cycle":"yearly"}]';
      expect(parseAiCandidates(raw).length, 1);
    });
  });
}
