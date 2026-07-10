/// اشتراكاتي — تتبّع اشتراكاتك الرقمية وتحكّم بمصروفك.
/// عربي أولًا، خصوصية كاملة: كل البيانات على جهازك فقط.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:local_auth/local_auth.dart';

import 'screens/calendar_screen.dart';
import 'screens/command_center_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/insights_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/subscriptions_screen.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/remote_catalog.dart';
import 'services/subscription_store.dart';
import 'services/update_checker.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = SubscriptionStore.instance;
  try {
    await store.load();
  } catch (_) {
    // لا نسمح لأي خطأ تخزين بمنع التطبيق من الفتح.
  }
  await NotificationService.instance.init();
  await AuthService.init();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.card,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const IshtirakatiApp());
  // بعد الإقلاع: صلاحية الإشعارات وجدولتها + تحديث قاعدة الخدمات.
  if (store.notificationsEnabled) {
    // ignore: unawaited_futures
    NotificationService.instance.requestPermission().then(
          (_) => NotificationService.instance
              .rescheduleAll(store.items, enabled: true),
        );
  }
  // ignore: unawaited_futures
  RemoteCatalog.instance.load().then((_) => store.reclassifyUnknowns());
  // ignore: unawaited_futures
  UpdateChecker.check();
}

class IshtirakatiApp extends StatelessWidget {
  const IshtirakatiApp({super.key});

  static ThemeMode _resolveMode(String pref) {
    switch (pref) {
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.dark;
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = SubscriptionStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final mode = _resolveMode(store.themeMode);
        return MaterialApp(
      title: 'اشتراكاتي',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      darkTheme: buildAppTheme(dark: true),
      themeMode: mode,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // إغلاق الكيبورد عند الضغط في أي مكان فارغ بالتطبيق.
      builder: (context, child) {
        final isDark = mode == ThemeMode.dark ||
            (mode == ThemeMode.system &&
                MediaQuery.platformBrightnessOf(context) == Brightness.dark);
        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
            statusBarBrightness:
                isDark ? Brightness.dark : Brightness.light,
            systemNavigationBarColor:
                isDark ? AppColors.darkBg : AppColors.card,
            systemNavigationBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
          ),
        );
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: store.hasOnboarded
          ? const LockGate(child: RootShell())
          : const OnboardingScreen(),
        );
      },
    );
  }
}

/// بوابة القفل: تطلب Face ID عند فتح التطبيق إذا فعّل المستخدم القفل.
class LockGate extends StatefulWidget {
  final Widget child;

  const LockGate({super.key, required this.child});

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate>
    with WidgetsBindingObserver {
  late bool _locked;
  bool _authInProgress = false;
  String? _authError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _locked = SubscriptionStore.instance.appLockEnabled;
    if (_locked) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ((state == AppLifecycleState.inactive ||
            state == AppLifecycleState.paused) &&
        SubscriptionStore.instance.appLockEnabled) {
      setState(() => _locked = true);
    }
  }

  Future<void> _unlock() async {
    if (_authInProgress) return;
    _authInProgress = true;
    if (mounted) setState(() => _authError = null);
    try {
      final auth = LocalAuthentication();
      final ok = await auth.authenticate(
        localizedReason: 'افتح «اشتراكاتي» ببصمة الوجه',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (ok && mounted) {
        setState(() {
          _locked = false;
          _authError = null;
        });
      } else if (mounted) {
        setState(() => _authError = 'لم تتم المصادقة. حاول مرة أخرى.');
      }
    } catch (_) {
      // لا نفتح التطبيق عند فشل المصادقة؛ القفل يحمي بيانات المستخدم.
      if (mounted) {
        setState(() => _authError = 'تعذرت المصادقة على هذا الجهاز.');
      }
    } finally {
      _authInProgress = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_locked) return widget.child;
    final p = context.palette;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 92,
              height: 92,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: AppColors.heroGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_rounded,
                color: Colors.white,
                size: 44,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'اشتراكاتي مقفلة',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: p.text,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size(220, 54),
              ),
              onPressed: _unlock,
              icon: const Icon(Icons.face_rounded),
              label: const Text('فتح ببصمة الوجه'),
            ),
            if (_authError != null) ...[
              const SizedBox(height: 14),
              Text(
                _authError!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: p.danger,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  Widget _body() {
    switch (_index) {
      case 0:
        return const CommandCenterScreen(key: ValueKey('command-center'));
      case 1:
        return const SubscriptionsScreen(key: ValueKey('subs'));
      case 2:
        return const InsightsScreen(key: ValueKey('insights'));
      case 3:
        return const CalendarScreen(key: ValueKey('calendar'));
      default:
        return const SettingsScreen(key: ValueKey('settings'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: child,
          ),
          child: _body(),
        ),
      ),
      bottomNavigationBar: _ModernBottomBar(
        selectedIndex: _index,
        onSelected: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _ModernBottomBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _ModernBottomBar({
    required this.selectedIndex,
    required this.onSelected,
  });

  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, 'الرئيسية'),
    (Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'اشتراكاتي'),
    (Icons.insights_outlined, Icons.insights_rounded, 'تحليلات'),
    (Icons.calendar_month_outlined, Icons.calendar_month_rounded, 'التقويم'),
    (Icons.settings_outlined, Icons.settings_rounded, 'الإعدادات'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        decoration: BoxDecoration(
          color: context.palette.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: context.palette.stroke),
          boxShadow: [
            BoxShadow(
              color: context.palette.shadow,
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            for (var i = 0; i < _items.length; i++)
              Expanded(
                child: _BottomBarItem(
                  item: _items[i],
                  selected: selectedIndex == i,
                  onTap: () => onSelected(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomBarItem extends StatelessWidget {
  final (IconData, IconData, String) item;
  final bool selected;
  final VoidCallback onTap;

  const _BottomBarItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: item.$3,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: selected ? context.palette.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? item.$2 : item.$1,
                size: 21,
                color: selected ? context.palette.accent : context.palette.textMuted,
              ),
              const SizedBox(height: 3),
              Text(
                item.$3,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? context.palette.accent : context.palette.textMuted,
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
