/// إعدادات الإصدار 8: مجموعات قصيرة واضحة من دون صفحات متراكبة.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/subscription.dart' show currencySymbols;
import '../services/account_deletion_service.dart';
import '../services/auth_service.dart';
import '../services/cloud_sync.dart';
import '../services/notification_service.dart';
import '../services/subscription_store.dart';
import '../services/update_checker.dart';
import '../theme.dart';
import '../widgets/ios_controls.dart';
import 'ai_tools_screen.dart';
import 'email_link_screen.dart';
import 'import_screen.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _budget;

  @override
  void initState() {
    super.initState();
    final store = SubscriptionStore.instance;
    final budget = store.monthlyBudget;
    _budget = TextEditingController(
      text: budget <= 0
          ? ''
          : budget == budget.roundToDouble()
              ? budget.toStringAsFixed(0)
              : budget.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _budget.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = SubscriptionStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          const _SettingsIntro(),
          if (!store.storageHealthy) ...[
            const SizedBox(height: 14),
            AppCard(
              color: context.palette.dangerSoft,
              borderColor: context.palette.danger,
              child: Text(
                store.storageError ?? 'التخزين مقفل لحماية بياناتك.',
                style: TextStyle(
                  color: context.palette.danger,
                  fontWeight: FontWeight.w800,
                  height: 1.6,
                ),
              ),
            ),
          ],
          const SizedBox(height: 22),
          _AccountCard(
            onChanged: () => setState(() {}),
            onDeleteAccount: _confirmDeleteAccount,
          ),
          const SizedBox(height: 26),
          const _SettingsLabel('المظهر'),
          const SizedBox(height: 10),
          const _ThemeModeCard(),
          const SizedBox(height: 26),
          const _SettingsLabel('التنبيهات'),
          const SizedBox(height: 10),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _SettingsSwitch(
                  icon: Icons.notifications_none_rounded,
                  title: 'تنبيهات التجديد',
                  detail: 'تذكير قبل الخصم والتجارب المجانية',
                  value: store.notificationsEnabled,
                  onChanged: (value) async {
                    if (value) {
                      final permitted = await NotificationService.instance.requestPermission();
                      if (!permitted && context.mounted) {
                        await showCupertinoDialog<void>(
                          context: context,
                          builder: (dialogContext) => CupertinoAlertDialog(
                            title: const Text('الإشعارات غير مفعلة'),
                            content: const Text('اسمح بالإشعارات من إعدادات iPhone لتلقي تنبيهات التجديد.'),
                            actions: [CupertinoDialogAction(onPressed: () => Navigator.pop(dialogContext), child: const Text('حسنًا'))],
                          ),
                        );
                      }
                    }
                    await store.setNotificationsEnabled(value);
                  },
                ),
                Divider(height: 1, color: context.palette.stroke),
                _SettingsSwitch(
                  icon: CupertinoIcons.lock_shield,
                  title: 'إخفاء تفاصيل التنبيهات',
                  detail: 'لا يظهر اسم الخدمة أو المبلغ على شاشة القفل',
                  value: store.privateNotifications,
                  onChanged: store.setPrivateNotifications,
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          const _SettingsLabel('الأمان والخصوصية'),
          const SizedBox(height: 10),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _SettingsSwitch(
                  icon: Icons.face_retouching_natural_rounded,
                  title: 'قفل التطبيق',
                  detail: 'استخدم Face ID عند الفتح أو العودة',
                  value: store.appLockEnabled,
                  onChanged: store.setAppLockEnabled,
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          const _SettingsLabel('التخطيط المالي'),
          const SizedBox(height: 10),
          _BudgetCard(controller: _budget, onSave: _saveBudget),
          const SizedBox(height: 26),
          const _SettingsLabel('أدواتك الذكية'),
          const SizedBox(height: 10),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _SettingsAction(
                  icon: Icons.document_scanner_rounded,
                  title: 'استيراد من النصوص',
                  detail: 'حلّل رسائل البنك أو الإيصالات',
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute(builder: (_) => const ImportScreen()),
                  ),
                ),
                Divider(height: 1, color: context.palette.stroke),
                _SettingsAction(
                  icon: Icons.alternate_email_rounded,
                  title: 'ربط البريد',
                  detail: 'اكتشف الاشتراكات من إيصالاتك',
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute(builder: (_) => const EmailLinkScreen()),
                  ),
                ),
                Divider(height: 1, color: context.palette.stroke),
                _SettingsAction(
                  icon: Icons.auto_awesome_rounded,
                  title: 'أدوات الذكاء الاصطناعي',
                  detail: 'المزود والمفتاح وتصنيف الخدمات',
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute(builder: (_) => const AiToolsScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          const _SettingsLabel('البيانات'),
          const SizedBox(height: 10),
          _DataCard(onDelete: _confirmWipe),
          const SizedBox(height: 26),
          const _SettingsLabel('حول التطبيق'),
          const SizedBox(height: 10),
          const _AboutCard(),
          const SizedBox(height: 30),
          Center(
            child: Text(
              'صُنع بحب في السعودية 🇸🇦',
              style: TextStyle(color: context.palette.textMuted, fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveBudget() async {
    final value = double.tryParse(
          _budget.text.trim().replaceAll('،', '.').replaceAll(',', '.'),
        ) ??
        0;
    await SubscriptionStore.instance.setMonthlyBudget(value);
    if (!mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        content: Text(value <= 0 ? 'تم إيقاف الميزانية الشهرية.' : 'تم حفظ الميزانية الشهرية.'),
        actions: [CupertinoDialogAction(onPressed: () => Navigator.pop(dialogContext), child: const Text('تم'))],
      ),
    );
  }

  Future<void> _confirmWipe() async {
    final confirmed = await showIosConfirmation(
      context: context,
      title: 'حذف جميع الاشتراكات؟',
      message: 'سيُحذف سجل الاشتراكات من هذا الجهاز نهائيًا.',
      confirmLabel: 'حذف نهائي',
      destructive: true,
    );
    if (!confirmed) return;
    await SubscriptionStore.instance.clearAll();
    if (mounted) {
      await showCupertinoDialog<void>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          content: const Text('تم حذف جميع الاشتراكات من هذا الجهاز.'),
          actions: [CupertinoDialogAction(onPressed: () => Navigator.pop(dialogContext), child: const Text('تم'))],
        ),
      );
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showIosConfirmation(
      context: context,
      title: 'حذف الحساب نهائيًا؟',
      message: 'سنطلب تأكيد هويتك، ثم نحذف بياناتك السحابية وحسابك، وبعد نجاح ذلك نمسح بيانات هذا الجهاز. حذف الحساب لا يلغي اشتراكاتك لدى الخدمات الأخرى.',
      confirmLabel: 'حذف الحساب',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: CupertinoAlertDialog(
          content: Row(
            children: [
              CupertinoActivityIndicator(),
              SizedBox(width: 12),
              Expanded(child: Text('جارٍ حذف الحساب والبيانات...')),
            ],
          ),
        ),
      ),
    );
    try {
      await AccountDeletionService.deleteEverything();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      Navigator.of(context).pushAndRemoveUntil(
        CupertinoPageRoute(builder: (_) => const OnboardingScreen()),
        (_) => false,
      );
    } catch (error) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      final message = error is AuthException
          ? error.message
          : 'تعذر إكمال الحذف. لم نمسح بيانات هذا الجهاز؛ أعد المحاولة.';
      await showCupertinoDialog<void>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('تعذر حذف الحساب'),
          content: Text(message),
          actions: [CupertinoDialogAction(onPressed: () => Navigator.pop(dialogContext), child: const Text('حسنًا'))],
        ),
      );
    }
  }
}

