/// الهوية البصرية الحديثة لتطبيق «اشتراكاتي».
library;

export 'design/design_tokens.dart'
    show
        V12Colors,
        V12Motion,
        V12Radius,
        V12Space,
        V15Type,
        V16Colors,
        V16Elevation,
        V16Motion,
        V16Radius,
        V16Space,
        V16Type,
        reduceMotion;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'data/service_domains.dart';
import 'design/design_tokens.dart';
import 'l10n/app_localizations.dart';

class AppColors {
  AppColors._();

  // خلفيات
  static const Color bg = V12Colors.lightCanvas;
  static const Color card = V12Colors.lightSurface;
  static const Color cardAlt = V12Colors.lightSurfaceMuted;
  static const Color border = V12Colors.lightStroke;

  // نصوص
  static const Color ink = V12Colors.lightInk;
  static const Color muted = V12Colors.lightMuted;

  // الهوية
  static const Color primary = V12Colors.pulse;
  static const Color primaryDeep = V12Colors.pulseDeep;
  static const Color primarySoft = V16Colors.emeraldSoft;

  static const Color gold = V12Colors.amber;
  static const Color goldDeep = V12Colors.amber;
  static const Color goldSoft = Color(0xFFFFF4D9);

  static const Color danger = V12Colors.coral;
  static const Color dangerSoft = Color(0xFFFFE8EA);
  static const Color warn = V16Colors.sand;

  // ألوان السطح الليلي، مع إبقاء الهوية الخضراء نفسها.
  static const Color darkBg = V12Colors.darkCanvas;
  static const Color darkCard = V12Colors.darkSurface;
  static const Color darkCardAlt = V12Colors.darkSurfaceMuted;
  static const Color darkBorder = V12Colors.darkStroke;
  static const Color darkInk = V12Colors.darkInk;
  static const Color darkMuted = V12Colors.darkMuted;

  /// تدرج البطاقة الرئيسية.
  static const LinearGradient heroGradient = V16Colors.lightHero;
}

