import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart' show initializeDateFormatting;
import 'package:intl/intl.dart' show DateFormat, Intl, NumberFormat;

import 'app_messages_ar.dart';

class AppLocalizations {
  AppLocalizations._(this.locale, this._messages);

  final Locale locale;
  final Map<String, String> _messages;
  static final Set<String> _initializedDateLocales = <String>{};

  static const supportedLocales = <Locale>[Locale('ar'), Locale('en')];
  static final _fallback = AppLocalizations._(
    const Locale('ar'),
    <String, String>{
      ...appMessagesAr,
      'appTitle': 'اشتراكاتي',
      'language': 'اللغة',
      'languageDescription': 'اختر لغة التطبيق أو اتبع لغة iPhone.',
      'languageSystem': 'حسب النظام',
      'languageArabic': 'العربية',
      'languageEnglish': 'English',
      'settingsAppearance': 'المظهر',
      'settingsAppearanceTitle': 'مظهر التطبيق',
      'settingsAppearanceDescription':
          'اختر المظهر المناسب؛ الوضع التلقائي يتبع iPhone.',
      'themeSystem': 'حسب النظام',
      'themeDark': 'داكن',
      'themeLight': 'فاتح',
      'currencySar': 'ر.س',
      'navHome': 'الرئيسية',
      'navSubscriptions': 'اشتراكاتي',
      'navSubscriptionsLibrary': 'مكتبة الاشتراكات',
      'navInsights': 'التحليلات',
      'navRenewals': 'التجديدات',
      'navRenewalsSchedule': 'جدول التجديدات',
      'navSettings': 'الإعدادات',
      'searchAndCommands': 'بحث وأوامر',
      'commonToday': 'اليوم',
      'commonTomorrow': 'غدًا',
      'daysAfter': 'بعد {days} يوم',
      'daysAfterTwo': 'بعد يومين',
      'daysAfterFew': 'بعد {days} أيام',
      'daysAfterMany': 'بعد {days} يومًا',
      'syncCompleted': 'اكتملت المزامنة',
      'lastCharge': 'آخر خصم {date}',
      'paymentSubscription': 'اشتراك',
      'paymentInstallment': 'قسط',
      'paymentBill': 'فاتورة',
      'cycleWeekly': 'أسبوعي',
      'cycleMonthly': 'شهري',
      'cycleQuarterly': 'كل 3 أشهر',
      'cycleYearly': 'سنوي',
      'categoryEntertainment': 'ترفيه ومشاهدة',
      'categoryMusic': 'موسيقى وبودكاست',
      'categoryProductivity': 'إنتاجية وذكاء اصطناعي',
      'categoryGames': 'ألعاب',
      'categoryHealth': 'رياضة وصحة',
      'categoryEducation': 'تعليم',
      'categoryShopping': 'تسوق وتوصيل',
      'categoryTelecom': 'اتصالات وإنترنت',
      'categoryCloud': 'تخزين سحابي',
      'categoryFinance': 'مالية وفواتير',
      'categoryNews': 'أخبار ومجلات',
      'categoryOther': 'أخرى',
      'advisorFields':
          'اسم الخدمة، التصنيف، السعر، العملة، دورة الدفع، وحالة التجربة أو المشاركة العائلية',
      'greetingMorning': 'صباح الخير',
      'greetingEvening': 'مساء الخير',
      'cloudPermissionDenied':
          'رفضت Firebase المزامنة. تحقق من App Check ونشر قواعد Firestore.',
      'cloudUnauthenticated':
          'انتهت جلسة الحساب. سجّل الدخول مجددًا ثم أعد المحاولة.',
      'cloudResourceNotFound':
          'تعذر الوصول إلى مورد Firebase المطلوب. حدّث التطبيق ثم أعد المحاولة.',
      'cloudFirestoreDatabaseNotFound':
          'قاعدة بيانات Firestore الافتراضية غير متاحة لهذا المشروع. تحقق من إعداد Firebase ثم أعد المحاولة.',
      'cloudFirestoreResourceNotFound':
          'تعذر العثور على مورد Firestore المطلوب. تحقق من إعداد المشروع ثم أعد المحاولة.',
      'cloudSyncDocumentNotFound':
          'لا توجد نسخة سحابية لهذا الحساب بعد. أعد المزامنة لإنشاء النسخة الأولى.',
      'cloudFirstCreateSuccess':
          'تم إنشاء النسخة السحابية ومزامنتها بنجاح',
      'cloudUpdateSuccess': 'تم تحديث النسخة السحابية بنجاح',
      'cloudSyncDiagnostic':
          'العملية: {operation} | الخطأ: {code} | المستند موجود: {exists} | المراجعة: {revision} | البناء: {commit}',
      'appBuildNumber': 'رقم البناء',
      'appCommit': 'نسخة الكود',
      'firestoreDiagnosticButton': 'اختبار اتصال Firestore',
      'firestoreDiagnosticRunning': 'جارٍ اختبار الاتصال...',
      'firestoreDiagnosticRestTitle': 'اختبار Firestore REST',
      'firestoreDiagnosticNativeTitle': 'اختبار Firestore Native',
      'firestoreDiagnosticHttpStatus': 'حالة HTTP',
      'firestoreDiagnosticDns': 'نجاح DNS',
      'firestoreDiagnosticHttps': 'نجاح اتصال HTTPS',
      'firestoreDiagnosticDuration': 'المدة',
      'firestoreDiagnosticResult': 'النتيجة',
      'firestoreDiagnosticException': 'نوع الاستثناء',
      'firestoreDiagnosticSucceeded': 'نجح الطلب',
      'firestoreDiagnosticDocumentExists': 'المستند موجود',
      'firestoreDiagnosticFirebaseCode': 'رمز Firebase',
      'firestoreDiagnosticYes': 'نعم',
      'firestoreDiagnosticNo': 'لا',
      'firestoreDiagnosticRest200':
          'HTTP 200: الاتصال والمصادقة يعملان والمستند موجود',
      'firestoreDiagnosticRest404':
          'HTTP 404: الاتصال والمصادقة يعملان والمستند غير موجود',
      'firestoreDiagnosticRest401':
          'HTTP 401: رمز Firebase غير صالح أو لم يتجدد',
      'firestoreDiagnosticRest403':
          'HTTP 403: الطلب مرفوض بقواعد Firestore أو الصلاحيات',
      'firestoreDiagnosticRest400':
          'HTTP 400: مسار المشروع أو قاعدة البيانات غير صحيح',
      'firestoreDiagnosticRest429': 'HTTP 429: تجاوز مؤقت للحصة',
      'firestoreDiagnosticRest5xx': 'خطأ مؤقت من خدمة Firestore',
      'firestoreDiagnosticDnsFailed':
          'تعذر حل اسم firestore.googleapis.com',
      'firestoreDiagnosticSocketFailed':
          'فشل اتصال Socket مع firestore.googleapis.com',
      'firestoreDiagnosticTlsFailed':
          'فشلت مصافحة TLS مع firestore.googleapis.com',
      'firestoreDiagnosticTimedOut': 'انتهت مهلة الاتصال',
      'firestoreDiagnosticClientFailed':
          'فشل عميل HTTPS قبل استلام استجابة',
      'firestoreDiagnosticNoUser': 'لا يوجد مستخدم Firebase مسجل',
      'firestoreDiagnosticTokenFailed':
          'تعذر تجديد Firebase ID token',
      'firestoreDiagnosticUnexpected':
          'فشل غير متوقع أثناء اختبار REST',
      'firestoreDiagnosticNativeTransportConclusion':
          'وصل REST إلى Firestore بينما فشل Native؛ الخلل محصور في نقل cloud_firestore أو Firebase iOS SDK.',
      'firestoreDiagnosticNetworkConclusion':
          'فشل REST قبل استلام HTTP؛ النتيجة تشير إلى DNS أو الشبكة أو TLS على الجهاز.',
      'firestoreDiagnosticAuthConclusion':
          'وصل REST إلى Firestore لكن المصادقة رُفضت؛ يلزم فحص تجديد جلسة Firebase Auth.',
      'firestoreDiagnosticRulesConclusion':
          'وصل REST إلى Firestore لكن الطلب رُفض؛ يلزم فحص القواعد أو صلاحية الحساب.',
      'firestoreDiagnosticBothReachedConclusion':
          'وصل REST وNative إلى Firestore بنجاح.',
      'firestoreDiagnosticNeedsReviewConclusion':
          'اكتمل الاختبار وتحتاج النتيجة إلى مراجعة الرمز الظاهر أعلاه.',
      'cloudQueuedLocally':
          'تم حفظ النسخة محليًا وهي بانتظار المزامنة السحابية',
      'firestoreDiagnosticEnvironmentTitle': 'بيئة Firebase',
      'firestoreDiagnosticAppVersion': 'الإصدار والبناء',
      'firestoreDiagnosticCommit': 'بصمة Git',
      'firestoreDiagnosticProject': 'المشروع',
      'firestoreDiagnosticDatabase': 'قاعدة البيانات',
      'firestoreDiagnosticSdkVersions': 'إصدارات Firebase',
      'firestoreDiagnosticDependencyManager': 'مدير اعتماديات iOS',
      'firestoreDiagnosticFeatureFlags': 'خيارات البناء',
      'firestoreDiagnosticAppCheck': 'App Check: مفعّل | المزوّد | الرمز',
      'firestoreDiagnosticFeatureFlagsValue':
          'الانتظار المحلي: {offline} | REST العام: {rest} | إنشاء REST أولًا: {firstCreate} | تحديث REST: {restUpdate} | App Check التشخيصي: {appCheckDebug}',
      'firestoreDiagnosticAppCheckValue':
          'مفعّل: {enabled} | المزوّد: {provider} | الرمز: {token}',
      'firestoreDiagnosticNotRequired': 'غير مطلوب',
      'firestoreDiagnosticNotUsed': 'لم يُستخدم',
      'firestoreDiagnosticServerConfirmed': 'نجاح مؤكد من الخادم',
      'firestoreDiagnosticQueuedLocally':
          'محفوظ محليًا وبانتظار الخادم',
      'firestoreDiagnosticFailed': 'فشل',
      'firestoreDiagnosticSyncRestStatus': 'حالة REST للإنشاء',
      'firestoreDiagnosticSyncRestResult': 'نتيجة REST للإنشاء',
      'firestoreDiagnosticPlugin': 'إضافة Firebase',
      'firestoreDiagnosticRuntimeType': 'نوع الاستثناء',
      'firestoreDiagnosticNativeOperation': 'عملية Native',
      'firestoreDiagnosticAttempts': 'عدد المحاولات',
      'firestoreDiagnosticNativeResult': 'نتيجة Native',
      'firestoreDiagnosticPendingWrites': 'كتابات محلية معلّقة',
      'cloudStorageResourceNotFound':
          'مساحة التخزين السحابية أو الملف المطلوب غير موجود. تحقق من إعداد Firebase.',
      'cloudFailedPrecondition':
          'لا يمكن بدء المزامنة قبل اكتمال إعداد Firebase على هذا الجهاز.',
      'cloudAppNotAuthorized':
          'هذا الإصدار من التطبيق غير مصرح له بالوصول إلى Firebase. تحقق من الباندل وتقييد مفتاح API.',
      'cloudEncryptedRestoreFailed':
          'تعذر فتح النسخة السحابية بالمفتاح المحفوظ في Keychain. لم تتغير بيانات هذا الجهاز.',
      'cloudServiceUnavailable':
          'خدمة المزامنة غير متاحة مؤقتًا. حاول مجددًا بعد لحظات.',
      'cloudOffline':
          'لا يمكن الوصول إلى Firebase الآن. تحقق من الإنترنت وأعد المحاولة.',
      'cloudTimeout':
          'استغرقت المزامنة وقتًا طويلًا. حاول مجددًا بعد لحظات.',
      'cloudFirebaseError':
          'تعذرت المزامنة بسبب خطأ من Firebase ({code}).',
      'cloudAccountMismatch':
          'بيانات هذا الجهاز مرتبطة بحساب آخر. سجّل الدخول بالحساب السابق أو احذف بيانات الجهاز قبل تبديل الحساب.',
      'cloudAccountBindingUnavailable':
          'تعذّر التحقق من حساب البيانات المحلية. أُوقفت المزامنة لحماية بياناتك.',
      'ui_f916d7d0556e': '{value0}\nتصنيفات',
      'ui_d966ce5d4f37': 'سيُرسل إلى {value0}:\n',
    },
  );
  static AppLocalizations _current = _fallback;

