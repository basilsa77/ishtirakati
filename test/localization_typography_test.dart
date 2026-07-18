import 'dart:io';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishtirakati/l10n/app_localizations.dart';
import 'package:ishtirakati/services/subscription_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('all UI font sizes use the v15 type scale', () {
    final numericFontSize = RegExp(r'fontSize\s*:\s*\d');
    final violations = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      if (numericFontSize.hasMatch(source)) violations.add(entity.path);
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('stored language preference is validated and persisted', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SubscriptionStore.testing();
    await store.load();
    expect(store.languageMode, 'system');

    await store.setLanguageMode('en');
    expect(store.languageMode, 'en');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('ishtirakati_language_mode_v15'), 'en');

    await store.setLanguageMode('unsupported');
    expect(store.languageMode, 'en');
  });

  test('locale preference and unsupported device locales resolve safely', () {
    expect(resolveStoredLocale('ar'), const Locale('ar'));
    expect(resolveStoredLocale('en'), const Locale('en'));
    expect(resolveStoredLocale('system'), isNull);
    expect(
      resolveSupportedLocale(const Locale('en', 'US')),
      const Locale('en'),
    );
    expect(
      resolveSupportedLocale(const Locale('fr', 'FR')),
      const Locale('ar'),
    );
  });

  test('Arabic and English ARB catalogs stay complete and aligned', () {
    final arabic =
        jsonDecode(File('lib/l10n/app_ar.arb').readAsStringSync())
            as Map<String, dynamic>;
    final english =
        jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
            as Map<String, dynamic>;
    expect(arabic.keys.toSet(), english.keys.toSet());
    expect(arabic.length, greaterThan(500));
    expect(
      english.entries
          .where((entry) => entry.key != 'languageArabic')
          .where(
            (entry) => RegExp(r'[\u0600-\u06ff]').hasMatch('${entry.value}'),
          ),
      isEmpty,
    );
  });

  testWidgets('localized messages switch language and preserve placeholders', (
    _,
  ) async {
    await AppLocalizations.load(const Locale('en'));
    expect(tr('navSettings'), 'Settings');
    expect(tr('daysAfter', {'days': 4}), 'In 4 days');

    await AppLocalizations.load(const Locale('ar'));
    expect(tr('navSettings'), 'الإعدادات');
    expect(localizedDaysAfter(2), 'بعد يومين');
    expect(localizedDaysAfter(4), 'بعد 4 أيام');
    expect(localizedDaysAfter(14), 'بعد 14 يومًا');
  });
}
