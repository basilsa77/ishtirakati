import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishtirakati/l10n/app_localizations.dart';

const _requiredCounts = <int>[0, 1, 2, 3, 11, 45, 48, 100];

const _pluralKeys = <String>[
  'v17ActiveCommitmentCount',
  'v17RenewalCountNext30Days',
  'v17DiscountCountNext30Days',
  'v17OperationCountNext30Days',
  'v17ActiveSubscriptionCount',
  'v17PaymentCount',
  'v17PaymentsThisMonthCount',
  'v17RenewalCount',
  'v17CategoryCount',
  'v17AdditionalCategoryCount',
  'v17TransactionCountNext21Days',
  'v17ReviewCountPrioritySorted',
  'v17DecisionItemCount',
  'v17ServiceClassifiedCount',
  'v17UnusedSubscriptionCount',
  'v17SubscriptionDiscoveredCount',
  'v17AiAnalyzedSubscriptionCount',
  'v17SubscriptionAddedCount',
  'v17SubscriptionReviewCount',
  'v17IndicatorReviewCount',
  'v17ReviewCount',
  'v17UrgentReviewCount',
  'v17PotentialDuplicateSubscriptionCount',
  'v17ServiceCount',
  'v17DaysAfterCount',
  'v17EmailScanNoMatches',
  'v17SubscriptionRenewsInDays',
  'backupDeleteFinalMessage',
  'backupImportCompleted',
];

const _arabicCoreCases = <String, Map<int, String>>{
  'v17ActiveCommitmentCount': {
    0: 'لا توجد التزامات نشطة',
    1: 'التزام نشط واحد',
    2: 'التزامان نشطان',
    3: '3 التزامات نشطة',
    11: '11 التزامًا نشطًا',
    45: '45 التزامًا نشطًا',
    100: '100 التزام نشط',
  },
  'v17DiscountCountNext30Days': {
    0: 'لا توجد خصومات خلال 30 يومًا',
    1: 'خصم واحد خلال 30 يومًا',
    2: 'خصمان خلال 30 يومًا',
    3: '3 خصومات خلال 30 يومًا',
    11: '11 خصمًا خلال 30 يومًا',
    45: '45 خصمًا خلال 30 يومًا',
    100: '100 خصم خلال 30 يومًا',
  },
  'v17OperationCountNext30Days': {
    0: 'لا توجد عمليات خلال 30 يومًا',
    1: 'عملية واحدة خلال 30 يومًا',
    2: 'عمليتان خلال 30 يومًا',
    3: '3 عمليات خلال 30 يومًا',
    11: '11 عملية خلال 30 يومًا',
    45: '45 عملية خلال 30 يومًا',
    100: '100 عملية خلال 30 يومًا',
  },
  'v17PaymentCount': {
    0: 'لا توجد دفعات',
    1: 'دفعة واحدة',
    2: 'دفعتان',
    3: '3 دفعات',
    11: '11 دفعة',
    45: '45 دفعة',
    48: '48 دفعة',
    100: '100 دفعة',
  },
};

const _englishCoreCases = <String, Map<int, String>>{
  'v17ActiveCommitmentCount': {
    0: 'No active commitments',
    1: '1 active commitment',
    2: '2 active commitments',
    3: '3 active commitments',
    11: '11 active commitments',
    45: '45 active commitments',
    100: '100 active commitments',
  },
  'v17DiscountCountNext30Days': {
    0: 'No discounts in the next 30 days',
    1: '1 discount in the next 30 days',
    2: '2 discounts in the next 30 days',
    3: '3 discounts in the next 30 days',
    11: '11 discounts in the next 30 days',
    45: '45 discounts in the next 30 days',
    100: '100 discounts in the next 30 days',
  },
  'v17OperationCountNext30Days': {
    0: 'No transactions in the next 30 days',
    1: '1 transaction in the next 30 days',
    2: '2 transactions in the next 30 days',
    3: '3 transactions in the next 30 days',
    11: '11 transactions in the next 30 days',
    45: '45 transactions in the next 30 days',
    100: '100 transactions in the next 30 days',
  },
  'v17PaymentCount': {
    0: 'No payments',
    1: '1 payment',
    2: '2 payments',
    3: '3 payments',
    11: '11 payments',
    45: '45 payments',
    48: '48 payments',
    100: '100 payments',
  },
};

