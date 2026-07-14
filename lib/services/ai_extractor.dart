/// استخراج الاشتراكات بالذكاء الاصطناعي (Google Gemini — الطبقة المجانية):
/// يرسل نص الرسائل/الإيصالات ويستقبل قائمة اشتراكات منظمة JSON
/// بكل خدمة وسعرها وعملتها ودورتها وتاريخ آخر خصم — حتى للخدمات غير المعروفة.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/subscription.dart';
import '../data/presets.dart';
import '../l10n/app_localizations.dart';
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
  "category": "واحدة من: ترفيه ومشاهدة، موسيقى وبودكاست، إنتاجية وذكاء اصطناعي، ألعاب، رياضة وصحة، تعليم، تسوق وتوصيل، اتصالات وإنترنت، تخزين سحابي، مالية وفواتير، أخبار ومجلات، أخرى",
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

/// يقرأ النص من استجابة Gemini دون افتراض بنية ديناميكية غير آمنة.
String extractGeminiResponseText(dynamic body) {
  if (body is! Map) return '';
  final candidates = body['candidates'];
  if (candidates is! List || candidates.isEmpty) return '';
  final first = candidates.first;
  if (first is! Map) return '';
  final content = first['content'];
  if (content is! Map) return '';
  final parts = content['parts'];
  if (parts is! List || parts.isEmpty) return '';
  final part = parts.first;
  return part is Map ? (part['text'] as String? ?? '') : '';
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
    'مالية وفواتير', 'أخبار ومجلات',
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
      sourceLine: tr('aiExtractionSource'),
    ));
  }
  return out;
}

/// مزودات الذكاء الاصطناعي المدعومة — يختار المستخدم مزوده ومفتاحه الخاص.
class AiProviderInfo {
  final String id;
  final String label;
  final String keyUrl;
  final String base; // فارغ = Gemini
  final String model;
  final String hint;

  const AiProviderInfo({
    required this.id,
    required this.label,
    required this.keyUrl,
    required this.base,
    required this.model,
    required this.hint,
  });
}

extension LocalizedAiProviderInfo on AiProviderInfo {
  String get localizedLabel => tr(switch (id) {
        'gemini' => 'aiProviderGemini',
        'groq' => 'aiProviderGroq',
        _ => label,
      });
}

const List<AiProviderInfo> kAiProviders = [
  AiProviderInfo(
    id: 'gemini',
    label: 'Google Gemini — مجاني',
    keyUrl: 'https://aistudio.google.com/apikey',
    base: '',
    model: '',
    hint: 'AIza...',
  ),
  AiProviderInfo(
    id: 'groq',
    label: 'Groq — مجاني وسريع',
    keyUrl: 'https://console.groq.com/keys',
    base: 'https://api.groq.com/openai/v1',
    model: 'llama-3.3-70b-versatile',
    hint: 'gsk_...',
  ),
  AiProviderInfo(
    id: 'openai',
    label: 'OpenAI (ChatGPT)',
    keyUrl: 'https://platform.openai.com/api-keys',
    base: 'https://api.openai.com/v1',
    model: 'gpt-4o-mini',
    hint: 'sk-...',
  ),
  AiProviderInfo(
    id: 'deepseek',
    label: 'DeepSeek',
    keyUrl: 'https://platform.deepseek.com/api_keys',
    base: 'https://api.deepseek.com/v1',
    model: 'deepseek-chat',
    hint: 'sk-...',
  ),
];

AiProviderInfo aiProviderById(String id) => kAiProviders.firstWhere(
      (p) => p.id == id,
      orElse: () => kAiProviders.first,
    );

