/// اشتراكاتي — تتبّع اشتراكاتك الرقمية وتحكّم بمصروفك.
/// عربي أولًا، خصوصية كاملة: كل البيانات على جهازك فقط.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/dashboard_screen.dart';
import 'screens/insights_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/subscriptions_screen.dart';
import 'services/notification_service.dart';
import 'services/remote_catalog.dart';
import 'services/subscription_store.dart';
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
  RemoteCatalog.instance.load();
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
      home: const RootShell(),
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
    'الإعدادات',
  ];

  Widget _body() {
    switch (_index) {
      case 0:
        return const DashboardScreen(key: ValueKey('dash'));
      case 1:
        return const SubscriptionsScreen(key: ValueKey('subs'));
      case 2:
        return const InsightsScreen(key: ValueKey('insights'));
      default:
        return const SettingsScreen(key: ValueKey('settings'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
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
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'الإعدادات',
          ),
        ],
      ),
    );
  }
}