  static AppLocalizations of(BuildContext context) {
    final result = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    return result ?? _fallback;
  }

  TextDirection get textDirection =>
      locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr;

  String text(String key, [Map<String, Object?> values = const {}]) {
    var result = _messages[key] ?? key;
    for (final entry in values.entries) {
      result = result.replaceAll('{${entry.key}}', '${entry.value ?? ''}');
    }
    return result;
  }

  String plural(
    String key, {
    required num count,
    Map<String, Object?> values = const {},
  }) {
    final suffix = count == 0
        ? 'Zero'
        : count == 1
            ? 'One'
            : count == 2
                ? 'Two'
                : 'Other';
    return text('$key$suffix', <String, Object?>{'count': count, ...values});
  }

  String decimal(num value, {int? decimalDigits}) {
    final formatter = NumberFormat.decimalPatternDigits(
      locale: locale.languageCode == 'ar' ? 'ar_SA' : 'en_SA',
      decimalDigits: decimalDigits,
    );
    return _latinDigits(formatter.format(value));
  }

  String money(num value, String currency, {int decimalDigits = 2}) {
    final number = decimal(value, decimalDigits: decimalDigits);
    final symbol = currency == 'SAR'
        ? text('currencySar')
        : currency;
    return locale.languageCode == 'ar' ? '$number $symbol' : '$symbol $number';
  }

