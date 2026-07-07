/// الهوية البصرية v2 لتطبيق «اشتراكاتي»:
/// ثيم داكن فاخر — زمردي متوهج على خلفية ليلية عميقة مع لمسات ذهبية.
library;

import 'package:flutter/material.dart';

import 'data/service_domains.dart';

class AppColors {
  AppColors._();

  // خلفيات
  static const Color bg = Color(0xFF0B1512); // ليل غابة عميق
  static const Color card = Color(0xFF15221C);
  static const Color cardAlt = Color(0xFF1B2B24);
  static const Color border = Color(0xFF25382F);

  // نصوص
  static const Color ink = Color(0xFFEDF6F0);
  static const Color muted = Color(0xFF8FA79B);

  // الهوية
  static const Color primary = Color(0xFF2EE6A8); // زمردي متوهج
  static const Color primaryDeep = Color(0xFF14B886);
  static const Color primarySoft = Color(0xFF16382C);

  static const Color gold = Color(0xFFE9C46A);
  static const Color goldDeep = Color(0xFFCFA13F);
  static const Color goldSoft = Color(0xFF33301C);

  static const Color danger = Color(0xFFFF6B6B);
  static const Color dangerSoft = Color(0xFF3A2226);
  static const Color warn = Color(0xFFF5B84F);

  /// تدرج البطاقة الرئيسية.
  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF0F3D2E), Color(0xFF14B886), Color(0xFF2EE6A8)],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );
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
  'أخرى': Color(0xFFE9C46A),
};

Color categoryColor(String category) =>
    kCategoryColors[category] ?? AppColors.gold;

ThemeData buildAppTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.primary,
    onPrimary: Color(0xFF06231A),
    secondary: AppColors.gold,
    onSecondary: Color(0xFF231A06),
    surface: AppColors.card,
    onSurface: AppColors.ink,
    error: AppColors.danger,
    onError: Colors.white,
  );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme);

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.ink,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: AppColors.ink,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: const Color(0xFF06231A),
        minimumSize: const Size.fromHeight(54),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primaryDeep, width: 1.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.primary),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      hintStyle: const TextStyle(color: AppColors.muted),
      labelStyle: const TextStyle(color: AppColors.muted),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF101B16),
      indicatorColor: AppColors.primarySoft,
      surfaceTintColor: Colors.transparent,
      height: 68,
      labelTextStyle: MaterialStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: states.contains(MaterialState.selected)
              ? AppColors.primary
              : AppColors.muted,
        ),
      ),
      iconTheme: MaterialStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(MaterialState.selected)
              ? AppColors.primary
              : AppColors.muted,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.cardAlt,
      contentTextStyle: const TextStyle(color: AppColors.ink, fontSize: 15),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Color(0xFF06231A),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.cardAlt,
      titleTextStyle: const TextStyle(
        color: AppColors.ink,
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
      contentTextStyle: const TextStyle(
        color: AppColors.muted,
        fontSize: 14.5,
        height: 1.6,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dividerColor: AppColors.border,
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
        color: color ?? AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor ?? AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 16,
            offset: Offset(0, 6),
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
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
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
      bg = AppColors.dangerSoft;
      fg = AppColors.danger;
    } else if (days == 1) {
      text = 'غدًا';
      bg = AppColors.dangerSoft;
      fg = AppColors.danger;
    } else if (days <= 7) {
      text = 'بعد $days أيام';
      bg = AppColors.goldSoft;
      fg = AppColors.gold;
    } else {
      text = 'بعد $days يومًا';
      bg = AppColors.primarySoft;
      fg = AppColors.primary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
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
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 450 + delayMs),
      curve: Curves.easeOutCubic,
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

/// أيقونة الخدمة: الشعار الرسمي إن عُرف نطاقها، وإلا الإيموجي.
class ServiceAvatar extends StatelessWidget {
  final String name;
  final String emoji;
  final String manageUrl;
  final Color tint;
  final double size;

  const ServiceAvatar({
    super.key,
    required this.name,
    required this.emoji,
    required this.manageUrl,
    required this.tint,
    this.size = 46,
  });

  @override
  Widget build(BuildContext context) {
    final url = logoUrlFor(name, manageUrl);
    final emojiText = Text(
      emoji,
      style: TextStyle(fontSize: size * 0.52),
    );
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tint.withOpacity(0.15),
        borderRadius: BorderRadius.circular(size * 0.3),
        border: Border.all(color: tint.withOpacity(0.35)),
      ),
      child: url == null
          ? emojiText
          : ClipRRect(
              borderRadius: BorderRadius.circular(size * 0.16),
              child: Image.network(
                url,
                width: size * 0.58,
                height: size * 0.58,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => emojiText,
              ),
            ),
    );
  }
}
