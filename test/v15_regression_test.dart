import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishtirakati/screens/calendar_screen.dart';
import 'package:ishtirakati/screens/pulse_home_screen.dart';
import 'package:ishtirakati/screens/settings_screen.dart';
import 'package:ishtirakati/screens/subscriptions_screen.dart';
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
}
