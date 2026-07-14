/// الهوية البصرية الحديثة لتطبيق «اشتراكاتي».
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'data/service_domains.dart';
import 'design/design_tokens.dart';

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
  static const Color primarySoft = Color(0xFFE2F4ED);

  static const Color gold = V12Colors.amber;
  static const Color goldDeep = V12Colors.amber;
  static const Color goldSoft = Color(0xFFFFF4D9);

  static const Color danger = V12Colors.coral;
  static const Color dangerSoft = Color(0xFFFFE8EA);
  static const Color warn = Color(0xFFF5B84F);

  // ألوان السطح الليلي، مع إبقاء الهوية الخضراء نفسها.
  static const Color darkBg = V12Colors.darkCanvas;
  static const Color darkCard = V12Colors.darkSurface;
  static const Color darkCardAlt = V12Colors.darkSurfaceMuted;
  static const Color darkBorder = V12Colors.darkStroke;
  static const Color darkInk = V12Colors.darkInk;
  static const Color darkMuted = V12Colors.darkMuted;

  /// تدرج البطاقة الرئيسية.
  static const LinearGradient heroGradient = LinearGradient(
    colors: [AppColors.primaryDeep, AppColors.primary],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );
}

/// رموز ألوان الإصدار 8. تُقرأ من الثيم الحالي لكي يكون الوضع الليلي
/// متكاملاً بدل الاعتماد على ألوان ثابتة داخل الواجهات.
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
    canvas: V12Colors.lightCanvas,
    surface: V12Colors.lightSurface,
    surfaceAlt: V12Colors.lightSurfaceMuted,
    stroke: V12Colors.lightStroke,
    text: V12Colors.lightInk,
    textMuted: V12Colors.lightMuted,
    accent: V12Colors.pulse,
    accentStrong: V12Colors.pulseDeep,
    accentSoft: Color(0xFFDDF4EA),
    danger: V12Colors.coral,
    dangerSoft: Color(0xFFFFE9EC),
    warning: V12Colors.amber,
    warningSoft: Color(0xFFFFF3D7),
    shadow: Color(0x140B2E22),
  );

  static const dark = AppPalette(
    canvas: V12Colors.darkCanvas,
    surface: V12Colors.darkSurface,
    surfaceAlt: V12Colors.darkSurfaceMuted,
    stroke: V12Colors.darkStroke,
    text: V12Colors.darkInk,
    textMuted: V12Colors.darkMuted,
    accent: V12Colors.pulseNight,
    accentStrong: V12Colors.pulseNight,
    accentSoft: Color(0xFF173D30),
    danger: V12Colors.coralNight,
    dangerSoft: Color(0xFF40252A),
    warning: V12Colors.amberNight,
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
  }) =>
      AppPalette(
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

/// ألوان مميزة لكل تصنيف (تُستخدم في الرسوم والقوائم).
const Map<String, Color> kCategoryColors = {
  'ترفيه ومشاهدة': Color(0xFFFF7A85),
  'موسيقى وبودكاست': Color(0xFFB388FF),
  'إنتاجية وذكاء اصطناعي': Color(0xFF2EE6A8),
  'ألعاب': Color(0xFF64B5F6),
  'رياضة وصحة': Color(0xFFFFB74D),
  'تعليم': Color(0xFF4DD0E1),
  'تسوق وتوصيل': Color(0xFFF48FB1),
  'اتصالات وإنترنت': Color(0xFF81C784),
  'تخزين سحابي': Color(0xFF90A4AE),
  'مالية وفواتير': Color(0xFFFFD166),
  'أخبار ومجلات': Color(0xFF8AB4F8),
  'أخرى': Color(0xFFE9C46A),
};

Color categoryColor(String category) =>
    kCategoryColors[category] ?? AppColors.gold;

ThemeData buildAppTheme({bool dark = false}) {
  final palette = dark ? AppPalette.dark : AppPalette.light;
  final scheme = dark
      ? const ColorScheme.dark(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          secondary: AppColors.gold,
          onSecondary: AppColors.ink,
          surface: AppColors.darkCard,
          onSurface: AppColors.darkInk,
          error: AppColors.danger,
          onError: Colors.white,
        )
      : const ColorScheme.light(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          secondary: AppColors.gold,
          onSecondary: AppColors.ink,
          surface: AppColors.card,
          onSurface: AppColors.ink,
          error: AppColors.danger,
          onError: Colors.white,
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
    fontFamily: V12Type.bodyFamily,
    fontFamilyFallback: V12Type.fallbacks,
    extensions: [palette],
  );

  return base.copyWith(
    cupertinoOverrideTheme: CupertinoThemeData(
      brightness: dark ? Brightness.dark : Brightness.light,
      primaryColor: palette.accent,
      scaffoldBackgroundColor: palette.canvas,
      barBackgroundColor: palette.surface,
      textTheme: CupertinoTextThemeData(
        textStyle: TextStyle(
          color: palette.text,
          fontSize: V12Type.body,
          height: 1.35,
          fontFamily: V12Type.bodyFamily,
          fontFamilyFallback: V12Type.fallbacks,
        ),
      ),
    ),
    scaffoldBackgroundColor: palette.canvas,
    appBarTheme: AppBarTheme(
      backgroundColor: palette.canvas,
      foregroundColor: onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 62,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: onSurface,
        fontSize: 22,
        fontWeight: FontWeight.w900,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: palette.accentStrong,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(54),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(V12Radius.standard),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.accent,
        side: BorderSide(color: palette.accent, width: 1.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(V12Radius.standard),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
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
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(V12Radius.standard),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(V12Radius.standard),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(V12Radius.standard),
        borderSide: BorderSide(color: palette.accent, width: 1.5),
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(V12Radius.standard),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: dark ? palette.surfaceAlt : palette.text,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 15),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(V12Radius.standard),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: palette.accentStrong,
      foregroundColor: Colors.white,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      titleTextStyle: TextStyle(
        color: onSurface,
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
      contentTextStyle: TextStyle(
        color: muted,
        fontSize: 14.5,
        height: 1.6,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(V12Radius.signature),
      ),
    ),
    dividerColor: border,
  );
}

/// بطاقة موحّدة الشكل في كل التطبيق.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? context.palette.surface,
        borderRadius: BorderRadius.circular(V12Radius.standard),
        border: Border.all(
          color: borderColor ?? context.palette.stroke,
        ),
        boxShadow: [
          BoxShadow(
            color: context.palette.shadow,
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
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
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          if (emoji != null) ...[
            Text(emoji!, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 7),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: context.palette.text,
            ),
          ),
        ],
      ),
    );
  }
}