/// Semantic v16 colours read from the active theme so every Cupertino and
/// Material surface follows the same light/dark contract.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color canvas;
  final Color surface;
  final Color surfaceAlt;
  final Color stroke;
  final Color text;
  final Color textMuted;
  final Color accent;
  final Color accentStrong;
  final Color accentSoft;
  final Color danger;
  final Color dangerSoft;
  final Color warning;
  final Color warningSoft;
  final Color shadow;

  const AppPalette({
    required this.canvas,
    required this.surface,
    required this.surfaceAlt,
    required this.stroke,
    required this.text,
    required this.textMuted,
    required this.accent,
    required this.accentStrong,
    required this.accentSoft,
    required this.danger,
    required this.dangerSoft,
    required this.warning,
    required this.warningSoft,
    required this.shadow,
  });

  static const light = AppPalette(
    canvas: V16Colors.lightCanvas,
    surface: V16Colors.lightSurface,
    surfaceAlt: V16Colors.lightSurfaceMuted,
    stroke: V16Colors.lightStroke,
    text: V16Colors.lightInk,
    textMuted: V16Colors.lightMuted,
    accent: V16Colors.emeraldDeep,
    accentStrong: V16Colors.emeraldDeep,
    accentSoft: V16Colors.emeraldSoft,
    danger: V16Colors.coralDeep,
    dangerSoft: Color(0xFFFFE9EC),
    warning: V16Colors.sandDeep,
    warningSoft: Color(0xFFFFF3D7),
    shadow: Color(0x1209251D),
  );

  static const dark = AppPalette(
    canvas: V16Colors.darkCanvas,
    surface: V16Colors.darkSurface,
    surfaceAlt: V16Colors.darkSurfaceMuted,
    stroke: V16Colors.darkStroke,
    text: V16Colors.darkInk,
    textMuted: V16Colors.darkMuted,
    accent: V16Colors.emeraldNight,
    accentStrong: V16Colors.emerald,
    accentSoft: Color(0xFF173E33),
    danger: V16Colors.coralNight,
    dangerSoft: Color(0xFF40252A),
    warning: V16Colors.sandNight,
    warningSoft: Color(0xFF42361D),
    shadow: Color(0x66000000),
  );

  @override
  AppPalette copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceAlt,
    Color? stroke,
    Color? text,
    Color? textMuted,
    Color? accent,
    Color? accentStrong,
    Color? accentSoft,
    Color? danger,
    Color? dangerSoft,
    Color? warning,
    Color? warningSoft,
    Color? shadow,
  }) => AppPalette(
    canvas: canvas ?? this.canvas,
    surface: surface ?? this.surface,
    surfaceAlt: surfaceAlt ?? this.surfaceAlt,
    stroke: stroke ?? this.stroke,
    text: text ?? this.text,
    textMuted: textMuted ?? this.textMuted,
    accent: accent ?? this.accent,
    accentStrong: accentStrong ?? this.accentStrong,
    accentSoft: accentSoft ?? this.accentSoft,
    danger: danger ?? this.danger,
    dangerSoft: dangerSoft ?? this.dangerSoft,
    warning: warning ?? this.warning,
    warningSoft: warningSoft ?? this.warningSoft,
    shadow: shadow ?? this.shadow,
  );

  @override
  AppPalette lerp(covariant AppPalette? other, double t) {
    if (other == null) return this;
    return AppPalette(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      stroke: Color.lerp(stroke, other.stroke, t)!,
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentStrong: Color.lerp(accentStrong, other.accentStrong, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

extension AppPaletteContext on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}

extension AppPaletteVisuals on AppPalette {
  bool get isDark => canvas.computeLuminance() < .2;

  LinearGradient get heroGradient =>
      isDark ? V16Colors.darkHero : V16Colors.lightHero;

  List<BoxShadow> get cardShadow =>
      isDark ? V16Elevation.darkLow : V16Elevation.low;
}

/// ألوان مميزة لكل تصنيف (تُستخدم في الرسوم والقوائم).
const Map<String, Color> kCategoryColors = {
  'ترفيه ومشاهدة': Color(0xFFD1495B),
  'موسيقى وبودكاست': Color(0xFF7B2CBF),
  'إنتاجية وذكاء اصطناعي': Color(0xFF00876C),
  'ألعاب': Color(0xFF2F6FED),
  'رياضة وصحة': Color(0xFFE07A00),
  'تعليم': Color(0xFF008FA3),
  'تسوق وتوصيل': Color(0xFFC13C82),
  'اتصالات وإنترنت': Color(0xFF4C8C2B),
  'تخزين سحابي': Color(0xFF6B7280),
  'مالية وفواتير': Color(0xFFB59B00),
  'أخبار ومجلات': Color(0xFF5B5BD6),
  'أخرى': Color(0xFF5D4037),
};

Color categoryColor(String category) =>
    kCategoryColors[category] ?? AppColors.gold;

TextTheme _appTextTheme(AppPalette palette) {
  TextStyle style(
    double size,
    double height, {
    FontWeight weight = V15Type.regular,
    Color? color,
  }) => TextStyle(
    color: color ?? palette.text,
    fontFamily: V15Type.bodyFamily,
    fontFamilyFallback: V15Type.fallbacks,
    fontSize: size,
    height: height,
    fontWeight: weight,
    letterSpacing: 0,
  );

  return TextTheme(
    displayLarge: style(
      V15Type.display,
      V15Type.displayHeight,
      weight: V15Type.semibold,
    ),
    displayMedium: style(
      V15Type.displaySmall,
      V15Type.displayHeight,
      weight: V15Type.semibold,
    ),
    headlineLarge: style(
      V15Type.headline,
      V15Type.headlineHeight,
      weight: V15Type.semibold,
    ),
    headlineMedium: style(
      V15Type.headlineSmall,
      V15Type.headlineHeight,
      weight: V15Type.semibold,
    ),
    titleLarge: style(
      V15Type.title,
      V15Type.titleHeight,
      weight: V15Type.semibold,
    ),
    titleMedium: style(
      V15Type.titleSmall,
      V15Type.titleHeight,
      weight: V15Type.semibold,
    ),
    bodyLarge: style(V15Type.body, V15Type.bodyHeight),
    bodyMedium: style(V15Type.bodySmall, V15Type.bodyHeight),
    labelLarge: style(
      V15Type.label,
      V15Type.labelHeight,
      weight: V15Type.semibold,
    ),
    labelMedium: style(
      V15Type.labelSmall,
      V15Type.labelHeight,
      weight: V15Type.semibold,
    ),
    bodySmall: style(
      V15Type.caption,
      V15Type.captionHeight,
      color: palette.textMuted,
    ),
    labelSmall: style(
      V15Type.captionSmall,
      V15Type.captionHeight,
      weight: V15Type.semibold,
      color: palette.textMuted,
    ),
  );
}

ThemeData buildAppTheme({bool dark = false}) {
  final palette = dark ? AppPalette.dark : AppPalette.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: palette.accent,
    brightness: dark ? Brightness.dark : Brightness.light,
  ).copyWith(
    primary: palette.accentStrong,
    onPrimary: V16Colors.white,
    primaryContainer: palette.accentSoft,
    onPrimaryContainer: palette.text,
    secondary: palette.warning,
    onSecondary: dark ? V16Colors.darkCanvas : V16Colors.lightInk,
    secondaryContainer: palette.warningSoft,
    onSecondaryContainer: palette.text,
    surface: palette.surface,
    onSurface: palette.text,
    error: palette.danger,
    onError: dark ? V16Colors.darkCanvas : V16Colors.white,
    outline: palette.stroke,
    shadow: palette.shadow,
  );

  final surface = palette.surface;
  final border = palette.stroke;
  final onSurface = palette.text;
  final muted = palette.textMuted;
  final base = ThemeData(
    useMaterial3: true,
    platform: TargetPlatform.iOS,
    brightness: dark ? Brightness.dark : Brightness.light,
    colorScheme: scheme,
    fontFamily: V16Type.bodyFamily,
    fontFamilyFallback: V16Type.fallbacks,
    extensions: [palette],
  );

  return base.copyWith(
    cupertinoOverrideTheme: CupertinoThemeData(
      brightness: dark ? Brightness.dark : Brightness.light,
      primaryColor: palette.accent,
      primaryContrastingColor: dark ? V16Colors.darkCanvas : V16Colors.white,
      scaffoldBackgroundColor: palette.canvas,
      barBackgroundColor: palette.surface,
      textTheme: CupertinoTextThemeData(
        textStyle: TextStyle(
          color: palette.text,
          fontSize: V16Type.body,
          height: V16Type.bodyHeight,
          fontFamily: V16Type.bodyFamily,
          fontFamilyFallback: V16Type.fallbacks,
        ),
      ),
    ),
    textTheme: _appTextTheme(palette),
    scaffoldBackgroundColor: palette.canvas,
    appBarTheme: AppBarTheme(
      backgroundColor: palette.canvas,
      foregroundColor: onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 68,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: onSurface,
        fontSize: V16Type.title,
        fontWeight: V16Type.semibold,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: palette.accentStrong,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(54),
        textStyle: const TextStyle(
          fontSize: V16Type.body,
          fontWeight: V16Type.semibold,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(V16Radius.standard),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.accent,
        side: BorderSide(color: palette.accent, width: 1.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(V16Radius.standard),
        ),
        textStyle: const TextStyle(fontWeight: V16Type.semibold),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: palette.accent),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      hintStyle: TextStyle(color: muted),
      labelStyle: TextStyle(color: muted),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: V16Space.md,
        vertical: V16Space.md,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(V16Radius.standard),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(V16Radius.standard),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(V16Radius.standard),
        borderSide: BorderSide(color: palette.accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(V16Radius.standard),
        borderSide: BorderSide(color: palette.danger),
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(V16Radius.standard),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: dark ? palette.surfaceAlt : palette.text,
      contentTextStyle: const TextStyle(
        color: V16Colors.white,
        fontSize: V16Type.bodySmall,
      ),
      behavior: SnackBarBehavior.floating,
      insetPadding: const EdgeInsets.all(V16Space.md),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(V16Radius.standard),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: palette.accentStrong,
      foregroundColor: V16Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(V16Radius.standard),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      titleTextStyle: TextStyle(
        color: onSurface,
        fontSize: V16Type.titleSmall,
        fontWeight: V16Type.semibold,
      ),
      contentTextStyle: TextStyle(
        color: muted,
        fontSize: V16Type.bodySmall,
        height: V16Type.bodyHeight,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(V16Radius.signature),
      ),
    ),
    dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
    dividerColor: border,
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: palette.surface,
      selectedItemColor: palette.accent,
      unselectedItemColor: palette.textMuted,
      selectedLabelStyle: const TextStyle(fontWeight: V16Type.semibold),
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: palette.accent,
      linearTrackColor: palette.surfaceAlt,
      circularTrackColor: palette.surfaceAlt,
    ),
  );
}

enum AppCardTone { standard, muted, accent, warning, danger }

/// The single card primitive used across v16. It supports restrained elevation,
/// semantic tap targets and the brand gradient without forcing screen-specific
/// shadows or radii.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final Gradient? gradient;
  final AppCardTone tone;
  final VoidCallback? onTap;
  final String? semanticsLabel;
  final bool elevated;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(V16Space.md),
    this.color,
    this.borderColor,
    this.gradient,
    this.tone = AppCardTone.standard,
    this.onTap,
    this.semanticsLabel,
    this.elevated = true,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final effectiveGradient =
        gradient ?? (tone == AppCardTone.accent ? palette.heroGradient : null);
    final effectiveColor =
        color ??
        switch (tone) {
          AppCardTone.standard => palette.surface,
          AppCardTone.muted => palette.surfaceAlt,
          AppCardTone.accent => null,
          AppCardTone.warning => palette.warningSoft,
          AppCardTone.danger => palette.dangerSoft,
        };
    final effectiveBorder =
        borderColor ??
        switch (tone) {
          AppCardTone.standard => palette.stroke,
          AppCardTone.muted => palette.stroke,
          AppCardTone.accent => V16Colors.white.withValues(alpha: .16),
          AppCardTone.warning => palette.warning.withValues(alpha: .28),
          AppCardTone.danger => palette.danger.withValues(alpha: .28),
        };

    final card = AnimatedContainer(
      duration: reduceMotion(context) ? Duration.zero : V16Motion.quick,
      curve: V16Motion.standardCurve,
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: effectiveGradient == null ? effectiveColor : null,
        gradient: effectiveGradient,
        borderRadius: BorderRadius.circular(V16Radius.standard),
        border: Border.all(color: effectiveBorder),
        boxShadow: elevated ? palette.cardShadow : V16Elevation.flat,
      ),
      child: child,
    );

    if (onTap == null) return card;
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: CupertinoButton(
        onPressed: onTap,
        padding: EdgeInsets.zero,
        pressedOpacity: .82,
        borderRadius: BorderRadius.circular(V16Radius.standard),
        child: card,
      ),
    );
  }
}

