/// موافقة محددة بالمزود قبل إرسال البيانات المالية إلى مستشار AI.
library;

import 'package:shared_preferences/shared_preferences.dart';

class AiConsentService {
  const AiConsentService._();

  static const consentVersion = 1;
  static const advisorFieldsAr =
      'اسم الخدمة، التصنيف، السعر، العملة، دورة الدفع، وحالة التجربة أو المشاركة العائلية';

  static String preferenceKey(String providerId) =>
      'ishtirakati_ai_advisor_consent_v${consentVersion}_$providerId';

  static Future<bool> hasAdvisorConsent(String providerId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(preferenceKey(providerId)) ?? false;
  }

  static Future<void> rememberAdvisorConsent(String providerId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(preferenceKey(providerId), true);
  }

  static Future<void> revokeAdvisorConsent(String providerId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(preferenceKey(providerId));
  }
}