/// عدّاد رقمي متحرك (يصعد بسلاسة من صفر إلى القيمة).
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
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(fmt(v), style: style),
    );
  }

  String fmt(double v) {
    final rounded = double.parse(v.toStringAsFixed(2));
    final s = rounded == rounded.roundToDouble()
        ? rounded.toStringAsFixed(0)
        : rounded.toStringAsFixed(2);
    return '$s ${currencySymbolsView[currency] ?? currency}';
  }

  static const Map<String, String> currencySymbolsView = {
    'SAR': 'ر.س',
    'AED': 'د.إ',
    'KWD': 'د.ك',
    'QAR': 'ر.ق',
    'BHD': 'د.ب',
    'OMR': 'ر.ع',
    'USD': r'$',
    'EUR': '€',
  };
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
      text = 'اليوم';
      bg = context.palette.dangerSoft;
      fg = context.palette.danger;
    } else if (days == 1) {
      text = 'غدًا';
      bg = context.palette.dangerSoft;
      fg = context.palette.danger;
    } else if (days <= 7) {
      text = 'بعد $days أيام';
      bg = context.palette.warningSoft;
      fg = context.palette.warning;
    } else {
      text = 'بعد $days يومًا';
      bg = context.palette.accentSoft;
      fg = context.palette.accent;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(V12Radius.signature),
      ),
      child: Text(
        text,
        style:
            TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w800),
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
      tween: Tween(begin: 0, end: 1),
      duration: V12Motion.entrance + Duration(milliseconds: delayMs),
      curve: V12Motion.curve,
      builder: (context, t, c) {
        final clamped = t.clamp(0.0, 1.0);
        return Opacity(
          opacity: clamped,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - clamped)),
            child: c,
          ),
        );
      },
      child: child,
    );
  }
}

String fmtDate(DateTime d) =>
    '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

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
    final fallback = Icon(
      Icons.apps_rounded,
      color: tint,
      size: size * 0.48,
    );
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(size * 0.3),
        border: Border.all(color: tint.withValues(alpha: 0.35)),
      ),
      child: url == null
          ? fallback
          : ClipRRect(
              borderRadius: BorderRadius.circular(size * 0.16),
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