/// عنوان قسم موحّد.
class SectionTitle extends StatelessWidget {
  final String text;
  final String? emoji;

  const SectionTitle(this.text, {super.key, this.emoji});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        bottom: V16Space.sm,
        top: V16Space.xxs,
      ),
      child: Row(
        children: [
          if (emoji != null) ...[
            Text(emoji!, style: const TextStyle(fontSize: V16Type.titleSmall)),
            const SizedBox(width: V16Space.xs),
          ],
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: V16Type.titleSmall,
                fontWeight: V16Type.semibold,
                color: context.palette.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// An accessible amount transition. Currency formatting remains isolated per
/// value and reduced-motion users get the final value immediately.
class AnimatedMoney extends StatelessWidget {
  final double value;
  final String currency;
  final TextStyle style;

  const AnimatedMoney({
    super.key,
    required this.value,
    required this.currency,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final digits = value == value.roundToDouble() ? 0 : 2;
    final finalText = context.l10n.money(
      value,
      currency,
      decimalDigits: digits,
    );
    if (reduceMotion(context)) {
      return Text(finalText, style: style);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: V16Motion.count,
      curve: V16Motion.standardCurve,
      builder: (context, v, _) {
        return Semantics(
          label: finalText,
          excludeSemantics: true,
          child: Text(
            context.l10n.money(v, currency, decimalDigits: digits),
            style: style,
          ),
        );
      },
    );
  }
}

/// شارة أيام التجديد: اليوم/غدًا/بعد X يوم بألوان تحذيرية متدرجة.
class RenewalBadge extends StatelessWidget {
  final int days;

  const RenewalBadge({super.key, required this.days});

  @override
  Widget build(BuildContext context) {
    final String text;
    final Color bg;
    final Color fg;
    if (days <= 0) {
      text = localizedDaysAfter(days);
      bg = context.palette.dangerSoft;
      fg = context.palette.danger;
    } else if (days == 1) {
      text = localizedDaysAfter(days);
      bg = context.palette.dangerSoft;
      fg = context.palette.danger;
    } else if (days <= 7) {
      text = localizedDaysAfter(days);
      bg = context.palette.warningSoft;
      fg = context.palette.warning;
    } else {
      text = localizedDaysAfter(days);
      bg = context.palette.accentSoft;
      fg = context.palette.accent;
    }
    return Semantics(
      label: text,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: V16Space.sm,
          vertical: V16Space.xxs,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(V16Radius.pill),
          border: Border.all(color: fg.withValues(alpha: .18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: V16Space.xs),
            Text(
              text,
              style: TextStyle(
                color: fg,
                fontSize: V16Type.caption,
                fontWeight: V16Type.semibold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// دخول متدرج للعناصر (fade + انزلاق خفيف) بدون أي حزم خارجية.
class FadeSlideIn extends StatelessWidget {
  final Widget child;
  final int delayMs;

  const FadeSlideIn({super.key, required this.child, this.delayMs = 0});

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: V16Motion.entrance + Duration(milliseconds: delayMs),
      curve: V16Motion.standardCurve,
      builder: (context, t, c) {
        final clamped = t.clamp(0.0, 1.0);
        return Opacity(
          opacity: clamped,
          child: Transform.translate(
            offset: Offset(0, V16Space.sm * (1 - clamped)),
            child: c,
          ),
        );
      },
      child: child,
    );
  }
}

/// A responsive title block shared by top-level screens and modal editors.
class AppPageIntro extends StatelessWidget {
  final String title;
  final String? description;
  final String? eyebrow;
  final Widget? trailing;

  const AppPageIntro({
    super.key,
    required this.title,
    this.description,
    this.eyebrow,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrow case final value?) ...[
          Text(
            value,
            style: TextStyle(
              color: context.palette.accent,
              fontSize: V16Type.labelSmall,
              fontWeight: V16Type.semibold,
            ),
          ),
          const SizedBox(height: V16Space.xxs),
        ],
        Text(
          title,
          style: TextStyle(
            color: context.palette.text,
            fontFamily: V16Type.displayFamily,
            fontFamilyFallback: V16Type.fallbacks,
            fontSize: V16Type.headline,
            height: V16Type.headlineHeight,
            fontWeight: V16Type.semibold,
          ),
        ),
        if (description case final value?) ...[
          const SizedBox(height: V16Space.xs),
          Text(
            value,
            style: TextStyle(
              color: context.palette.textMuted,
              fontSize: V16Type.bodySmall,
              height: V16Type.bodyHeight,
            ),
          ),
        ],
      ],
    );
    if (trailing == null) return copy;
    return LayoutBuilder(
      builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.2;
        if (largeText || constraints.maxWidth < 420) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              copy,
              const SizedBox(height: V16Space.md),
              Align(alignment: AlignmentDirectional.centerEnd, child: trailing),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: copy),
            const SizedBox(width: V16Space.md),
            trailing!,
          ],
        );
      },
    );
  }
}

/// Empty state with a quiet illustrated tile and one optional primary action.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => AppCard(
    tone: AppCardTone.muted,
    elevated: false,
    padding: const EdgeInsets.all(V16Space.xl),
    child: Column(
      children: [
        Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: context.palette.accentSoft,
            borderRadius: BorderRadius.circular(V16Radius.signature),
          ),
          child: Icon(icon, color: context.palette.accent, size: 34),
        ),
        const SizedBox(height: V16Space.lg),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.palette.text,
            fontSize: V16Type.title,
            fontWeight: V16Type.semibold,
          ),
        ),
        const SizedBox(height: V16Space.xs),
        Text(
          description,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.palette.textMuted,
            fontSize: V16Type.bodySmall,
            height: V16Type.bodyHeight,
          ),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: V16Space.lg),
          CupertinoButton.filled(
            onPressed: onAction,
            borderRadius: BorderRadius.circular(V16Radius.standard),
            child: Text(actionLabel!),
          ),
        ],
      ],
    ),
  );
}

