import 'package:flutter/material.dart';

/// اشتراكاتي v16 — Gulf Aurora.
///
/// This is the single source of truth for colour, type, spacing, radius,
/// elevation and motion. The palette is intentionally calm and premium: pearl
/// surfaces, petroleum ink, Gulf emerald and a restrained sand accent.
abstract final class V16Colors {
  // Light mode.
  static const lightCanvas = Color(0xFFF7F8F4);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceMuted = Color(0xFFEEF3EF);
  static const lightSurfaceElevated = Color(0xFFFBFCFA);
  static const lightStroke = Color(0xFFD9E3DD);
  static const lightInk = Color(0xFF10231F);
  static const lightMuted = Color(0xFF63736D);

  // Dark mode.
  static const darkCanvas = Color(0xFF071410);
  static const darkSurface = Color(0xFF0E211B);
  static const darkSurfaceMuted = Color(0xFF162D26);
  static const darkSurfaceElevated = Color(0xFF19352C);
  static const darkStroke = Color(0xFF2B443B);
  static const darkInk = Color(0xFFF3F8F5);
  static const darkMuted = Color(0xFFA7BBB3);

  // Brand and semantic colours.
  static const emerald = Color(0xFF007F6D);
  static const emeraldDeep = Color(0xFF00594D);
  static const emeraldNight = Color(0xFF63DDBB);
  static const emeraldSoft = Color(0xFFDDF5EC);
  static const sand = Color(0xFFB78325);
  static const sandDeep = Color(0xFF76510D);
  static const sandNight = Color(0xFFF0C76D);
  static const coral = Color(0xFFC54D5D);
  static const coralDeep = Color(0xFF9F3044);
  static const coralNight = Color(0xFFFF909B);
  static const blue = Color(0xFF347693);
  static const blueDeep = Color(0xFF2C6781);
  static const blueNight = Color(0xFF81CAE7);
  static const white = Color(0xFFFFFFFF);
  static const transparent = Color(0x00000000);

  static const lightHero = LinearGradient(
    colors: [Color(0xFF004E44), emerald, Color(0xFF0F806E)],
    stops: [0, .58, 1],
    begin: AlignmentDirectional.topStart,
    end: AlignmentDirectional.bottomEnd,
  );

  static const darkHero = LinearGradient(
    colors: [Color(0xFF0A2A23), Color(0xFF075E50), Color(0xFF0B806B)],
    stops: [0, .62, 1],
    begin: AlignmentDirectional.topStart,
    end: AlignmentDirectional.bottomEnd,
  );
}

abstract final class V16Space {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const ml = 20.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
  static const xxxl = 64.0;
}

abstract final class V16Radius {
  static const compact = 8.0;
  static const standard = 16.0;
  static const signature = 24.0;
  static const hero = 30.0;
  static const pill = 999.0;
}

/// One bilingual scale for Arabic and Latin. IBM Plex Sans Arabic contains
/// harmonised glyphs for both scripts and is bundled with the application.
abstract final class V16Type {
  static const displayFamily = 'IBM Plex Sans Arabic';
  static const bodyFamily = 'IBM Plex Sans Arabic';
  static const fallbacks = <String>[
    'SF Arabic',
    'Geeza Pro',
    'Noto Sans Arabic',
    'sans-serif',
  ];

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

  static const captionHeight = 1.45;
  static const labelHeight = 1.45;
  static const bodyHeight = 1.55;
  static const titleHeight = 1.40;
  static const headlineHeight = 1.30;
  static const displayHeight = 1.22;

  static const regular = FontWeight.w400;
  static const semibold = FontWeight.w600;
}

abstract final class V16Elevation {
  static const flat = <BoxShadow>[];
  static const low = <BoxShadow>[
    BoxShadow(color: Color(0x1009251D), blurRadius: 18, offset: Offset(0, 6)),
  ];
  static const medium = <BoxShadow>[
    BoxShadow(color: Color(0x1609251D), blurRadius: 30, offset: Offset(0, 12)),
  ];
  static const darkLow = <BoxShadow>[
    BoxShadow(color: Color(0x66000000), blurRadius: 22, offset: Offset(0, 8)),
  ];
}

abstract final class V16Motion {
  static const instant = Duration(milliseconds: 120);
  static const quick = Duration(milliseconds: 220);
  static const entrance = Duration(milliseconds: 420);
  static const count = Duration(milliseconds: 760);
  static const standardCurve = Curves.easeOutCubic;
  static const emphasizedCurve = Curves.easeOutBack;
}

bool reduceMotion(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;

// Temporary source-compatible names. They deliberately forward to v16 so
// historical screens cannot silently drift to an older visual language while
// the migration is completed file by file.
abstract final class V12Colors {
  static const lightCanvas = V16Colors.lightCanvas;
  static const lightSurface = V16Colors.lightSurface;
  static const lightSurfaceMuted = V16Colors.lightSurfaceMuted;
  static const lightStroke = V16Colors.lightStroke;
  static const lightInk = V16Colors.lightInk;
  static const lightMuted = V16Colors.lightMuted;
  static const darkCanvas = V16Colors.darkCanvas;
  static const darkSurface = V16Colors.darkSurface;
  static const darkSurfaceMuted = V16Colors.darkSurfaceMuted;
  static const darkStroke = V16Colors.darkStroke;
  static const darkInk = V16Colors.darkInk;
  static const darkMuted = V16Colors.darkMuted;
  static const pulse = V16Colors.emerald;
  static const pulseDeep = V16Colors.emeraldDeep;
  static const pulseNight = V16Colors.emeraldNight;
  static const amber = V16Colors.sand;
  static const amberNight = V16Colors.sandNight;
  static const coral = V16Colors.coral;
  static const coralNight = V16Colors.coralNight;
  static const white = V16Colors.white;
  static const transparent = V16Colors.transparent;
}

abstract final class V12Space {
  static const xxs = V16Space.xxs;
  static const xs = V16Space.xs;
  static const sm = V16Space.sm;
  static const md = V16Space.md;
  static const lg = V16Space.lg;
  static const xl = V16Space.xl;
  static const xxl = V16Space.xxl;
}

abstract final class V12Radius {
  static const compact = V16Radius.compact;
  static const standard = V16Radius.standard;
  static const signature = V16Radius.signature;
}

abstract final class V15Type {
  static const displayFamily = V16Type.displayFamily;
  static const bodyFamily = V16Type.bodyFamily;
  static const fallbacks = V16Type.fallbacks;
  static const captionSmall = V16Type.captionSmall;
  static const caption = V16Type.caption;
  static const labelSmall = V16Type.labelSmall;
  static const label = V16Type.label;
  static const bodySmall = V16Type.bodySmall;
  static const body = V16Type.body;
  static const titleSmall = V16Type.titleSmall;
  static const title = V16Type.title;
  static const headlineSmall = V16Type.headlineSmall;
  static const headline = V16Type.headline;
  static const displaySmall = V16Type.displaySmall;
  static const display = V16Type.display;
  static const captionHeight = V16Type.captionHeight;
  static const labelHeight = V16Type.labelHeight;
  static const bodyHeight = V16Type.bodyHeight;
  static const titleHeight = V16Type.titleHeight;
  static const headlineHeight = V16Type.headlineHeight;
  static const displayHeight = V16Type.displayHeight;
  static const regular = V16Type.regular;
  static const semibold = V16Type.semibold;
}

abstract final class V12Motion {
  static const quick = V16Motion.quick;
  static const entrance = V16Motion.entrance;
  static const curve = V16Motion.standardCurve;
}
