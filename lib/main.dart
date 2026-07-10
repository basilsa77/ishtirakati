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
import 'services/notification_service.dart';
import 'services/remote_catalog.dart';
import 'services/subscription_store.dart';
import 'services/update_checker.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = SubscriptionStore.instance;
  await store.load();
  await NotificationService.instance.init();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarBrightness: Brightness.dark),
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'اشتراكاتي',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // إغلاق الكيبورد عند الضغط في أي مكان فارغ بالتطبيق.
      builder: (context, child) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: child ?? const SizedBox.shrink(),
      ),
      home: SubscriptionStore.instance.hasOnboarded
          ? const LockGate(child: RootShell())
          : const OnboardingScreen(),
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
    if (state == AppLifecycleState.paused &&
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
          biometricOnly: false,
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
            const Text(
              'اشتراكاتي مقفلة',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.ink,
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
                style: const TextStyle(
                  color: AppColors.danger,
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

  static const List<String> _titles = [
    'اشتراكاتي',
    'كل الاشتراكات',
    'تحليلات الإنفاق',
    'التقويم',
    'الإعدادات',
  ];

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
      appBar: _index == 0 ? null : AppBar(title: Text(_titles[_index])),
      body: SafeArea(
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'اشتراكاتي',
          ),
          NavigationDestination(
            icon: Icon(Icons.donut_large_outlined),
            selectedIcon: Icon(Icons.donut_large_rounded),
            label: 'تحليلات',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'التقويم',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'الإعدادات',
          ),
        ],
      ),
    );
  }
}
