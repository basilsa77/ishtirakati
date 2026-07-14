/// اشتراكاتي — تتبّع اشتراكاتك الرقمية وتحكّم بمصروفك.
/// عربي أولًا: محلي افتراضيًا، مع مزامنة وAI اختياريين بإفصاح واضح.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:local_auth/local_auth.dart';

import 'screens/calendar_screen.dart';
import 'l10n/app_localizations.dart';
import 'screens/onboarding_screen.dart';
import 'screens/insights_screen.dart';
import 'screens/command_palette.dart';
import 'screens/pulse_home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/subscriptions_screen.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/remote_catalog.dart';
import 'services/subscription_store.dart';
import 'services/update_checker.dart';
import 'theme.dart';
import 'widgets/adaptive_cycle_shell.dart';
import 'widgets/app_material_root.dart';
import 'widgets/app_media_query.dart';

/// Prevents Flutter Inspector paint overlays from leaking into an installed
/// build. The baseline overlay is especially disruptive for Arabic text because
/// it draws yellow and green rules across every rendered line.
@visibleForTesting
void disableVisualDebugOverlays() {
  debugPaintSizeEnabled = false;
  debugPaintBaselinesEnabled = false;
  debugPaintPointersEnabled = false;
  debugPaintLayerBordersEnabled = false;
  debugRepaintRainbowEnabled = false;
}