class _SettingsIntro extends StatelessWidget {
  const _SettingsIntro();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('الإعدادات', style: TextStyle(color: p.text, fontSize: 30, fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        Text('الحساب، الخصوصية، التنبيهات وأدوات الاستيراد.', style: TextStyle(color: p.textMuted, fontSize: 13)),
      ],
    );
  }
}

class _AccountCard extends StatelessWidget {
  final VoidCallback onChanged;
  final Future<void> Function() onDeleteAccount;

  const _AccountCard({
    required this.onChanged,
    required this.onDeleteAccount,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final signedIn = AuthService.isSignedIn;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: p.accentSoft, borderRadius: BorderRadius.circular(12)),
                child: Icon(CupertinoIcons.cloud, color: p.accent, size: 21),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('الحساب والمزامنة', style: TextStyle(color: p.text, fontWeight: FontWeight.w900, fontSize: 15)),
                    const SizedBox(height: 3),
                    Text(
                      !AuthService.isAvailable
                          ? 'الخدمة غير متاحة في هذا البناء'
                          : signedIn
                              ? AuthService.userEmail
                              : 'سجّل دخولك لتستعيد بياناتك على أجهزتك',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: p.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!signedIn)
            CupertinoButton.filled(
              onPressed: !AuthService.isAvailable
                  ? null
                  : () async {
                      await Navigator.of(context).push(
                        CupertinoPageRoute(builder: (_) => const LoginScreen(fromSettings: true)),
                      );
                      onChanged();
                    },
              child: const Text('تسجيل الدخول'),
            )
          else
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: CupertinoButton.filled(
                        onPressed: () async {
                          await CloudSync.push();
                        },
                        child: const Text('مزامنة الآن'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    CupertinoButton(
                      padding: const EdgeInsets.all(11),
                      color: p.dangerSoft,
                      onPressed: () async {
                        try {
                          await AuthService.signOut();
                          onChanged();
                        } on AuthException catch (error) {
                          if (!context.mounted) return;
                          await showCupertinoDialog<void>(
                            context: context,
                            builder: (dialogContext) => CupertinoAlertDialog(
                              content: Text(error.message),
                              actions: [CupertinoDialogAction(onPressed: () => Navigator.pop(dialogContext), child: const Text('حسنًا'))],
                            ),
                          );
                        }
                      },
                      child: Icon(CupertinoIcons.square_arrow_right, color: p.danger),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ValueListenableBuilder<CloudSyncStatus>(
                  valueListenable: CloudSync.status,
                  builder: (context, status, _) {
                    final (icon, text, color) = switch (status.phase) {
                      CloudSyncPhase.syncing => (
                           CupertinoIcons.arrow_2_circlepath,
                           'جارٍ مزامنة البيانات...',
                          p.accent,
                        ),
                      CloudSyncPhase.success => (
                           CupertinoIcons.check_mark_circled,
                          _syncSuccessText(status.updatedAt),
                          p.accent,
                        ),
                      CloudSyncPhase.failure => (
                           CupertinoIcons.exclamationmark_circle,
                           status.message ??
                               'تعذرت المزامنة. أعد المحاولة بعد التحقق من الاتصال.',
                          p.danger,
                        ),
                      CloudSyncPhase.idle => (
                           CupertinoIcons.cloud,
                           'لم تبدأ مزامنة جديدة بعد.',
                          p.textMuted,
                        ),
                    };
                    return Row(
                      children: [
                        Icon(icon, color: color, size: 17),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            text,
                            style: TextStyle(
                              color: color,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                CupertinoButton(
                  onPressed: onDeleteAccount,
                  child: Text('حذف الحساب والبيانات السحابية', style: TextStyle(color: p.danger)),
                ),
              ],
            ),
          const SizedBox(height: 12),
          Text(
            'بياناتك على هذا الجهاز مشفرة بـ AES-256-GCM، ويُحفظ مفتاحها في Keychain. عند تفعيل المزامنة، تنقل Firebase النسخة عبر اتصال مشفر وتحميها في التخزين السحابي، لكنها ليست تشفيرًا طرفيًا بمفتاح لا تستطيع الخوادم قراءته.',
            style: TextStyle(color: p.textMuted, fontSize: 11.5, height: 1.6),
          ),
          ValueListenableBuilder<String?>(
            valueListenable: AuthService.appCheckWarning,
            builder: (context, warning, _) {
              if (warning == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.gpp_maybe_rounded, color: p.danger, size: 18),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        warning,
                        style: TextStyle(
                          color: p.danger,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  static String _syncSuccessText(DateTime? at) {
    if (at == null) return 'اكتملت المزامنة';
    final hour = at.hour.toString().padLeft(2, '0');
    final minute = at.minute.toString().padLeft(2, '0');
    return 'آخر مزامنة ناجحة $hour:$minute';
  }
}

class _SettingsLabel extends StatelessWidget {
  final String text;

  const _SettingsLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(color: context.palette.textMuted, fontSize: 12, fontWeight: FontWeight.w900),
      );
}

class _SettingsSwitch extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitch({
    required this.icon,
    required this.title,
    required this.detail,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: p.accent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: p.text, fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 3),
                Text(detail, style: TextStyle(color: p.textMuted, fontSize: 11.5)),
              ],
            ),
          ),
          CupertinoSwitch(
            value: value,
            activeTrackColor: p.accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _SettingsAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;

  const _SettingsAction({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Icon(icon, color: p.accent, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: p.text, fontWeight: FontWeight.w800, fontSize: 14)),
                  const SizedBox(height: 3),
                  Text(detail, style: TextStyle(color: p.textMuted, fontSize: 11.5)),
                ],
              ),
            ),
            Icon(CupertinoIcons.chevron_left, color: p.textMuted, size: 17),
          ],
        ),
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSave;

  const _BudgetCard({required this.controller, required this.onSave});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final currency = SubscriptionStore.instance.defaultCurrency;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart_outline_rounded, color: p.accent),
              const SizedBox(width: 9),
              Text('ميزانية الشهر', style: TextStyle(color: p.text, fontSize: 15, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 7),
          Text('ضع سقفًا مرنًا لمتابعة الالتزامات الشهرية.', style: TextStyle(color: p.textMuted, fontSize: 12)),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: CupertinoTextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textDirection: TextDirection.ltr,
                  placeholder: '0',
                  suffix: Padding(
                    padding: const EdgeInsetsDirectional.only(end: 12),
                    child: Text(currencySymbols[currency] ?? currency, style: TextStyle(color: p.textMuted)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                  decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(11), border: Border.all(color: p.stroke)),
                ),
              ),
              const SizedBox(width: 10),
              CupertinoButton(
                padding: const EdgeInsets.all(11),
                color: p.accent,
                onPressed: onSave,
                child: const Icon(CupertinoIcons.check_mark, color: CupertinoColors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          const _AboutLine(label: 'التطبيق', value: 'اشتراكاتي'),
          Divider(height: 1, color: p.stroke),
          const _AboutLine(label: 'الإصدار', value: kAppBuildLabel),
          Divider(height: 1, color: p.stroke),
          const _AboutLine(label: 'نوع البناء', value: kAppBuildMode),
          Divider(height: 1, color: p.stroke),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => launchUrl(
              Uri.parse(
                'https://github.com/basilsa77/ishtirakati/blob/main/PRIVACY_POLICY.md',
              ),
              mode: LaunchMode.externalApplication,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(child: Text('سياسة الخصوصية', style: TextStyle(color: p.text, fontWeight: FontWeight.w800, fontSize: 13))),
                  Icon(CupertinoIcons.arrow_up_right_square, color: p.textMuted, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutLine extends StatelessWidget {
  final String label;
  final String value;

  const _AboutLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: p.textMuted, fontSize: 12)),
          const Spacer(),
          Text(value, style: TextStyle(color: p.text, fontWeight: FontWeight.w800, fontSize: 13)),
        ],
      ),
    );
  }
}

/// اختيار مظهر التطبيق: داكن (الافتراضي) أو فاتح أو حسب النظام.
class _ThemeModeCard extends StatelessWidget {
  const _ThemeModeCard();

