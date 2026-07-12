import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishtirakati/screens/command_palette.dart';
import 'package:ishtirakati/widgets/adaptive_cycle_shell.dart';

void main() {
  testWidgets('صدفة الهاتف تعرض خمس وجهات والإعدادات متاحة مباشرة',
      (tester) async {
    V12Destination selected = V12Destination.home;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: AdaptiveCycleShell(
              destination: selected,
              onDestination: (value) => setState(() => selected = value),
              pages: const [
                Center(child: Text('home')),
                Center(child: Text('subscriptions')),
                Center(child: Text('insights')),
                Center(child: Text('calendar')),
                Center(child: Text('settings')),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('v12-command-button')), findsNothing);
    expect(find.byKey(const ValueKey('v12-dock-settings')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('v12-dock-subscriptions')));
    await tester.pumpAndSettle();
    expect(find.text('subscriptions'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('v12-dock-settings')));
    await tester.pumpAndSettle();
    expect(find.text('settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('صدفة iPad تتحول إلى rail وتبقي الإعدادات متاحة',
      (tester) async {
    tester.view.physicalSize = const Size(1024, 1366);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdaptiveCycleShell(
            destination: V12Destination.home,
            onDestination: (_) {},
            pages: const [
              SizedBox(),
              SizedBox(),
              SizedBox(),
              SizedBox(),
              SizedBox(),
            ],
          ),
        ),
      ),
    );

    expect(find.text('اشتراكاتي'), findsOneWidget);
    expect(find.text('الإعدادات'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
