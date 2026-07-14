/// فاحص التحديثات: يقرأ نسخة التطبيق الأحدث من المستودع
/// ويخبر المستخدم إن توفرت نسخة أجدد من المثبتة لديه.
library;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../l10n/app_localizations.dart';

/// نسخة التطبيق الحالية — تُحدَّث مع كل إصدار.
const String kAppVersion = '15.2.0';
const String kAppBuildNumber = '35';
const String kAppBuildLabel = '$kAppVersion ($kAppBuildNumber)';
String get kAppBuildMode => kReleaseMode
    ? tr('buildRelease')
    : kProfileMode
        ? tr('buildProfile')
        : tr('buildDebug');

const String _pubspecUrl =
    'https://raw.githubusercontent.com/basilsa77/ishtirakati/main/pubspec.yaml';

/// يستخرج "X.Y.Z" من محتوى pubspec — دالة نقية قابلة للاختبار.
String? extractVersion(String pubspecContent) {
  final m = RegExp(r'^version:\s*(\d+\.\d+\.\d+)', multiLine: true)
      .firstMatch(pubspecContent);
  return m?.group(1);
}

/// هل [remote] أحدث من [local]؟ (مقارنة X.Y.Z) — نقية قابلة للاختبار.
bool isNewerVersion(String remote, String local) {
  List<int> parse(String v) =>
      v.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  final r = parse(remote);
  final l = parse(local);
  for (var i = 0; i < 3; i++) {
    final a = i < r.length ? r[i] : 0;
    final b = i < l.length ? l[i] : 0;
    if (a != b) return a > b;
  }
  return false;
}

class UpdateChecker {
  UpdateChecker._();

  /// النسخة الأحدث المتاحة (null = لا تحديث أو لم يُفحص بعد).
  static final ValueNotifier<String?> newVersion = ValueNotifier(null);

  static Future<void> check() async {
    try {
      final res = await http
          .get(Uri.parse(_pubspecUrl))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return;
      final remote = extractVersion(res.body);
      if (remote != null && isNewerVersion(remote, kAppVersion)) {
        newVersion.value = remote;
      }
    } catch (_) {
      // بدون إنترنت — لا شيء.
    }
  }
}
