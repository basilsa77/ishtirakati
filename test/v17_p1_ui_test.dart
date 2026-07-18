import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishtirakati/l10n/app_localizations.dart';
import 'package:ishtirakati/models/subscription.dart';
import 'package:ishtirakati/screens/financial_review_screen.dart';
import 'package:ishtirakati/screens/insights_screen.dart';
import 'package:ishtirakati/screens/pulse_home_screen.dart';
import 'package:ishtirakati/services/financial_assistant.dart';
import 'package:ishtirakati/services/financial_distribution.dart';
import 'package:ishtirakati/services/renewal_window.dart';
import 'package:ishtirakati/services/secure_data_codec.dart';
import 'package:ishtirakati/services/spending_history.dart';
import 'package:ishtirakati/services/subscription_store.dart';
import 'package:ishtirakati/theme.dart';
import 'package:ishtirakati/widgets/app_material_root.dart';
import 'package:ishtirakati/widgets/potential_duplicate_badge.dart';
import 'package:shared_preferences/shared_preferences.dart';

Subscription _subscription({
  required String id,
  String? name,
  required DateTime anchor,
  BillingCycle cycle = BillingCycle.monthly,
  double price = 10,
  String currency = 'SAR',
}) => Subscription(
  id: id,
  name: name ?? id,
  emoji: 'S',
  price: price,
  currency: currency,
  cycle: cycle,
  anchorDate: anchor,
  category: 'أخرى',
);

class _MemoryKeyStore implements SecureKeyStore {
  final List<String> values = [];

  @override
  Future<void> deleteAll(String key) async => values.clear();

  @override
  Future<List<String>> readAll(String key) async => List.of(values);

  @override
  Future<bool> writeAll(String key, String value) async {
    if (!values.contains(value)) values.add(value);
    return true;
  }
}

class _DuplicateReviewHarness extends StatelessWidget {
  final SubscriptionStore store;

  const _DuplicateReviewHarness({super.key, required this.store});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final groups = FinancialAssistant.indexDuplicateGroupsBySubscriptionId(
        FinancialAssistant.findDuplicateGroups(store.items),
      );
      return Column(
        children: [
          for (final subscription in store.items)
            if (groups[subscription.id] case final group?)
              PotentialDuplicateBadge(
                key: ValueKey('duplicate-badge-${subscription.id}'),
                onTap:
                    () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder:
                            (_) => FinancialReviewScreen(
                              currency: subscription.currency,
                              initialDuplicateGroupKey: group.groupKey,
                              store: store,
                            ),
                      ),
                    ),
              ),
        ],
      );
    },
  );
}

