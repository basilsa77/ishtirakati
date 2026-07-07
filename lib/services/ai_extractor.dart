/// استخراج الاشتراكات بالذكاء الاصطناعي (Google Gemini — الطبقة المجانية):
/// يرسل نص الرسائل/الإيصالات ويستقبل قائمة اشتراكات منظمة JSON
/// بكل خدمة وسعرها وعملتها ودورتها وتاريخ آخر خصم — حتى للخدمات غير المعروفة.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/subscription.dart';
import 'import_parser.dart';

/// نماذج نجربها بالترتيب (الأحدث أولًا، مع بدائل إن أُوقف نموذج).
const List<String> kGeminiModels = [
  'gemini-2.5-flash',
  'gemini-2.0-flash',
  'gemini-flash-latest',
];

const String _prompt = '''
أنت خبير مالي. حلل النص التالي (رسائل بنكية وإيصالات بريد) واستخرج كل
الاشتراكات الدورية المدفوعة. أعد النتيجة بصيغة JSON فقط — مصفوفة كائنات:
[{"name": "اسم الخدمة كما يعرفه الناس",
  "emoji": "إيموجي واحد مناسب",
  "category": "واحدة من: ترفيه ومشاهدة، موسيقى وبودكاست، إنتاجية وذكاء اصطناعي، ألعاب، رياضة وصحة، تعليم، تسوق وتوصيل، اتصالات وإنترنت، تخزين سحابي، أخرى",
  "price": 55.99,
  "currency": "SAR أو AED أو USD أو EUR أو KWD أو QAR أو BHD أو OMR",
  "cycle": "weekly أو monthly أو quarterly أو yearly",
  "lastChargeDate": "YYYY-MM-DD أو null"}]
قواعد: تجاهل المشتريات لمرة واحدة. لا تكرر الخدمة الواحدة (خذ أحدث خصم لها).
إن لم تجد اشتراكات أعد []. لا تكتب أي شيء خارج الـ JSON.

النص:
''';

class AiExtractionException implements Exception {
  final String message;

  const AiExtractionException(this.message);

  @override
  String toString() => message;
}

/// يحوّل ردّ الذكاء الاصطناعي (JSON) إلى مرشحين — دالة نقية قابلة للاختبار.
List<ImportCandidate> parseAiCandidates(String raw) {
  var s = raw.trim();
  // إزالة أسوار الكود إن وُجدت.
  if (s.startsWith('```')) {
    s = s.replaceAll(RegExp(r'^```[a-zA-Z]*'), '').replaceAll('```', '');
    s = s.trim();
  }
  final start = s.indexOf('[');
  final end = s.lastIndexOf(']');
  if (start < 0 || end <= start) return const [];
  s = s.substring(start, end + 1);

  dynamic data;
  try {
    data = jsonDecode(s);
  } catch (_) {
    return const [];
  }
  if (data is! List) return const [];

  const validCurrencies = {
    'SAR', 'AED', 'USD', 'EUR', 'KWD', 'QAR', 'BHD', 'OMR',
  };
  const validCategories = {
    'ترفيه ومشاهدة', 'موسيقى وبودكاست', 'إنتاجية وذكاء اصطناعي',
    'ألعاب', 'رياضة وصحة', 'تعليم', 'تسوق وتوصيل',
    'اتصالات وإنترنت', 'تخزين سحابي', 'أخرى',
  };

  final seen = <String>{};
  final out = <ImportCandidate>[];
  for (final e in data) {
    if (e is! Map<String, dynamic>) continue;
    final name = ((e['name'] as String?) ?? '').trim();
    if (name.isEmpty || seen.contains(name)) continue;
    seen.add(name);

    final currencyRaw =
        ((e['currency'] as String?) ?? '').trim().toUpperCase();
    final cycleRaw = ((e['cycle'] as String?) ?? 'monthly').toLowerCase();
    final cycle = switch (cycleRaw) {
      'weekly' => BillingCycle.weekly,
      'quarterly' => BillingCycle.quarterly,
      'yearly' => BillingCycle.yearly,
      _ => BillingCycle.monthly,
    };
    final categoryRaw = ((e['category'] as String?) ?? 'أخرى').trim();
    final price = (e['price'] as num?)?.toDouble();
    final anchor =
        DateTime.tryParse((e['lastChargeDate'] as String?) ?? '');

    out.add(ImportCandidate(
      name: name,
      emoji: ((e['emoji'] as String?) ?? '').trim().isEmpty
          ? '🔖'
          : (e['emoji'] as String).trim(),
      category:
          validCategories.contains(categoryRaw) ? categoryRaw : 'أخرى',
      price: (price != null && price > 0 && price < 100000) ? price : null,
      currency: validCurrencies.contains(currencyRaw) ? currencyRaw : '',
      cycle: cycle,
      anchor: anchor,
      sourceLine: 'استخراج بالذكاء الاصطناعي',
    ));
  }
  return out;
}

class AiExtractor {
  /// يستخرج الاشتراكات من نص حر عبر Gemini.
  /// يرمي [AiExtractionException] برسالة واضحة عند الفشل.
  static Future<List<ImportCandidate>> extract(
    String text,
    String apiKey,
  ) async {
    // نقتصر على حجم معقول حتى لا نتجاوز حدود الطلب.
    final clipped =
        text.length > 60000 ? text.substring(0, 60000) : text;

    Object? lastError;
    for (final model in kGeminiModels) {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
      );
      try {
        final res = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'contents': [
                  {
                    'parts': [
                      {'text': '$_prompt\n$clipped'},
                    ],
                  },
                ],
                'generationConfig': {
                  'temperature': 0,
                  'responseMimeType': 'application/json',
                },
              }),
            )
            .timeout(const Duration(seconds: 90));

        if (res.statusCode == 404) {
          // النموذج غير متاح — جرّب التالي.
          lastError = 'model $model not found';
          continue;
        }
        if (res.statusCode == 400 || res.statusCode == 403) {
          throw const AiExtractionException(
            'مفتاح API غير صالح — تأكد من نسخه كاملًا من aistudio.google.com',
          );
        }
        if (res.statusCode == 429) {
          throw const AiExtractionException(
            'تجاوزت حد الاستخدام المجاني مؤقتًا — انتظر دقيقة وأعد المحاولة',
          );
        }
        if (res.statusCode != 200) {
          lastError = 'HTTP ${res.statusCode}';
          continue;
        }

        final body = jsonDecode(utf8.decode(res.bodyBytes));
        final candidates = body['candidates'];
        if (candidates is! List || candidates.isEmpty) return const [];
        final parts = candidates[0]?['content']?['parts'];
        if (parts is! List || parts.isEmpty) return const [];
        final answer = (parts[0]?['text'] as String?) ?? '';
        return parseAiCandidates(answer);
      } on AiExtractionException {
        rethrow;
      } catch (e) {
        lastError = e;
        continue;
      }
    }
    throw AiExtractionException('تعذر الاتصال بالذكاء الاصطناعي: $lastError');
  }
}
