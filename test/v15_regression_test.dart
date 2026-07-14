import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishtirakati/screens/edit_subscription_screen.dart';
import 'package:ishtirakati/screens/calendar_screen.dart';
import 'package:ishtirakati/screens/pulse_home_screen.dart';
import 'package:ishtirakati/screens/settings_screen.dart';
import 'package:ishtirakati/screens/subscriptions_screen.dart';
import 'package:ishtirakati/main.dart' show resolveAppThemeMode;
import 'package:ishtirakati/services/cloud_sync.dart';
import 'package:ishtirakati/theme.dart';
import 'package:ishtirakati/widgets/app_material_root.dart';
import 'package:ishtirakati/widgets/app_media_query.dart';

void main() {
  testWidgets('app root provides Material and themed text to every route',
      (tester) async {
    TextStyle? inheritedStyle;
    TextStyle? routeStyle;
    TextStyle? overlayStyle;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        builder: (context, child) => AppMaterialRoot(child: child!),
        home: Builder(
          builder: (context) {
            inheritedStyle = DefaultTextStyle.of(context).style;
            return Column(
              children: [
                const Text('نص موروث من الثيم'),
                TextButton(
                  key: const Key('open-cupertino-route'),
                  onPressed: () => Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder: (_) => Builder(
                        builder: (routeContext) {
                          routeStyle = DefaultTextStyle.of(routeContext).style;
                          return const Text('نص داخل مسار Cupertino');
                        },
                      ),
                    ),
                  ),
                  child: const Text('فتح مسار'),
                ),
                TextButton(
                  key: const Key('open-overlay'),
                  onPressed: () => showCupertinoModalPopup<void>(
                    context: context,
                    builder: (overlayContext) {
                      overlayStyle =
                          DefaultTextStyle.of(overlayContext).style;
                      return const Align(
                        alignment: Alignment.bottomCenter,
                        child: Text('نص داخل Overlay'),
                      );
                    },
                  ),
                  child: const Text('فتح طبقة'),
                ),
              ],
            );
          },
        ),
      ),
    );

    final text = find.text('نص موروث من الثيم');
    expect(text, findsOneWidget);
    expect(
      find.ancestor(of: text, matching: find.byType(Material)),
      findsWidgets,
    );
    expect(inheritedStyle?.fontSize, V15Type.body);
    expect(inheritedStyle?.decoration, isNot(TextDecoration.underline));
    expect(inheritedStyle?.decorationStyle, isNot(TextDecorationStyle.double));

    await tester.tap(find.byKey(const Key('open-cupertino-route')));
    await tester.pumpAndSettle();
    final routeText = find.text('نص داخل مسار Cupertino');
    expect(routeText, findsOneWidget);
    expect(
      find.ancestor(of: routeText, matching: find.byType(Material)),
      findsWidgets,
    );
    expect(routeStyle?.fontSize, V15Type.body);
    expect(routeStyle?.decoration, isNot(TextDecoration.underline));
    expect(routeStyle?.decorationStyle, isNot(TextDecorationStyle.double));

    Navigator.of(tester.element(routeText)).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-overlay')));
    await tester.pumpAndSettle();
    final overlayText = find.text('نص داخل Overlay');
    expect(overlayText, findsOneWidget);
    expect(
      find.ancestor(of: overlayText, matching: find.byType(Material)),
      findsWidgets,
    );
    expect(overlayStyle?.fontSize, V15Type.body);
    expect(overlayStyle?.decoration, isNot(TextDecoration.underline));
    expect(overlayStyle?.decorationStyle, isNot(TextDecorationStyle.double));
  });

  testWidgets('v15 limits extreme iOS text scaling without disabling it',
      (tester) async {
    double? scaled;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(3.2)),
          child: AppMediaQuery(
            child: Builder(
              builder: (context) {
                scaled = MediaQuery.textScalerOf(context).scale(10) / 10;
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );

    expect(scaled, 1.4);
  });

  testWidgets('v15 primary pages render on a small iPhone with large text',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final pages = <Widget>[
      PulseHomeScreen(
        onOpenCommands: () {},
        onOpenLibrary: () {},
        onOpenRenewals: () {},
      ),
      const SubscriptionsScreen(),
      const CalendarScreen(),
      const SettingsScreen(),
    ];

    for (final page in pages) {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          darkTheme: buildAppTheme(dark: true),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              textScaler: TextScaler.linear(3.2),
            ),
            child: AppMediaQuery(child: page),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '${page.runtimeType}');
    }
  });

  test('v15 gives actionable Firebase synchronization errors', () {
    expect(
      CloudSync.messageForFirebaseCode('permission-denied'),
      contains('App Check'),
    );
    expect(
      CloudSync.messageForFirebaseCode('unavailable'),
      contains('الإنترنت'),
    );
    expect(
      CloudSync.messageForFirebaseCode('unauthenticated'),
      contains('سجّل الدخول'),
    );
  });

  test('theme preference resolves every appearance mode explicitly', () {
    expect(resolveAppThemeMode('system'), ThemeMode.system);
    expect(resolveAppThemeMode('dark'), ThemeMode.dark);
    expect(resolveAppThemeMode('light'), ThemeMode.light);
    expect(resolveAppThemeMode('unexpected'), ThemeMode.system);
  });

  testWidgets('calendar segment opens and closes the calendar grid',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const CalendarScreen(),
      ),
    );

    expect(find.byKey(const Key('renewals-calendar-grid')), findsNothing);
    await tester.tap(find.byKey(const Key('renewals-calendar-option')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('renewals-calendar-grid')), findsOneWidget);

    await tester.tap(find.byKey(const Key('renewals-timeline-option')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('renewals-calendar-grid')), findsNothing);
  });

  testWidgets('subscription form keeps switch and plan labels on body scale',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        builder: (context, child) => AppMaterialRoot(child: child!),
        home: const MediaQuery(
          data: MediaQueryData(
            size: Size(390, 844),
            textScaler: TextScaler.linear(3.2),
          ),
          child: AppMediaQuery(child: EditSubscriptionScreen()),
        ),
      ),
    );
    await tester.pump();

    final renewalCycle = find.text('دورة التجديد');
    expect(renewalCycle, findsOneWidget);
    final renewalCycleText = tester.widget<Text>(renewalCycle);
    final renewalCycleContext = tester.element(renewalCycle);
    final renewalCycleStyle = DefaultTextStyle.of(renewalCycleContext)
        .style
        .merge(renewalCycleText.style);
    expect(renewalCycleStyle.fontSize, V15Type.body);
    expect(
      renewalCycleStyle.decoration,
      isNot(TextDecoration.underline),
    );
    expect(
      renewalCycleStyle.decorationStyle,
      isNot(TextDecorationStyle.double),
    );

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('trial-switch-row')),
      280,
      scrollable: scrollable,
    );
    final trialTitle = tester.widget<Text>(find.text('تجربة مجانية'));
    expect(trialTitle.style?.fontSize, V15Type.body);
    expect(trialTitle.maxLines, 2);

    await tester.scrollUntilVisible(
      find.byKey(const Key('family-switch-row')),
      180,
      scrollable: scrollable,
    );
    final familyTitle = tester.widget<Text>(find.text('اشتراك عائلي / مشترك'));
    expect(familyTitle.style?.fontSize, V15Type.body);
    expect(familyTitle.maxLines, 2);

    await tester.scrollUntilVisible(
      find.byKey(const Key('plan-name-field')),
      220,
      scrollable: scrollable,
    );
    final planEditor = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('plan-name-field')),
        matching: find.byType(EditableText),
      ),
    );
    expect(planEditor.style.fontSize, V15Type.body);
    expect(tester.takeException(), isNull);
  });
}