Future<void> _pumpLocalized(
  WidgetTester tester, {
  required Widget child,
  required Locale locale,
  required Size size,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
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
      builder:
          (context, routedChild) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(size: size, disableAnimations: true),
            child: AppMaterialRoot(child: routedChild!),
          ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(V16Space.md),
          child: child,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('30-day summary uses occurrence count and currency totals', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final summary = RenewalWindow.calculate([
      _subscription(
        id: 'weekly',
        anchor: DateTime(2026, 7, 1),
        cycle: BillingCycle.weekly,
        price: 10,
      ),
      _subscription(
        id: 'monthly-usd',
        anchor: DateTime(2026, 7, 10),
        price: 7.5,
        currency: 'USD',
      ),
    ], now: DateTime(2026, 7, 1));

    expect(summary.paymentCount, 6);
    expect(summary.uniqueSubscriptionCount, 2);
    expect(summary.totalsByCurrency, {'SAR': 50, 'USD': 7.5});

    for (final locale in const [Locale('ar'), Locale('en')]) {
      for (final width in [375.0, 390.0, 744.0]) {
        await _pumpLocalized(
          tester,
          locale: locale,
          size: Size(width, width == 744 ? 1133 : 844),
          child: RenewalSummaryCard(
            fallbackCurrency: 'SAR',
            summary: summary,
            onOpen: () {},
          ),
        );

        expect(find.text(tr('v17Next30DaysTotal')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('next-30-days-total-SAR')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('next-30-days-total-USD')),
          findsOneWidget,
        );
        expect(find.text(tr('ui_08965782a0af')), findsNothing);
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('distribution legend expands every grouped category', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final result = FinancialDistribution.calculate(const [
      MapEntry('ترفيه ومشاهدة', 50),
      MapEntry('موسيقى وبودكاست', 20),
      MapEntry('إنتاجية وذكاء اصطناعي', 10),
      MapEntry('ألعاب', 7),
      MapEntry('رياضة وصحة', 5),
      MapEntry('تعليم', 4),
      MapEntry('تسوق وتوصيل', 2),
      MapEntry('أخبار ومجلات', 1),
    ]);
    expect(
      result.slices.fold<int>(0, (sum, item) => sum + item.percentage),
      100,
    );

    for (final locale in const [Locale('ar'), Locale('en')]) {
      for (final width in [375.0, 390.0]) {
        await _pumpLocalized(
          tester,
          locale: locale,
          size: Size(width, 844),
          child: DistributionCard(
            key: ValueKey('distribution-${locale.languageCode}-$width'),
            distribution: result,
            currency: 'SAR',
          ),
        );

        final expand = find.byKey(const Key('distribution-expand-categories'));
        expect(expand, findsOneWidget);
        await tester.tap(expand);
        await tester.pump();
        expect(find.text(localizedCategory('تعليم')), findsOneWidget);
        expect(find.text(localizedCategory('تسوق وتوصيل')), findsOneWidget);
        expect(find.text(localizedCategory('أخبار ومجلات')), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('duplicate badges open the exact group and persist ignore', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final locale in const [Locale('ar'), Locale('en')]) {
      for (final width in [375.0, 390.0]) {
        SharedPreferences.setMockInitialValues({});
        final keyStore = _MemoryKeyStore();
        final store = SubscriptionStore.testing(
          secretStore: keyStore,
          dataCodec: SecureDataCodec(keyStore: keyStore),
        );
        await store.load();
        await store.upsert(
          _subscription(
            id: 'first',
            name: 'Netflix Basic',
            price: 45,
            anchor: DateTime(2026, 7, 1),
          ),
        );
        await store.upsert(
          _subscription(
            id: 'second',
            name: 'Netflix Premium',
            price: 65,
            anchor: DateTime(2026, 7, 1),
          ),
        );
        await _pumpLocalized(
          tester,
          locale: locale,
          size: Size(width, 844),
          child: _DuplicateReviewHarness(
            key: ValueKey('duplicate-${locale.languageCode}-$width'),
            store: store,
          ),
        );

        expect(find.byType(PotentialDuplicateBadge), findsNWidgets(2));
        expect(
          tester.getSize(find.byType(PotentialDuplicateBadge).first).height,
          greaterThanOrEqualTo(44),
        );
        await tester.tap(find.byKey(const ValueKey('duplicate-badge-second')));
        await tester.pumpAndSettle();

        final group =
            FinancialAssistant.findDuplicateGroups(store.items).single;
        final focusedGroup = find.byKey(
          ValueKey('duplicate-review-${group.groupKey}'),
        );
        expect(focusedGroup, findsOneWidget);
        expect(
          find.descendant(
            of: focusedGroup,
            matching: find.text('Netflix Basic'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: focusedGroup,
            matching: find.text('Netflix Premium'),
          ),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('ignore-duplicate-group')));
        await tester.pumpAndSettle();
        expect(FinancialAssistant.findDuplicateGroups(store.items), isEmpty);
        expect(find.byType(PotentialDuplicateBadge), findsNothing);
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('payment history shows no-data state instead of zero bars', (
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
          child: SpendingHistoryCard(
            history: SpendingHistory.unavailable(now: DateTime(2026, 7, 18)),
            currency: 'SAR',
          ),
        );
        expect(
          find.byKey(const Key('payment-history-no-data')),
          findsOneWidget,
        );
        expect(find.text(tr('v17PaymentHistoryUnavailable')), findsNWidgets(2));
        expect(find.byType(FractionallySizedBox), findsNothing);
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('actual zero remains distinct from an actual amount', (
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
          child: SpendingHistoryCard(
            history: [
              SpendingPoint.noData(month: DateTime(2026, 5)),
              SpendingPoint.actual(month: DateTime(2026, 6), amount: 0),
              SpendingPoint.actual(month: DateTime(2026, 7), amount: 100),
            ],
            currency: 'USD',
          ),
        );

        expect(find.byKey(const Key('payment-history-no-data')), findsNothing);
        expect(
          find.textContaining(fmtMoneyWithCurrency(100, 'USD')),
          findsOneWidget,
        );
        expect(find.text('—'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    }
  });

  test('central money formatter labels every supported currency', () async {
    for (final locale in const [Locale('ar'), Locale('en')]) {
      await AppLocalizations.load(locale);
      for (final entry in currencySymbols.entries) {
        final formatted = fmtMoneyWithCurrency(12.5, entry.key);
        final expectedSymbol =
            locale.languageCode == 'en' && entry.key == 'SAR'
                ? 'SAR'
                : entry.value;
        expect(formatted, contains(expectedSymbol), reason: entry.key);
        expect(formatted, contains('12.5'), reason: entry.key);
        if (locale.languageCode == 'en') {
          expect(formatted.startsWith(expectedSymbol), isTrue);
        } else {
          expect(formatted.endsWith(expectedSymbol), isTrue);
        }
      }
    }
  });

  test('category palette is distinct in hue, brightness, or saturation', () {
    final colors = kCategoryColors.values.toList(growable: false);
    expect(colors.toSet(), hasLength(colors.length));
    for (var first = 0; first < colors.length; first++) {
      for (var second = first + 1; second < colors.length; second++) {
        final left = HSVColor.fromColor(colors[first]);
        final right = HSVColor.fromColor(colors[second]);
        final rawHueDistance = (left.hue - right.hue).abs();
        final hueDistance =
            rawHueDistance > 180 ? 360 - rawHueDistance : rawHueDistance;
        final visuallyDistinct =
            hueDistance >= 15 ||
            (left.value - right.value).abs() >= .15 ||
            (left.saturation - right.saturation).abs() >= .25;
        expect(
          visuallyDistinct,
          isTrue,
          reason: '${colors[first]} and ${colors[second]} are too similar',
        );
      }
    }
  });
}