/// Accessible chart container. Painters remain screen-owned, while title,
/// explanation, contrast and semantic summary are consistent everywhere.
class AppChartSurface extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String semanticsLabel;
  final Widget child;
  final Widget? legend;

  const AppChartSurface({
    super.key,
    required this.title,
    required this.semanticsLabel,
    required this.child,
    this.subtitle,
    this.legend,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: semanticsLabel,
    child: AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: context.palette.text,
              fontSize: V16Type.titleSmall,
              fontWeight: V16Type.semibold,
            ),
          ),
          if (subtitle case final value?) ...[
            const SizedBox(height: V16Space.xxs),
            Text(
              value,
              style: TextStyle(
                color: context.palette.textMuted,
                fontSize: V16Type.caption,
              ),
            ),
          ],
          const SizedBox(height: V16Space.lg),
          ExcludeSemantics(child: child),
          if (legend case final value?) ...[
            const SizedBox(height: V16Space.md),
            value,
          ],
        ],
      ),
    ),
  );
}

class AppMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? accent;

  const AppMetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? context.palette.accent;
    return AppCard(
      elevated: false,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(V16Radius.compact),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: V16Space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: context.palette.textMuted,
                    fontSize: V16Type.caption,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.palette.text,
                    fontSize: V16Type.titleSmall,
                    fontWeight: V16Type.semibold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String fmtDate(DateTime d) => localizedDate(d);

/// أيقونة الخدمة: الشعار الرسمي إن عُرف نطاقها، وإلا رمز تطبيق محايد.
class ServiceAvatar extends StatelessWidget {
  final String name;
  final String emoji;
  final String manageUrl;
  final Color tint;
  final double size;
  final String iconUrl;

  const ServiceAvatar({
    super.key,
    required this.name,
    required this.emoji,
    required this.manageUrl,
    required this.tint,
    this.size = 46,
    this.iconUrl = '',
  });

  @override
  Widget build(BuildContext context) {
    final url = iconUrl.isNotEmpty ? iconUrl : logoUrlFor(name, manageUrl);
    final fallback =
        emoji.trim().isNotEmpty
            ? Text(emoji, style: const TextStyle(fontSize: V16Type.title))
            : Icon(Icons.apps_rounded, color: tint, size: size * 0.48);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(V16Radius.compact),
        border: Border.all(color: tint.withValues(alpha: 0.35)),
      ),
      child:
          url == null
              ? fallback
              : ClipRRect(
                borderRadius: BorderRadius.circular(V16Radius.compact),
                child: Image.network(
                  url,
                  width: size * 0.58,
                  height: size * 0.58,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => fallback,
                ),
              ),
    );
  }
}
