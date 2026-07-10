/// مستشار الاشتراكات الذكي: يرسل ملخص اشتراكاتك إلى Gemini
/// ويعيد تحليلًا عربيًا عمليًا — فرص توفير، تكرارات، ومقارنات أسعار.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/subscription.dart';
import 'ai_extractor.dart'
    show kGeminiModels, AiExtractionException, extractGeminiResponseText;

/// يبني ملخص الاشتراكات المُرسل للنموذج — دالة نقية قابلة للاختبار.
String buildAdvisorSummary(List<Subscription> subs) {
  final b = StringBuffer();
  for (final s in subs) {
    b.writeln(
      '- ${s.name} | ${s.category} | ${s.price.toStringAsFixed(2)} ${s.currency} '
      '${s.cycle.labelAr}${s.isPaused ? ' | موقوف' : ''}'
      '${s.isFamily ? ' | عائلي (${s.familyMembers} أفراد)' : ''}'
      '${s.isTrialActive() ? ' | تجربة مجانية' : ''}',
    );
  }
  return b.toString();
}

const String _advisorPrompt = '''
أنت مستشار مالي سعودي ودود متخصص في الاشتراكات الرقمية.
حلل قائمة اشتراكات المستخدم التالية وقدم نصائح عملية مختصرة بالعربية:
1. فرص التوفير الواضحة (خدمات متشابهة أو متداخلة يمكن الاستغناء عن إحداها).
2. اشتراكات يبدو سعرها أعلى من المعتاد أو يوجد لها بديل أرخص.
3. اقتراح التحول من شهري لسنوي إن كان يوفر عادة.
4. أي ملاحظة ذكية أخرى (تجارب مجانية على وشك التحول، اشتراكات موقوفة منسية).
اكتب 3-6 نقاط قصيرة فقط، كل نقطة في سطر يبدأ بشرطة "-". بدون مقدمات أو خاتمة.
لا تختلق أسعارًا دقيقة لمنافسين — قل "عادة" أو "قد".

اشتراكات المستخدم:
''';

class AiAdvisor {
  /// يعيد نص النصائح، أو يرمي [AiExtractionException] برسالة واضحة.
  static Future<String> advise(
    List<Subscription> subs,
    String apiKey,
  ) async {
    final summary = buildAdvisorSummary(subs);
    Object? lastError;
    for (final model in kGeminiModels) {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
      );
      try {
        final res = await http
            .post(
              uri,
              headers: {
                'Content-Type': 'application/json',
                'x-goog-api-key': apiKey,
              },
              body: jsonEncode({
                'contents': [
                  {
                    'parts': [
                      {'text': '$_advisorPrompt\n$summary'},
                    ],
                  },
                ],
                'generationConfig': {'temperature': 0.4},
              }),
            )
            .timeout(const Duration(seconds: 60));

        if (res.statusCode == 404) {
          lastError = 'model $model not found';
          continue;
        }
        if (res.statusCode == 400 || res.statusCode == 403) {
          throw const AiExtractionException(
            'مفتاح API غير صالح — راجعه في الإعدادات',
          );
        }
        if (res.statusCode == 429) {
          throw const AiExtractionException(
            'تجاوزت الحد المجاني مؤقتًا — انتظر دقيقة',
          );
        }
        if (res.statusCode != 200) {
          lastError = 'HTTP ${res.statusCode}';
          continue;
        }
        final body = jsonDecode(utf8.decode(res.bodyBytes));
        final answer = extractGeminiResponseText(body).trim();
        return answer.isEmpty ? 'لم يصلنا تحليل — أعد المحاولة.' : answer;
      } on AiExtractionException {
        rethrow;
      } catch (e) {
        lastError = e;
        continue;
      }
    }
    throw AiExtractionException('تعذر الاتصال: $lastError');
  }
}