  @override
  Widget build(BuildContext context) {
    final store = SubscriptionStore.instance;
    final p = context.palette;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('مظهر التطبيق', style: TextStyle(color: p.text, fontSize: 14, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('اختر المظهر الذي يناسب جهازك؛ الوضع التلقائي يتبع iPhone.', style: TextStyle(color: p.textMuted, fontSize: 12)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: CupertinoSlidingSegmentedControl<String>(
              groupValue: store.themeMode,
              backgroundColor: p.surfaceAlt,
              thumbColor: p.accent,
              children: {
                'system': _ThemeModeOption(
                  label: 'حسب النظام',
                  icon: CupertinoIcons.device_phone_portrait,
                  selected: store.themeMode == 'system',
                ),
                'dark': _ThemeModeOption(
                  label: 'داكن',
                  icon: CupertinoIcons.moon_fill,
                  selected: store.themeMode == 'dark',
                ),
                'light': _ThemeModeOption(
                  label: 'فاتح',
                  icon: CupertinoIcons.sun_max_fill,
                  selected: store.themeMode == 'light',
                ),
              },
              onValueChanged: (value) {
                if (value != null) store.setThemeMode(value);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeModeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;

  const _ThemeModeOption({
    required this.label,
    required this.icon,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected
                  ? CupertinoColors.white
                  : context.palette.textMuted,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: selected
                    ? CupertinoColors.white
                    : context.palette.text,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
}

/// إدارة البيانات: حذف السجل من الجهاز.
class _DataCard extends StatelessWidget {
  final Future<void> Function() onDelete;

  const _DataCard({required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppCard(
      padding: EdgeInsets.zero,
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        onPressed: onDelete,
        child: Row(
          children: [
            Icon(CupertinoIcons.delete, color: p.danger, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('حذف جميع الاشتراكات', style: TextStyle(color: p.danger, fontWeight: FontWeight.w800, fontSize: 13.5)),
                  const SizedBox(height: 3),
                  Text('يمسح السجل من هذا الجهاز نهائيًا', style: TextStyle(color: p.danger.withValues(alpha: .75), fontSize: 11.5)),
                ],
              ),
            ),
            Icon(CupertinoIcons.chevron_left, color: p.danger, size: 17),
          ],
        ),
      ),
    );
  }
}
