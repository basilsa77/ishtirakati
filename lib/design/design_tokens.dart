import 'package:flutter/material.dart';

/// The single source of truth for the v12 visual system.
abstract final class V12Colors {
  static const lightCanvas = Color(0xFFF4F7F3);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceMuted = Color(0xFFEAF0EC);
  static const lightStroke = Color(0xFFD6E1DA);
  static const lightInk = Color(0xFF13231D);
  static const lightMuted = Color(0xFF60736A);

  static const darkCanvas = Color(0xFF0D1411);
  static const darkSurface = Color(0xFF151F1A);
  static const darkSurfaceMuted = Color(0xFF1D2A23);
  static const darkStroke = Color(0xFF304139);
  static const darkInk = Color(0xFFF2F7F4);
  static const darkMuted = Color(0xFFA9BBB1);

  static const pulse = Color(0xFF007D5C);
  static const pulseDeep = Color(0xFF00543E);
  static const pulseNight = Color(0xFF47D7A5);
  static const amber = Color(0xFFD79A2B);
  static const amberNight = Color(0xFFF0C56A);
  static const coral = Color(0xFFC94F5C);
  static const coralNight = Color(0xFFFF8D97);
  static const white = Color(0xFFFFFFFF);
  static const transparent = Color(0x00000000);
}

abstract final class V12Space {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

abstract final class V12Radius {
  static const compact = 4.0;
  static const standard = 8.0;
  static const signature = 14.0;
}

/// v15 bilingual type scale. IBM Plex Sans Arabic contains harmonised Arabic
/// and Latin glyphs and is bundled under the SIL Open Font License 1.1.
abstract final class V15Type {
  static const displayFamily = 'IBM Plex Sans Arabic';
  static const bodyFamily = 'IBM Plex Sans Arabic';
  static const fallbacks = <String>[
    'SF Arabic',
    'Geeza Pro',
    'Noto Sans Arabic',
    'sans-serif',
  ];

  // Size tokens. Variants remain within the six-level product type scale.
  static const captionSmall = 10.0;
  static const caption = 12.0;
  static const labelSmall = 13.0;
  static const label = 14.0;
  static const bodySmall = 15.0;
  static const body = 16.0;
  static const titleSmall = 18.0;
  static const title = 20.0;
  static const headlineSmall = 24.0;
  static const headline = 28.0;
  static const displaySmall = 36.0;
  static const display = 44.0;

  // Arabic needs more leading than Latin so marks and dots never collide.
  static const captionHeight = 1.45;
  static const labelHeight = 1.45;
  static const bodyHeight = 1.55;
  static const titleHeight = 1.40;
  static const headlineHeight = 1.30;
  static const displayHeight = 1.22;

  static const regular = FontWeight.w400;
  static const semibold = FontWeight.w600;
}

abstract final class V12Motion {
  static const quick = Duration(milliseconds: 180);
  static const entrance = Duration(milliseconds: 360);
  static const curve = Curves.easeOutCubic;
}

bool reduceMotion(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;
