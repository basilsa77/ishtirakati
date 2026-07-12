import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishtirakati/models/subscription.dart';
import 'package:ishtirakati/theme.dart';
import 'package:ishtirakati/widgets/renewal_orbit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final display = FontLoader('Tajawal')
      ..addFont(rootBundle.load('assets/fonts/tajawal/Tajawal-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/tajawal/Tajawal-Bold.ttf'));
    final body = FontLoader('IBM Plex Sans Arabic')
      ..addFont(rootBundle.load(
        'assets/fonts/ibm_plex_sans_arabic/IBMPlexSansArabic-Regular.ttf',
      ))
      ..addFont(rootBundle.load(
        'assets/fonts/ibm_plex_sans_arabic/IBMPlexSansArabic-SemiBold.ttf',
      ));
    await Future.wait([display.load(), body.load()]);
  });

  final items = [
    Subscription(
      id: 'netflix',
      name: 'Netflix',
      emoji: 'N',
      price: 55.99,
      currency: 'SAR',
      cycle: BillingCycle.monthly,
      anchorDate: DateTime(2025, 1, 7),
      category: 'ترفيه ومشاهدة',
    ),
    Subscription(
      id: 'cloud',
      name: 'Cloud',
      emoji: 'C',
      price: 75,
      currency: 'SAR',
      cycle: BillingCycle.monthly,
      anchorDate: DateTime(2025, 1, 18),
      category: 'إنتاجية وذكاء اصطناعي',
      usageCount: 4,
    ),
  ];

  for (final brightness in [Brightness.light, Brightness.dark]) {
    for (final direction in [TextDirection.rtl, TextDirection.ltr]) {
      final mode = brightness.name;
      final dir = direction.name;
      testWidgets('مدار v12 $mode $dir', (tester) async {
        tester.view.physicalSize = const Size(390, 520);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            darkTheme: buildAppTheme(dark: true),
            themeMode: brightness == Brightness.dark
                ? ThemeMode.dark
                : ThemeMode.light,
            home: Directionality(
              textDirection: direction,
              child: Scaffold(
                body: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: RenewalOrbit(
                      subscriptions: items,
                      annualCost: 1571.88,
                      currency: 'SAR',
                      now: DateTime(2026, 7, 12),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/v12_orbit_${mode}_$dir.png'),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
