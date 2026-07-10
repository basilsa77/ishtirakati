/// مستشار الاشتراكات الذكي: يرسل ملخص اشتراكاتك إلى Gemini
/// ويعيد تحليلًا عربيًا عمليًا — فرص توفير، تكرارات، ومقارنات أسعار.
library;



import '../models/subscription.dart';
import 'ai_extractor.dart'
    show AiExtractionException, aiGenerateText;

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
    String apiKey, {
    String providerId = 'gemini',
  }) async {
    final summary = buildAdvisorSummary(subs);
    final answer = (await aiGenerateText(
      '$_advisorPrompt\n$summary',
      apiKey,
      providerId: providerId,
      temperature: 0.4,
      timeout: const Duration(seconds: 60),
    ))
        .trim();
    return answer.isEmpty ? 'لم يصلنا تحليل — أعد المحاولة.' : answer;
  }
}
