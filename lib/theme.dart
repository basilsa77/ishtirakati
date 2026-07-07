/// الهوية البصرية لتطبيق «اشتراكاتي»:
/// خلفية فاتحة دافئة، أخضر زمردي (المال والنمو)، ولمسات رملية خليجية.
library;

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color bg = Color(0xFFF7F4EE); // خلفية دافئة
  static const Color card = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE7E0D2);
  static const Color ink = Color(0xFF1B2A26); // نص أساسي
  static const Color muted = Color(0xFF6E7B75); // نص ثانوي

  static const Color primary = Color(0xFF0E8A63); // زمردي
  static const Color primaryDeep = Color(0xFF0A6B4C);
  static const Color primarySoft = Color(0xFFE3F2EB);

  static const Color sand = Color(0xFFC9A24B); // رملي/ذهبي هادئ
  static const Color sandSoft = Color(0xFFF6EEDC);

  static const Color danger = Color(0xFFD64550);
  static const Color warn = Color(0xFFE0A320);
}

ThemeData buildAppTheme() {
  const scheme = ColorScheme.light(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    secondary: AppColors.sand,
    onSecondary: AppColors.ink,
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
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(54),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryDeep,
        side: const BorderSide(color: AppColors.primary, width: 1.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.primaryDeep),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
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
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: AppColors.primaryDeep,
      unselectedItemColor: AppColors.muted,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: TextStyle(fontWeight: FontWeight.w800),
      elevation: 8,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.ink,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 15),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
    ),
    dividerColor: AppColors.border,
  );
}

/// بطاقة موحّدة الشكل في كل التطبيق
/// (بديل عن CardTheme لضمان الثبات عبر إصدارات Flutter).
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D1B2A26),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: child,
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
      text = 'اليوم';
      bg = const Color(0xFFFBE3E5);
      fg = AppColors.danger;
    } else if (days == 1) {
      text = 'غدًا';
      bg = const Color(0xFFFBE3E5);
      fg = AppColors.danger;
    } else if (days <= 7) {
      text = 'بعد $days أيام';
      bg = const Color(0xFFFDF2D9);
      fg = const Color(0xFF9A6E0C);
    } else {
      text = 'بعد $days يومًا';
      bg = AppColors.primarySoft;
      fg = AppColors.primaryDeep;
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