/// طلب توليد نص موحّد يعمل مع Gemini وكل المزودات المتوافقة مع OpenAI.
Future<String> aiGenerateText(
  String prompt,
  String apiKey, {
  String providerId = 'gemini',
  double temperature = 0,
  bool jsonOutput = false,
  Duration timeout = const Duration(seconds: 90),
}) async {
  final provider = aiProviderById(providerId);

  if (provider.base.isEmpty) {
    // Gemini
    Object? lastError;
    for (final model in kGeminiModels) {
      try {
        final res = await http
            .post(
              Uri.parse(
                'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
              ),
              headers: {
                'Content-Type': 'application/json',
                'x-goog-api-key': apiKey,
              },
              body: jsonEncode({
                'contents': [
                  {
                    'parts': [
                      {'text': prompt},
                    ],
                  },
                ],
                'generationConfig': {
                  'temperature': temperature,
                  if (jsonOutput) 'responseMimeType': 'application/json',
                },
              }),
            )
            .timeout(timeout);
        if (res.statusCode == 404) {
          lastError = 'model $model not found';
          continue;
        }
        if (res.statusCode == 400 || res.statusCode == 403) {
          throw AiExtractionException(tr('aiInvalidKey'));
        }
        if (res.statusCode == 429) {
          throw AiExtractionException(tr('aiRateLimited'));
        }
        if (res.statusCode != 200) {
          lastError = 'HTTP ${res.statusCode}';
          continue;
        }
        return extractGeminiResponseText(
          jsonDecode(utf8.decode(res.bodyBytes)),
        );
      } on AiExtractionException {
        rethrow;
      } catch (e) {
        lastError = e;
      }
    }
    throw AiExtractionException(
      tr('aiConnectionFailed', {'error': lastError}),
    );
  }

  // مزودات متوافقة مع OpenAI (Groq / OpenAI / DeepSeek)
  try {
    final res = await http
        .post(
          Uri.parse('${provider.base}/chat/completions'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            'model': provider.model,
            'temperature': temperature,
            if (jsonOutput)
              'response_format': {'type': 'json_object'},
            'messages': [
              {'role': 'user', 'content': prompt},
            ],
          }),
        )
        .timeout(timeout);
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw AiExtractionException(
        tr('aiProviderKeyInvalid', {'provider': provider.localizedLabel}),
      );
    }
    if (res.statusCode == 429) {
      throw AiExtractionException(tr('aiRateLimited'));
    }
    if (res.statusCode != 200) {
      throw AiExtractionException(
        tr('aiHttpFailed', {'code': res.statusCode}),
      );
    }
    return extractOpenAiResponseText(
      jsonDecode(utf8.decode(res.bodyBytes)),
    );
  } on AiExtractionException {
    rethrow;
  } catch (e) {
    throw AiExtractionException(tr('aiConnectionFailed', {'error': e}));
  }
}

/// يقرأ نص استجابة المزودات المتوافقة مع OpenAI بفحص أنواع صارم.
String extractOpenAiResponseText(dynamic body) {
  if (body is! Map) return '';
  final choices = body['choices'];
  if (choices is! List || choices.isEmpty) return '';
  final first = choices.first;
  if (first is! Map) return '';
  final message = first['message'];
  if (message is! Map) return '';
  return (message['content'] as String?) ?? '';
}

class AiExtractor {
  /// يستخرج الاشتراكات من نص حر عبر Gemini.
  /// يرمي [AiExtractionException] برسالة واضحة عند الفشل.
  static Future<List<ImportCandidate>> extract(
    String text,
    String apiKey, {
    String providerId = 'gemini',
  }) async {
    // نقتصر على حجم معقول حتى لا نتجاوز حدود الطلب.
    final clipped =
        text.length > 60000 ? text.substring(0, 60000) : text;
    final answer = await aiGenerateText(
      '$_prompt\n$clipped',
      apiKey,
      providerId: providerId,
      jsonOutput: true,
    );
    if (answer.isEmpty) return const [];
    return parseAiCandidates(answer);
  }

  /// يصنف أسماء خدمات موجودة مسبقًا دون إرسال الأسعار أو البيانات المالية.
  static Future<Map<String, String>> classifyNames(
    List<String> names,
    String apiKey, {
    String providerId = 'gemini',
  }) async {
    if (names.isEmpty) return const {};
    final prompt = '''
صنف أسماء الخدمات التالية إلى تصنيف واحد فقط من القائمة:
${kCategories.join('، ')}
أعد JSON object فقط، بحيث يكون المفتاح اسم الخدمة والقيمة التصنيف.
لا تستخدم «أخرى» إلا إذا كان الاسم غير قابل للتعرف عليه.
الأسماء:
${names.join('\n')}
''';
    final answer = await aiGenerateText(
      prompt,
      apiKey,
      providerId: providerId,
      jsonOutput: true,
      timeout: const Duration(seconds: 45),
    );
    return parseAiCategories(answer);
  }
}

Map<String, String> parseAiCategories(String raw) {
  var value = raw.trim();
  if (value.startsWith('```')) {
    value = value
        .replaceAll(RegExp(r'^```[a-zA-Z]*'), '')
        .replaceAll('```', '')
        .trim();
  }
  final start = value.indexOf('{');
  final end = value.lastIndexOf('}');
  if (start < 0 || end <= start) return const {};
  try {
    final data = jsonDecode(value.substring(start, end + 1));
    if (data is! Map<String, dynamic>) return const {};
    return {
      for (final entry in data.entries)
        if (entry.key.trim().isNotEmpty &&
            entry.value is String &&
            kCategories.contains(entry.value))
          entry.key.trim(): entry.value as String,
    };
  } catch (_) {
    return const {};
  }
}