Future<void> _pumpProbe(WidgetTester tester, Locale locale) async {
  await AppLocalizations.load(locale);
  setDefaultFormattingLocale(locale);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: Builder(
          builder:
              (context) => Text(
                '${context.l10n.integer(1234)}|'
                '${context.l10n.percent(45)}|'
                '${context.l10n.longDate(DateTime(2026, 7, 18))}',
              ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every v17 count message is valid six-branch ICU plural', () {
    for (final path in ['lib/l10n/app_ar.arb', 'lib/l10n/app_en.arb']) {
      final catalog =
          jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
      for (final key in _pluralKeys) {
        final message = catalog[key] as String;
        expect(message, startsWith('{count, plural,'), reason: '$path: $key');
        for (final branch in ['zero', 'one', 'two', 'few', 'many', 'other']) {
          expect(message, contains('$branch {'), reason: '$path: $key');
        }
      }
    }
  });

  testWidgets('Arabic core count nouns follow the approved grammar table', (
    _,
  ) async {
    await AppLocalizations.load(const Locale('ar'));
    for (final entry in _arabicCoreCases.entries) {
      for (final countCase in entry.value.entries) {
        expect(
          localizedPlural(entry.key, countCase.key),
          countCase.value,
          reason: '${entry.key}: ${countCase.key}',
        );
      }
    }
  });

  testWidgets('English core count nouns use correct singular and plural', (
    _,
  ) async {
    await AppLocalizations.load(const Locale('en'));
    for (final entry in _englishCoreCases.entries) {
      for (final countCase in entry.value.entries) {
        expect(
          localizedPlural(entry.key, countCase.key),
          countCase.value,
          reason: '${entry.key}: ${countCase.key}',
        );
      }
    }
  });

  testWidgets('all count messages resolve every mandatory test value', (
    _,
  ) async {
    final forbiddenDigits = RegExp(r'[٠-٩۰-۹]');
    for (final locale in const [Locale('ar'), Locale('en')]) {
      await AppLocalizations.load(locale);
      for (final key in _pluralKeys) {
        for (final count in _requiredCounts) {
          final value = localizedPlural(key, count, const {'name': 'Netflix'});
          expect(value, isNot(contains('{')), reason: '$locale $key $count');
          expect(value, isNot(contains('}')), reason: '$locale $key $count');
          expect(value, isNot(contains('#')), reason: '$locale $key $count');
          expect(
            forbiddenDigits.hasMatch(value),
            isFalse,
            reason: '$locale $key $count',
          );
        }
      }
    }
  });

  testWidgets('number formatter always paints western digits', (_) async {
    for (final locale in const [Locale('ar'), Locale('en')]) {
      await AppLocalizations.load(locale);
      expect(localizedNumber(1234567.89), '1,234,567.89');
      expect(localizedInteger(45), '45');
      expect(localizedPercent(45), '45%');
      expect(latinDigits('٠١٢٣٤٥٦٧٨٩ ۰۱۲۳۴۵۶۷۸۹'), '0123456789 0123456789');
    }
  });

  testWidgets('long and short dates are centralized for both languages', (
    _,
  ) async {
    await AppLocalizations.load(const Locale('ar'));
    expect(formatLongDate(DateTime(2026, 7, 18)), '18/07/2026');
    expect(formatShortDate(DateTime(2026, 7, 27)), '27 يوليو');
    expect(formatLongDate(DateTime(2026, 12, 31)), '31/12/2026');
    expect(formatShortDate(DateTime(2026, 12, 31)), '31 ديسمبر');
    expect(formatLongDate(DateTime(2028, 2, 29)), '29/02/2028');

    await AppLocalizations.load(const Locale('en'));
    expect(formatLongDate(DateTime(2026, 7, 18)), '18/07/2026');
    expect(formatShortDate(DateTime(2026, 7, 27)), 'Jul 27');
    expect(formatLongDate(DateTime(2026, 12, 31)), '31/12/2026');
    expect(formatShortDate(DateTime(2026, 12, 31)), 'Dec 31');
    expect(formatLongDate(DateTime(2028, 2, 29)), '29/02/2028');
  });

  testWidgets('localized numeric widgets render consistently in RTL and LTR', (
    tester,
  ) async {
    await _pumpProbe(tester, const Locale('ar'));
    expect(find.text('1,234|45%|18/07/2026'), findsOneWidget);

    await _pumpProbe(tester, const Locale('en'));
    expect(find.text('1,234|45%|18/07/2026'), findsOneWidget);
  });
}
