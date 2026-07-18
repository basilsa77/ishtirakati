import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishtirakati/l10n/app_localizations.dart';
import 'package:ishtirakati/models/subscription.dart';
import 'package:ishtirakati/screens/edit_subscription_screen.dart';
import 'package:ishtirakati/screens/quick_add_sheet.dart';
import 'package:ishtirakati/theme.dart';
import 'package:ishtirakati/widgets/app_material_root.dart';
import 'package:ishtirakati/widgets/ios_controls.dart';
import 'package:ishtirakati/widgets/service_name_text.dart';

double _contrastRatio(Color foreground, Color background) {
  final lighter =
      foreground.computeLuminance() > background.computeLuminance()
          ? foreground.computeLuminance()
          : background.computeLuminance();
  final darker =
      foreground.computeLuminance() > background.computeLuminance()
          ? background.computeLuminance()
          : foreground.computeLuminance();
  return (lighter + .05) / (darker + .05);
}

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
  tester.view.physicalSize = Size(width, 844);
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
          data: media.copyWith(size: Size(width, 844), disableAnimations: true),
          child: AppMaterialRoot(child: routedChild!),
        );
      },
      home: Scaffold(body: child),
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

  test('service-name direction follows its first strong character only', () {
    expect(
      serviceNameTextDirection(
        'Tinder Dating App Premium Plus',
        TextDirection.rtl,
      ),
      TextDirection.ltr,
    );
    expect(
      serviceNameTextDirection('365 Sports Premium', TextDirection.rtl),
      TextDirection.ltr,
    );
    expect(
      serviceNameTextDirection(
        '\u0634\u0627\u0647\u062F VIP',
        TextDirection.ltr,
      ),
      TextDirection.rtl,
    );
    expect(
      serviceNameTextDirection('12345', TextDirection.rtl),
      TextDirection.rtl,
    );
  });

  testWidgets(
    'English service names keep trailing ellipsis in RTL and LTR layouts',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const original = 'Tinder Dating App Premium International Membership';

      for (final locale in const [Locale('ar'), Locale('en')]) {
        for (final width in const [375.0, 390.0]) {
          for (final dark in const [false, true]) {
            await _pumpLocalized(
              tester,
              locale: locale,
              width: width,
              dark: dark,
              child: const SizedBox(
                width: 128,
                child: ServiceNameText(
                  key: Key('long-english-service-name'),
                  name: original,
                ),
              ),
            );

            final label = tester.widget<Text>(
              find.descendant(
                of: find.byKey(const Key('long-english-service-name')),
                matching: find.byType(Text),
              ),
            );
            expect(label.data, original);
            expect(label.textDirection, TextDirection.ltr);
            expect(
              label.textAlign,
              locale.languageCode == 'ar' ? TextAlign.right : TextAlign.left,
            );
            expect(label.maxLines, 1);
            expect(label.overflow, TextOverflow.ellipsis);
            expect(tester.takeException(), isNull);
          }
        }
      }
    },
  );

  testWidgets(
    'shared segmented control is high contrast in both directions and themes',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final locale in const [Locale('ar'), Locale('en')]) {
        for (final width in const [375.0, 390.0]) {
          for (final dark in const [false, true]) {
            await _pumpLocalized(
              tester,
              locale: locale,
              width: width,
              dark: dark,
              child: AppSegmentedControl<BillingCycle>(
                key: const Key('test-cycle-segments'),
                groupValue: BillingCycle.monthly,
                labels: const {
                  BillingCycle.weekly: 'Weekly',
                  BillingCycle.monthly: 'Monthly',
                  BillingCycle.quarterly: 'Quarterly',
                  BillingCycle.yearly: 'Yearly',
                },
                onValueChanged: (_) {},
              ),
            );

            final control = tester
                .widget<CupertinoSlidingSegmentedControl<BillingCycle>>(
                  find.descendant(
                    of: find.byKey(const Key('test-cycle-segments')),
                    matching: find.byType(
                      CupertinoSlidingSegmentedControl<BillingCycle>,
                    ),
                  ),
                );
            final context = tester.element(
              find.byKey(const Key('test-cycle-segments')),
            );
            final palette = context.palette;
            expect(control.backgroundColor, palette.surfaceAlt);
            expect(control.thumbColor, palette.accentStrong);

            final selected = tester.widget<Text>(
              find.byKey(
                const ValueKey<String>('app-segment-BillingCycle.monthly'),
              ),
            );
            final unselected = tester.widget<Text>(
              find.byKey(
                const ValueKey<String>('app-segment-BillingCycle.weekly'),
              ),
            );
            expect(selected.style?.color, V16Colors.white);
            expect(
              _contrastRatio(selected.style!.color!, control.thumbColor),
              greaterThanOrEqualTo(4.5),
            );
            expect(unselected.style?.color, palette.text);
            expect(tester.takeException(), isNull);
          }
        }
      }
    },
  );

  testWidgets('full and quick forms use the same cycle control', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpLocalized(
      tester,
      locale: const Locale('ar'),
      width: 375,
      dark: false,
      child: const EditSubscriptionScreen(),
    );
    expect(find.byKey(const Key('full-form-cycle-segments')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('full-form-cycle-segments')),
        matching: find.byType(CupertinoSlidingSegmentedControl<BillingCycle>),
      ),
      findsOneWidget,
    );

    await _pumpLocalized(
      tester,
      locale: const Locale('en'),
      width: 390,
      dark: true,
      child: Builder(
        builder:
            (context) => CupertinoButton(
              key: const Key('open-quick-add'),
              onPressed: () => showQuickAddSheet(context),
              child: const Text('Open'),
            ),
      ),
    );
    await tester.tap(find.byKey(const Key('open-quick-add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quick-add-cycle-segments')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('quick-add-cycle-segments')),
        matching: find.byType(CupertinoSlidingSegmentedControl<BillingCycle>),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('production Cupertino switch toggles without a manual mirror', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final locale in const [Locale('ar'), Locale('en')]) {
      for (final width in const [375.0, 390.0]) {
        for (final dark in const [false, true]) {
          await _pumpLocalized(
            tester,
            locale: locale,
            width: width,
            dark: dark,
            child: const EditSubscriptionScreen(),
          );

          final row = find.byKey(const Key('trial-switch-row'));
          await tester.scrollUntilVisible(
            row,
            260,
            scrollable: find.byType(Scrollable).first,
          );
          final switchFinder = find.descendant(
            of: row,
            matching: find.byType(CupertinoSwitch),
          );
          expect(tester.widget<CupertinoSwitch>(switchFinder).value, isFalse);
          expect(
            find.ancestor(of: switchFinder, matching: find.byType(Transform)),
            findsNothing,
          );

          await tester.tap(switchFinder);
          await tester.pump();
          expect(tester.widget<CupertinoSwitch>(switchFinder).value, isTrue);
          expect(tester.takeException(), isNull);
        }
      }
    }
  });
}