void _installVisualDebugOverlayGuard() {
  disableVisualDebugOverlays();
  WidgetsBinding.instance.addPersistentFrameCallback((_) {
    disableVisualDebugOverlays();
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _installVisualDebugOverlayGuard();
  ErrorWidget.builder = (details) {
    debugPrint('UI render failure (${details.exception.runtimeType}).');
    return const _RenderFailure();
  };
  final store = SubscriptionStore.instance;
  try {
    await store.load();
  } catch (_) {
    // لا نسمح لأي خطأ تخزين بمنع التطبيق من الفتح.
  }
  final initialLocale = resolveStoredLocale(store.languageMode) ??
      resolveSupportedLocale(
        WidgetsBinding.instance.platformDispatcher.locale,
      );
  await AppLocalizations.load(initialLocale);
  setDefaultFormattingLocale(initialLocale);
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
  WidgetsBinding.instance.addPostFrameCallback((_) {
    disableVisualDebugOverlays();
  });
  // بعد الإقلاع: صلاحية الإشعارات وجدولتها + تحديث قاعدة الخدمات.
  if (store.notificationsEnabled) {
    // ignore: unawaited_futures
    NotificationService.instance.requestPermission().then(
          (_) => NotificationService.instance
              .rescheduleAll(
                store.items,
                enabled: true,
                privateContent: store.privateNotifications,
              ),
        );
  }
  // ignore: unawaited_futures
  RemoteCatalog.instance.load().then((_) => store.reclassifyUnknowns());
  // ignore: unawaited_futures
  UpdateChecker.check();
}

ThemeMode resolveAppThemeMode(String preference) => switch (preference) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

class IshtirakatiApp extends StatelessWidget {
  const IshtirakatiApp({super.key});

  @override
  Widget build(BuildContext context) {
    disableVisualDebugOverlays();
    final store = SubscriptionStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final mode = resolveAppThemeMode(store.themeMode);
        final preferredLocale = resolveStoredLocale(store.languageMode);
        final effectiveLocale = preferredLocale ?? resolveSupportedLocale(
          WidgetsBinding.instance.platformDispatcher.locale,
        );
        setDefaultFormattingLocale(effectiveLocale);
        return MaterialApp(
      onGenerateTitle: (context) => context.l10n.text('appTitle'),
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      darkTheme: buildAppTheme(dark: true),
      themeMode: mode,
      locale: preferredLocale,
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback: (deviceLocale, _) =>
          resolveSupportedLocale(deviceLocale),
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
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
        return AppMaterialRoot(
          child: AppMediaQuery(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
      home: store.hasOnboarded
          ? const LockGate(child: RootShell())
          : OnboardingScreen(),
        );
      },
    );
  }
}

class _RenderFailure extends StatelessWidget {
  const _RenderFailure();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.canvas,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.exclamationmark_triangle,
                color: p.warning,
                size: 36,
              ),
              SizedBox(height: 12),
              Text(
                tr('ui_b68f32e3329a'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: p.text,
                  fontSize: V15Type.titleSmall,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 6),
              Text(
                tr('ui_af2167fbbff9'),
                textAlign: TextAlign.center,
                style: TextStyle(color: p.textMuted, height: 1.5),
              ),
            ],
          ),
        ),
      ),
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
        localizedReason: tr('ui_f9a122088fe8'),
        options: AuthenticationOptions(
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
        setState(() => _authError = tr('ui_df7cc66a367d'));
      }
    } catch (_) {
      // لا نفتح التطبيق عند فشل المصادقة؛ القفل يحمي بيانات المستخدم.
      if (mounted) {
        setState(() => _authError = tr('ui_4f19bb952755'));
      }
    } finally {
      _authInProgress = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_locked) return widget.child;
    final p = context.palette;
    return CupertinoPageScaffold(
      backgroundColor: p.canvas,
      child: Center(
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
              child: Icon(
                CupertinoIcons.lock_fill,
                color: CupertinoColors.white,
                size: 44,
              ),
            ),
            SizedBox(height: 20),
            Text(
              tr('ui_c3c9617192c3'),
              style: TextStyle(
                fontSize: V15Type.title,
                fontWeight: FontWeight.w900,
                color: p.text,
              ),
            ),
            SizedBox(height: 24),
            CupertinoButton.filled(
              onPressed: _unlock,
              child: Text(tr('ui_cef85563f6a5')),
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
  V12Destination _destination = V12Destination.home;
  late final List<Widget> _pages = [
    PulseHomeScreen(
      key: const PageStorageKey('pulse-home'),
      onOpenCommands: _openCommands,
      onOpenLibrary: () => _select(V12Destination.subscriptions),
      onOpenRenewals: () => _select(V12Destination.calendar),
    ),
    SubscriptionsScreen(key: PageStorageKey('subscriptions')),
    InsightsScreen(key: PageStorageKey('insights')),
    CalendarScreen(key: PageStorageKey('calendar')),
    SettingsScreen(key: PageStorageKey('settings')),
  ];

  void _select(V12Destination destination) {
    if (_destination == destination) return;
    setState(() => _destination = destination);
  }

  Future<void> _openCommands() => showV12CommandPalette(
        context,
        onDestination: _select,
      );

  @override
  Widget build(BuildContext context) {
    final store = SubscriptionStore.instance;
    if (!store.storageHealthy) {
      return _StorageRecoveryGate(
        message: store.storageError ??
            tr('ui_fa44d20258ad'),
      );
    }
    return CupertinoPageScaffold(
      backgroundColor: context.palette.canvas,
      child: SafeArea(
        bottom: false,
        child: AdaptiveCycleShell(
          destination: _destination,
          onDestination: _select,
          pages: _pages,
        ),
      ),
    );
  }
}

class _StorageRecoveryGate extends StatefulWidget {
  final String message;

  const _StorageRecoveryGate({required this.message});

  @override
  State<_StorageRecoveryGate> createState() => _StorageRecoveryGateState();
}

class _StorageRecoveryGateState extends State<_StorageRecoveryGate> {
  bool _retrying = false;

  Future<void> _retry() async {
    setState(() => _retrying = true);
    await SubscriptionStore.instance.load();
    if (mounted) setState(() => _retrying = false);
  }

  @override
  Widget build(BuildContext context) {
    if (SubscriptionStore.instance.storageHealthy) {
      return RootShell();
    }
    final p = context.palette;
    return CupertinoPageScaffold(
      backgroundColor: p.canvas,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(CupertinoIcons.shield_fill, size: 64, color: p.accent),
              SizedBox(height: 20),
              Text(
                tr('ui_ae57be0a15db'),
                style: TextStyle(
                  color: p.text,
                  fontSize: V15Type.title,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 12),
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: TextStyle(color: p.textMuted, height: 1.7),
              ),
              SizedBox(height: 8),
              Text(
                tr('ui_93a9463ad8dc') +
                tr('ui_d38f17269b33'),
                textAlign: TextAlign.center,
                style: TextStyle(color: p.textMuted, fontSize: V15Type.caption, height: 1.6),
              ),
              SizedBox(height: 24),
              CupertinoButton.filled(
                onPressed: _retrying ? null : _retry,
                child: _retrying
                    ? CupertinoActivityIndicator(color: CupertinoColors.white)
                    : Text(tr('ui_c73b9bc3f450')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
