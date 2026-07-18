import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishtirakati/l10n/app_localizations.dart';
import 'package:ishtirakati/models/subscription.dart';
import 'package:ishtirakati/screens/calendar_screen.dart';
import 'package:ishtirakati/screens/subscriptions_screen.dart';
import 'package:ishtirakati/services/renewal_day_grouping.dart';
import 'package:ishtirakati/theme.dart';
import 'package:ishtirakati/widgets/app_material_root.dart';

Subscription _subscription({
  required String id,
  required String name,
  double price = 10,
  String currency = 'SAR',
}) => Subscription(
  id: id,
  name: name,
  emoji: 'S',
  price: price,
  currency: currency,
  cycle: BillingCycle.monthly,
  anchorDate: DateTime(2026, 7, 1),
  category: 'أخرى',
);

RenewalDayItem _item(
  Subscription subscription,
  DateTime occursAt, {
  double? amount,
}) => RenewalDayItem(
  subscription: subscription,
  occursAt: occursAt,
  amount: amount ?? subscription.price,
  currency: subscription.currency,
);

Future<void> _pumpLocalized(
  WidgetTester tester, {
  required Locale locale,
  required double width,
  required bool dark,
  required Widget child,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await AppLocalizations.load(locale);
  setDefaultFormattingLocale(locale);
  final height = width == 744 ? 1133.0 : 844.0;
  tester.view.physicalSize = Size(width, height);
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
            size: Size(width, height),
            disableAnimations: true,
          ),
          child: AppMaterialRoot(child: routedChild!),
        );
      },
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(V16Space.md),
          child: child,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.clearAllTestValues();
  });

  test(
    'renewals group by local day with stable ordering and currency totals',
    () {
      final first = _subscription(id: 'first', name: 'First', price: 7.25);
      final second = _subscription(id: 'second', name: 'Second', price: 4);
      final usd = _subscription(
        id: 'usd',
        name: 'USD',
        price: 3.5,
        currency: 'USD',
      );
      final nextDay = _subscription(id: 'next', name: 'Next', price: 11);

      final groups = RenewalDayGrouping.group([
        _item(nextDay, DateTime(2026, 7, 11, 0, 1)),
        _item(second, DateTime(2026, 7, 10, 23, 59)),
        _item(first, DateTime(2026, 7, 10, 9)),
        _item(usd, DateTime(2026, 7, 10, 9)),
      ], preferredCurrency: 'SAR');

      expect(groups, hasLength(2));
      expect(groups.first.date, DateTime(2026, 7, 10));
      expect(groups.last.date, DateTime(2026, 7, 11));
      expect(groups.first.items.map((item) => item.subscription.id), [
        'first',
        'usd',
        'second',
      ]);
      expect(groups.first.totalsByCurrency.keys, ['SAR', 'USD']);
      expect(groups.first.totalsByCurrency['SAR'], closeTo(11.25, .0001));
      expect(groups.first.totalsByCurrency['USD'], closeTo(3.5, .0001));
      expect(groups.last.totalsByCurrency, {'SAR': 11});
    },
  );

  test('UTC occurrences use the device-local calendar day', () {
    final subscription = _subscription(id: 'utc', name: 'UTC');
    final instant = DateTime.utc(2026, 7, 10, 23, 59);
    final local = instant.toLocal();

    final group =
        RenewalDayGrouping.group([_item(subscription, instant)]).single;

    expect(group.date, DateTime(local.year, local.month, local.day));
    expect(group.items.single.localOccurrence, local);
  });

  testWidgets(
    'short metric cards balance label and trailing value across layouts',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final locale in const [Locale('ar'), Locale('en')]) {
        for (final width in const [375.0, 390.0, 744.0]) {
          for (final dark in const [false, true]) {
            const shortValue = '42 SAR';
            const longValue = '123,456,789.00 SAR';
            const note =
                'A long note remains readable on multiple lines instead of '
                'being compressed into a one-line trailing metric value.';
            await _pumpLocalized(
              tester,
              locale: locale,
              width: width,
              dark: dark,
              child: const Column(
                children: [
                  AppMetricTile(
                    key: Key('short-app-metric'),
                    label: 'Average service',
                    value: shortValue,
                    icon: CupertinoIcons.money_dollar_circle,
                  ),
                  SizedBox(height: V16Space.sm),
                  AppMetricTile(
                    key: Key('long-app-metric'),
                    label: 'Renewals expected during the coming week',
                    value: longValue,
                    icon: CupertinoIcons.timer,
                  ),
                  SizedBox(height: V16Space.sm),
                  SubscriptionDetailMetric(
                    key: Key('short-detail-metric'),
                    icon: Icons.payments_outlined,
                    label: 'Monthly cost',
                    value: shortValue,
                  ),
                  SizedBox(height: V16Space.sm),
                  SubscriptionDetailMetric(
                    key: Key('long-detail-metric'),
                    icon: Icons.event_repeat_rounded,
                    label: 'Next renewal with a deliberately long label',
                    value: longValue,
                  ),
                  SizedBox(height: V16Space.sm),
                  SubscriptionDetailNote(
                    key: Key('multiline-detail-note'),
                    icon: Icons.notes_rounded,
                    label: 'Notes',
                    value: note,
                  ),
                ],
              ),
            );

            for (final key in const [
              Key('short-app-metric'),
              Key('long-app-metric'),
              Key('short-detail-metric'),
              Key('long-detail-metric'),
            ]) {
              expect(
                tester.getSize(find.byKey(key)).height,
                lessThanOrEqualTo(88),
              );
            }

            final longValueWidgets = tester.widgetList<Text>(
              find.text(longValue),
            );
            expect(longValueWidgets, hasLength(2));
            for (final text in longValueWidgets) {
              expect(text.maxLines, 1);
              expect(text.overflow, TextOverflow.ellipsis);
              expect(text.textAlign, TextAlign.end);
            }
            final noteText = tester.widget<Text>(find.text(note));
            expect(noteText.maxLines, isNull);
            expect(tester.takeException(), isNull);
          }
        }
      }
    },
  );

  testWidgets(
    'renewal timeline renders one local-day header and per-currency totals',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final sar = _subscription(
        id: 'sar-service',
        name: 'Tinder Dating App Premium International',
        price: 112.96,
      );
      final usd = _subscription(
        id: 'usd-service',
        name: 'Cloud Storage Pro',
        price: 9.99,
        currency: 'USD',
      );
      final group =
          RenewalDayGrouping.group([
            _item(sar, DateTime(2026, 7, 10, 9)),
            _item(usd, DateTime(2026, 7, 10, 18)),
          ], preferredCurrency: 'SAR').single;

      for (final locale in const [Locale('ar'), Locale('en')]) {
        for (final width in const [375.0, 390.0, 744.0]) {
          for (final dark in const [false, true]) {
            await _pumpLocalized(
              tester,
              locale: locale,
              width: width,
              dark: dark,
              child: RenewalDaySection(
                group: group,
                onOpenSubscription: (_) {},
                onOpenDuplicate: (_) {},
              ),
            );

            expect(
              find.byKey(const ValueKey('renewal-day-header-2026-07-10')),
              findsOneWidget,
            );
            expect(
              find.byKey(
                const ValueKey('renewal-day-item-2026-07-10-sar-service-0'),
              ),
              findsOneWidget,
            );
            expect(
              find.byKey(
                const ValueKey('renewal-day-item-2026-07-10-usd-service-1'),
              ),
              findsOneWidget,
            );
            expect(
              find.byKey(const ValueKey('renewal-day-total-2026-07-10-SAR')),
              findsOneWidget,
            );
            expect(
              find.byKey(const ValueKey('renewal-day-total-2026-07-10-USD')),
              findsOneWidget,
            );
            expect(
              find.text(formatShortDate(DateTime(2026, 7, 10))),
              findsOneWidget,
            );
            expect(find.text(localizedInteger(10)), findsNothing);
            expect(
              find.text(localizedPlural('v17ServiceCount', 2)),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
          }
        }
      }
    },
  );
}
