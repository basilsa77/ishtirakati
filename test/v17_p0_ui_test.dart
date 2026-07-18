import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishtirakati/l10n/app_localizations.dart';
import 'package:ishtirakati/models/subscription.dart';
import 'package:ishtirakati/screens/calendar_screen.dart';
import 'package:ishtirakati/screens/command_palette.dart';
import 'package:ishtirakati/screens/edit_subscription_screen.dart';
import 'package:ishtirakati/screens/insights_screen.dart';
import 'package:ishtirakati/services/financial_assistant.dart';
import 'package:ishtirakati/theme.dart';
import 'package:ishtirakati/widgets/app_material_root.dart';

Future<void> _pumpLocalized(
  WidgetTester tester, {
  required Widget child,
  required Locale locale,
  required Size size,
  bool dark = false,
  double keyboardInset = 0,
}) async {
  await AppLocalizations.load(locale);
  setDefaultFormattingLocale(locale);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
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
      theme: buildAppTheme(),
      darkTheme: buildAppTheme(dark: true),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      builder: (context, routedChild) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            size: size,
            viewInsets: EdgeInsets.only(bottom: keyboardInset),
            disableAnimations: true,
          ),
          child: AppMaterialRoot(child: routedChild!),
        );
      },
      home: Scaffold(body: child),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

FinancialAssistantSnapshot _forecastSnapshot() => FinancialAssistantSnapshot(
  currency: 'SAR',
  forecast: [
    for (var month = 1; month <= 12; month++)
      MonthlyForecast(
        month: DateTime(2026, month),
        total: month == 12 ? 1234567.89 : month * 1250.25,
        paymentCount: month,
      ),
  ],
  duplicateGroups: const [],
  reviewItems: const [],
  potentialMonthlySavings: 0,
);