  String date(DateTime value, {String skeleton = 'yMMMd'}) {
    final localeName = locale.languageCode == 'ar' ? 'ar_SA' : 'en_SA';
    if (_initializedDateLocales.add(localeName)) {
      // The local Intl registrar installs symbols synchronously; its returned
      // future is already completed. This also keeps pure services testable
      // when they format a date before the Flutter localization delegate runs.
      initializeDateFormatting(localeName);
    }
    return _latinDigits(DateFormat(skeleton, localeName).format(value));
  }

  static String _latinDigits(String value) {
    const eastern = '٠١٢٣٤٥٦٧٨٩';
    var result = value;
    for (var index = 0; index < eastern.length; index++) {
      result = result.replaceAll(eastern[index], '$index');
    }
    return result;
  }

  static Future<AppLocalizations> load(Locale locale) async {
    final language = locale.languageCode == 'en' ? 'en' : 'ar';
    final data = await rootBundle.load('lib/l10n/app_$language.arb');
    // CachingAssetBundle moves strings larger than 50 KB to a helper isolate.
    // Decode this small catalog directly so localization remains deterministic
    // in widget tests and during early iOS startup.
    final source = utf8.decode(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    final raw = jsonDecode(source) as Map<String, dynamic>;
    final result = AppLocalizations._(
      Locale(language),
      raw.map(
        (key, value) => MapEntry(key, value is String ? value : '$value'),
      )..removeWhere((key, _) => key.startsWith('@')),
    );
    _current = result;
    return result;
  }
}

String tr(String key, [Map<String, Object?> values = const {}]) =>
    AppLocalizations._current.text(key, values);

bool get isEnglishLocale =>
    AppLocalizations._current.locale.languageCode == 'en';

String localizedNumber(num value, {int? decimalDigits}) =>
    AppLocalizations._current.decimal(value, decimalDigits: decimalDigits);

String localizedDate(DateTime value, {String skeleton = 'yMd'}) =>
    AppLocalizations._current.date(value, skeleton: skeleton);

class AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.supportedLocales.any(
        (supported) => supported.languageCode == locale.languageCode,
      );

