/// مستشار الاشتراكات الذكي: يرسل ملخص اشتراكاتك إلى Gemini
/// ويعيد تحليلًا عربيًا عمليًا — فرص توفير، تكرارات، ومقارنات أسعار.
library;

import '../l10n/app_localizations.dart';
import '../models/subscription.dart';
import 'ai_extractor.dart' show AiExtractionException, aiGenerateText;

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

const String _advisorPromptEn = '''
You are a concise financial advisor specializing in digital subscriptions.
Analyze the user's subscriptions and return 3-6 practical bullet points in English:
1. Clear savings opportunities from overlapping services.
2. Plans that appear expensive or may have a cheaper alternative.
3. Cases where switching from monthly to yearly billing may usually save money.
4. Useful observations about expiring trials or forgotten paused subscriptions.
Start each line with "-". Do not add an introduction or conclusion, and do not
invent exact competitor prices.

User subscriptions:
''';

class AiAdvisor {
  /// يعيد نص النصائح، أو يرمي [AiExtractionException] برسالة واضحة.
  static Future<String> advise(
    List<Subscription> subs,
    String apiKey, {
    String providerId = 'gemini',
  }) async {
    final summary = buildAdvisorSummary(subs);
    final prompt = isEnglishLocale ? _advisorPromptEn : _advisorPrompt;
    final answer =
        (await aiGenerateText(
          '$prompt\n$summary',
          apiKey,
          providerId: providerId,
          temperature: 0.4,
          timeout: const Duration(seconds: 60),
        )).trim();
    return answer.isEmpty ? tr('aiNoAnalysis') : answer;
  }
}
