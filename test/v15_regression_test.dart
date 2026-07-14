import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishtirakati/design/design_tokens.dart';
import 'package:ishtirakati/screens/edit_subscription_screen.dart';
import 'package:ishtirakati/screens/calendar_screen.dart';
import 'package:ishtirakati/screens/pulse_home_screen.dart';
import 'package:ishtirakati/screens/settings_screen.dart';
import 'package:ishtirakati/screens/subscriptions_screen.dart';
import 'package:ishtirakati/main.dart' show resolveAppThemeMode;
import 'package:ishtirakati/services/cloud_sync.dart';
import 'package:ishtirakati/theme.dart';
import 'package:ishtirakati/widgets/app_media_query.dart';

void main() {
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

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('trial-switch-row')),
      280,
      scrollable: scrollable,
    );
    final trialTitle = tester.widget<Text>(find.text('تجربة مجانية'));
    expect(trialTitle.style?.fontSize, V12Type.body);
    expect(trialTitle.maxLines, 2);

    await tester.scrollUntilVisible(
      find.byKey(const Key('family-switch-row')),
      180,
      scrollable: scrollable,
    );
    final familyTitle = tester.widget<Text>(find.text('اشتراك عائلي / مشترك'));
    expect(familyTitle.style?.fontSize, V12Type.body);
    expect(familyTitle.maxLines, 2);

    await tester.scrollUntilVisible(
      find.byKey(const Key('plan-name-field')),
      220,
      scrollable: scrollable,
    );
    final planField = tester.widget<CupertinoTextFormFieldRow>(
      find.byKey(const Key('plan-name-field')),
    );
    expect(planField.style?.fontSize, V12Type.body);
    expect(planField.placeholderStyle?.fontSize, V12Type.body);
    expect(tester.takeException(), isNull);
  });
}