void main() {
  test('ARB catalogs never decode an accidental literal backslash-n', () async {
    for (final language in ['ar', 'en']) {
      final source = await rootBundle.loadString('lib/l10n/app_$language.arb');
      final catalog = jsonDecode(source) as Map<String, dynamic>;
      final accidental =
          catalog.entries
              .where(
                (entry) =>
                    entry.value is String &&
                    (entry.value as String).contains(r'\n'),
              )
              .map((entry) => entry.key)
              .toList();
      expect(accidental, isEmpty, reason: '$language: $accidental');
    }
  });

  test(
    'category count badge is a clean single line in Arabic and English',
    () async {
      await AppLocalizations.load(const Locale('ar'));
      expect(tr('ui_f916d7d0556e', {'value0': 9}), '9 تصنيفات');
      expect(tr('ui_f916d7d0556e', {'value0': 9}), isNot(contains('\n')));

      await AppLocalizations.load(const Locale('en'));
      expect(tr('ui_f916d7d0556e', {'value0': 9}), '9 Categories');
      expect(tr('ui_f916d7d0556e', {'value0': 9}), isNot(contains('\n')));
    },
  );

  testWidgets('popular services use an opaque keyboard-safe modal surface', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final locale in const [Locale('ar'), Locale('en')]) {
      for (final width in [375.0, 390.0, 744.0]) {
        await _pumpLocalized(
          tester,
          child: const EditSubscriptionScreen(),
          locale: locale,
          size: Size(width, width == 744 ? 1133 : 844),
          keyboardInset: width == 375 ? 260 : 0,
        );

        final openButton = find.byKey(const Key('open-popular-services'));
        final button = tester.widget<CupertinoButton>(openButton);
        button.onPressed!();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        final surfaceFinder = find.byKey(const Key('ios-modal-sheet-surface'));
        expect(surfaceFinder, findsOneWidget);
        final surface = tester.widget<Material>(surfaceFinder);
        expect(surface.color, isNotNull);
        expect((surface.color!.a * 255).round(), 255);
        expect(surface.color, AppPalette.light.surface);

        final barriers =
            tester
                .widgetList<ModalBarrier>(find.byType(ModalBarrier))
                .where((barrier) => barrier.color != null)
                .toList();
        expect(barriers, isNotEmpty);
        final barrierAlpha = barriers.last.color!.a;
        expect(barrierAlpha, inInclusiveRange(.4, .6));

        final title = find.text(tr('ui_b0ae1da4a56b'));
        expect(title, findsOneWidget);
        final titleTop = tester.getTopLeft(title).dy;
        final sheetScrollable = find.descendant(
          of: surfaceFinder,
          matching: find.byType(Scrollable),
        );
        if (sheetScrollable.evaluate().isNotEmpty) {
          await tester.drag(sheetScrollable.last, const Offset(0, -180));
          await tester.pump();
          expect(tester.getTopLeft(title).dy, closeTo(titleTop, .1));
        }
        expect(tester.takeException(), isNull);
        Navigator.of(tester.element(surfaceFinder)).pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }
    }
  });

  testWidgets('command palette reserves only the design-token search gap', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final locale in const [Locale('ar'), Locale('en')]) {
      for (final width in [375.0, 390.0]) {
        await _pumpLocalized(
          tester,
          locale: locale,
          size: Size(width, 844),
          child: Builder(
            builder:
                (context) => TextButton(
                  key: const Key('open-command-palette'),
                  onPressed:
                      () =>
                          showV12CommandPalette(context, onDestination: (_) {}),
                  child: const Text('Open'),
                ),
          ),
        );
        await tester.tap(find.byKey(const Key('open-command-palette')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        final search = find.byKey(const Key('command-palette-search'));
        final content = find.byKey(const Key('command-palette-content'));
        expect(
          find.byKey(const Key('command-palette-results')),
          findsOneWidget,
        );
        final populatedGap =
            tester.getTopLeft(content).dy - tester.getBottomLeft(search).dy;
        expect(populatedGap, closeTo(V16Space.md, .1));

        await tester.enterText(search, 'zz-no-command-result');
        await tester.pump();
        expect(find.byKey(const Key('command-palette-results')), findsNothing);
        final emptyGap =
            tester.getTopLeft(content).dy - tester.getBottomLeft(search).dy;
        expect(emptyGap, closeTo(V16Space.md, .1));
        expect(tester.takeException(), isNull);

        Navigator.of(tester.element(content)).pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }
    }
  });

  testWidgets('forecast exposes all 12 localized months and full tooltips', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final snapshot = _forecastSnapshot();

    for (final locale in const [Locale('ar'), Locale('en')]) {
      for (final width in [375.0, 390.0, 744.0]) {
        await _pumpLocalized(
          tester,
          locale: locale,
          size: Size(width, width == 744 ? 1133 : 844),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(V16Space.md),
            child: ForecastCard(snapshot: snapshot),
          ),
        );

        final scroll = find.byKey(const Key('forecast-chart-scroll'));
        expect(scroll, findsOneWidget);
        final chartScrollable = find.descendant(
          of: scroll,
          matching: find.byType(Scrollable),
        );
        final chartPosition = tester.state<ScrollableState>(
          chartScrollable.first,
        );
        chartPosition.position.jumpTo(chartPosition.position.minScrollExtent);
        await tester.pump();
        expect(find.byKey(const ValueKey('forecast-month-1')), findsOneWidget);
        expect(
          find.text(locale.languageCode == 'ar' ? 'ينا' : 'Jan'),
          findsOneWidget,
        );

        chartPosition.position.jumpTo(chartPosition.position.maxScrollExtent);
        await tester.pump();
        final lastMonth = find.byKey(const ValueKey('forecast-month-12'));
        expect(lastMonth, findsOneWidget);
        await tester.ensureVisible(lastMonth);
        await tester.pump();
        expect(
          find.text(locale.languageCode == 'ar' ? 'ديس' : 'Dec'),
          findsOneWidget,
        );

        final viewport = tester.getRect(scroll);
        final lastBounds = tester.getRect(lastMonth);
        expect(lastBounds.left, greaterThanOrEqualTo(viewport.left - .1));
        expect(lastBounds.right, lessThanOrEqualTo(viewport.right + .1));

        final tooltipFinder = find.ancestor(
          of: lastMonth,
          matching: find.byType(Tooltip),
        );
        final tooltip = tester.widget<Tooltip>(tooltipFinder);
        expect(
          tooltip.message,
          fmtMoneyWithCurrency(1234567.89, snapshot.currency),
        );
        await tester.tap(lastMonth);
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text(tooltip.message!), findsWidgets);
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('renewals summary contains only its intended visible layers', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final dark in [false, true]) {
      for (final width in [375.0, 744.0]) {
        await _pumpLocalized(
          tester,
          locale: const Locale('ar'),
          size: Size(width, width == 744 ? 1133 : 844),
          dark: dark,
          child: const Padding(
            padding: EdgeInsets.all(V16Space.md),
            child: RenewalsSummaryCard(
              totals: {'SAR': 1234.5, 'USD': 20},
              itemCount: 4,
            ),
          ),
        );

        final card = find.byKey(const Key('renewals-summary-card'));
        expect(card, findsOneWidget);
        expect(
          find.descendant(of: card, matching: find.byType(Stack)),
          findsNothing,
        );
        expect(
          find.descendant(of: card, matching: find.byType(Opacity)),
          findsNothing,
        );
        expect(
          find.descendant(of: card, matching: find.byType(AnimatedMoney)),
          findsNWidgets(2),
        );
        expect(find.byKey(const Key('renewals-summary-count')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('renewals-summary-amount-SAR')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('renewals-summary-amount-USD')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
    }
  });
}