  @override
  Future<AppLocalizations> load(Locale locale) =>
      AppLocalizations.load(locale);

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

Locale? resolveStoredLocale(String preference) => switch (preference) {
      'ar' => const Locale('ar'),
      'en' => const Locale('en'),
      _ => null,
    };

Locale resolveSupportedLocale(Locale? deviceLocale) {
  if (deviceLocale?.languageCode == 'en') return const Locale('en');
  return const Locale('ar');
}

void setDefaultFormattingLocale(Locale locale) {
  Intl.defaultLocale = locale.languageCode == 'en' ? 'en_SA' : 'ar_SA';
}

String latinDigits(String value) {
  const eastern = '٠١٢٣٤٥٦٧٨٩';
  var result = value;
  for (var index = 0; index < eastern.length; index++) {
    result = result.replaceAll(eastern[index], '$index');
  }
  return result;
}

String localizedPaymentKind(String name) => tr(switch (name) {
      'installment' => 'paymentInstallment',
      'bill' => 'paymentBill',
      _ => 'paymentSubscription',
    });

String localizedBillingCycle(String name) => tr(switch (name) {
      'weekly' => 'cycleWeekly',
      'quarterly' => 'cycleQuarterly',
      'yearly' => 'cycleYearly',
      _ => 'cycleMonthly',
    });

String localizedCategory(String value) => tr(switch (value) {
      'ترفيه ومشاهدة' => 'categoryEntertainment',
      'موسيقى وبودكاست' => 'categoryMusic',
      'إنتاجية وذكاء اصطناعي' => 'categoryProductivity',
      'ألعاب' => 'categoryGames',
      'رياضة وصحة' => 'categoryHealth',
      'تعليم' => 'categoryEducation',
      'تسوق وتوصيل' => 'categoryShopping',
      'اتصالات وإنترنت' => 'categoryTelecom',
      'تخزين سحابي' => 'categoryCloud',
      'مالية وفواتير' => 'categoryFinance',
      'أخبار ومجلات' => 'categoryNews',
      _ => 'categoryOther',
    });

String localizedDaysAfter(int days) {
  if (days <= 0) return tr('commonToday');
  if (days == 1) return tr('commonTomorrow');
  if (isEnglishLocale) {
    return tr('daysAfter', {'days': days});
  }
  if (days == 2) return tr('daysAfterTwo', {'days': days});
  if (days <= 10) return tr('daysAfterFew', {'days': days});
  return tr('daysAfterMany', {'days': days});
}
