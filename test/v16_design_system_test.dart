import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishtirakati/theme.dart';

double _contrast(Color first, Color second) {
  final light = first.computeLuminance();
  final dark = second.computeLuminance();
  final high = light > dark ? light : dark;
  final low = light > dark ? dark : light;
  return (high + .05) / (low + .05);
}

void main() {
  test('v16 palettes keep readable primary and secondary text', () {
    expect(
      _contrast(AppPalette.light.text, AppPalette.light.canvas),
      greaterThanOrEqualTo(7),
    );
    expect(
      _contrast(AppPalette.light.textMuted, AppPalette.light.canvas),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(AppPalette.dark.text, AppPalette.dark.canvas),
      greaterThanOrEqualTo(7),
    );
    expect(
      _contrast(AppPalette.dark.textMuted, AppPalette.dark.canvas),
      greaterThanOrEqualTo(4.5),
    );
    for (final palette in [AppPalette.light, AppPalette.dark]) {
      expect(
        _contrast(palette.accent, palette.accentSoft),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(palette.warning, palette.warningSoft),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(palette.danger, palette.dangerSoft),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(palette.accentStrong, V16Colors.white),
        greaterThanOrEqualTo(4.5),
      );
    }
    for (final color in [
      ...V16Colors.lightHero.colors,
      ...V16Colors.darkHero.colors,
    ]) {
      expect(_contrast(color, V16Colors.white), greaterThanOrEqualTo(4.5));
    }
  });

  test('Material and Cupertino inherit the single bundled type family', () {
    final light = buildAppTheme();
    final dark = buildAppTheme(dark: true);

    expect(light.textTheme.bodyLarge?.fontFamily, V16Type.bodyFamily);
    expect(dark.textTheme.bodyLarge?.fontFamily, V16Type.bodyFamily);
    expect(
      light.cupertinoOverrideTheme?.textTheme?.textStyle.fontFamily,
      V16Type.bodyFamily,
    );
    expect(light.extension<AppPalette>()?.accent, V16Colors.emeraldDeep);
    expect(dark.extension<AppPalette>()?.accent, V16Colors.emeraldNight);
    expect(
      _contrast(dark.colorScheme.error, dark.colorScheme.onError),
      greaterThanOrEqualTo(4.5),
    );
    expect(V15Type.body, V16Type.body);
  });

  testWidgets('AnimatedMoney displays its final value with reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: AnimatedMoney(
              value: 125,
              currency: 'SAR',
              style: TextStyle(fontSize: V16Type.title),
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('125'), findsOneWidget);
    expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
  });

  testWidgets('AnimatedMoney animates safely when motion is enabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(
          body: AnimatedMoney(
            value: 125,
            currency: 'SAR',
            style: TextStyle(fontSize: V16Type.title),
          ),
        ),
      ),
    );

    expect(find.byType(TweenAnimationBuilder<double>), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.textContaining('125'), findsOneWidget);
  });
}
