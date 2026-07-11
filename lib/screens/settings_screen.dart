/// إعدادات الإصدار 8: مجموعات قصيرة واضحة من دون صفحات متراكبة.
library;

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
          const _SettingsLabel('الحماية والتنبيهات'),
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('فعّل الإشعارات من إعدادات iPhone أولًا.')),
                        );
                      }
                    }
                    await store.setNotificationsEnabled(value);
                  },
                ),
                Divider(height: 1, color: context.palette.stroke),
                _SettingsSwitch(
                  icon: Icons.face_retouching_natural_rounded,
                  title: 'قفل التطبيق',
                  detail: 'استخدم Face ID عند الفتح أو العودة',
                  value: store.appLockEnabled,
                  onChanged: store.setAppLockEnabled,
                ),
                Divider(height: 1, color: context.palette.stroke),
                _SettingsSwitch(
                  icon: Icons.key_rounded,
                  title: 'توافق إعادة التوقيع الجانبي',
                  detail: store.sideloadRecoveryEnabled
                      ? 'مرآة توافق مفعّلة؛ Keychain يبقى المصدر الأول'
                      : 'Keychain فقط؛ الحماية الأقوى للإصدار الرسمي',
                  value: store.sideloadRecoveryEnabled,
                  onChanged: _toggleSideloadRecovery,
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
                    MaterialPageRoute(builder: (_) => const ImportScreen()),
                  ),
                ),
                Divider(height: 1, color: context.palette.stroke),
                _SettingsAction(
                  icon: Icons.alternate_email_rounded,
                  title: 'ربط البريد',
                  detail: 'اكتشف الاشتراكات من إيصالاتك',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const EmailLinkScreen()),
                  ),
                ),
                Divider(height: 1, color: context.palette.stroke),
                _SettingsAction(
                  icon: Icons.auto_awesome_rounded,
                  title: 'أدوات الذكاء الاصطناعي',
                  detail: 'المزود والمفتاح وتصنيف الخدمات',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AiToolsScreen()),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value <= 0 ? 'تم إيقاف الميزانية الشهرية.' : 'تم حفظ الميزانية الشهرية.'),
      ),
    );
  }

  Future<void> _confirmWipe() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف جميع الاشتراكات؟'),
        content: const Text('سيُحذف سجل الاشتراكات من هذا الجهاز نهائيًا.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: context.palette.danger),
            child: const Text('حذف نهائي'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await SubscriptionStore.instance.clearAll();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف جميع الاشتراكات.')),
      );
    }
  }

  Future<void> _toggleSideloadRecovery(bool enabled) async {
    if (enabled) {
      final approved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('تفعيل توافق إعادة التوقيع؟'),
          content: const Text(
            'يحتفظ هذا الخيار بنسخة محلية من مفتاح البيانات كي لا تضيع '
            'اشتراكاتك عند إعادة توقيع التطبيق جانبيًا. Keychain يبقى المصدر '
            'الأول، لكن مستوى العزل أقل من نسخة App Store. فعّله فقط إذا '
            'كنت تعيد توقيع التطبيق خارج App Store.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('تفعيل التوافق'),
            ),
          ],
        ),
      );
      if (approved != true) return;
    }
    final ok = await SubscriptionStore.instance
        .setSideloadRecoveryEnabled(enabled);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? enabled
                  ? 'فُعّل وضع التوافق. سيُستخدم فقط بعد تعذر Keychain.'
                  : 'عُطّل وضع التوافق بعد التحقق من Keychain.'
              : 'تعذر تغيير الوضع دون المخاطرة ببياناتك.',
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف الحساب نهائيًا؟'),
        content: const Text(
          'سنطلب تأكيد هويتك، ثم نحذف النسخة السحابية وحساب Firebase، '
          'وبعد نجاحهما نمسح الاشتراكات والمفاتيح من هذا الجهاز. لا يمكن '
          'التراجع عن هذه العملية. حذف الحساب لا يلغي اشتراكاتك لدى الخدمات الأخرى.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إبقاء حسابي'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: dialogContext.palette.danger,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('تأكيد الحذف'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Expanded(child: Text('جارٍ حذف الحساب والبيانات بأمان...')),
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
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        (_) => false,
      );
    } catch (error) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      final message = error is AuthException
          ? error.message
          : 'تعذر إكمال الحذف. لم نمسح بيانات هذا الجهاز؛ أعد المحاولة.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
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
        Text('الإعدادات', style: TextStyle(color: p.text, fontSize: 27, fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        Text('رتّب حماية التطبيق وطريقة متابعته على ذوقك.', style: TextStyle(color: p.textMuted, fontSize: 13)),
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: p.accentSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.accent.withOpacity(.24)),
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
                decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.cloud_done_rounded, color: Colors.white, size: 21),
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
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
              onPressed: !AuthService.isAvailable
                  ? null
                  : () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LoginScreen(fromSettings: true)),
                      );
                      onChanged();
                    },
              icon: const Icon(Icons.login_rounded, size: 19),
              label: const Text('تسجيل الدخول'),
            )
          else
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                        onPressed: () async {
                          final ok = await CloudSync.push();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(ok ? 'اكتملت المزامنة.' : 'تعذرت المزامنة، تحقق من الإنترنت.')),
                            );
                          }
                        },
                        icon: const Icon(Icons.sync_rounded, size: 19),
                        label: const Text('مزامنة الآن'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      tooltip: 'تسجيل الخروج',
                      style: IconButton.styleFrom(
                        minimumSize: const Size(46, 46),
                        foregroundColor: p.danger,
                        side: BorderSide(color: p.danger.withValues(alpha: .45)),
                      ),
                      onPressed: () async {
                        await AuthService.signOut();
                        onChanged();
                      },
                      icon: const Icon(Icons.logout_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ValueListenableBuilder<CloudSyncStatus>(
                  valueListenable: CloudSync.status,
                  builder: (context, status, _) {
                    final (icon, text, color) = switch (status.phase) {
                      CloudSyncPhase.syncing => (
                          Icons.sync_rounded,
                          'جارٍ تأمين أحدث نسخة...',
                          p.accent,
                        ),
                      CloudSyncPhase.success => (
                          Icons.cloud_done_rounded,
                          _syncSuccessText(status.updatedAt),
                          p.accent,
                        ),
                      CloudSyncPhase.failure => (
                          Icons.cloud_off_rounded,
                          'تعذرت آخر محاولة مزامنة',
                          p.danger,
                        ),
                      CloudSyncPhase.idle => (
                          Icons.cloud_queue_rounded,
                          'جاهز للمزامنة الآمنة',
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
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    foregroundColor: p.danger,
                  ),
                  onPressed: onDeleteAccount,
                  icon: const Icon(Icons.person_remove_rounded, size: 18),
                  label: const Text('حذف الحساب والبيانات السحابية'),
                ),
              ],
            ),
          const SizedBox(height: 12),
          Text(
            'النسخة السحابية محمية بتسجيل الدخول وقواعد Firestore وتشفير '
            'النقل والتخزين لدى Firebase، لكنها ليست تشفيرًا طرفيًا E2E. '
            'استخدام المزامنة اختياري.',
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
          Switch.adaptive(value: value, activeColor: p.accent, onChanged: onChanged),
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
    return InkWell(
      onTap: onTap,
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
            Icon(Icons.chevron_left_rounded, color: p.textMuted),
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
                child: TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(hintText: '0', suffixText: currencySymbols[currency]),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(
                tooltip: 'حفظ الميزانية',
                onPressed: onSave,
                icon: const Icon(Icons.check_rounded),
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
          _AboutLine(label: 'التطبيق', value: 'اشتراكاتي'),
          Divider(height: 1, color: p.stroke),
          _AboutLine(label: 'الإصدار', value: kAppVersion),
          Divider(height: 1, color: p.stroke),
          ListTile(
            onTap: () => launchUrl(
              Uri.parse(
                'https://github.com/basilsa77/ishtirakati/blob/main/PRIVACY_POLICY.md',
              ),
              mode: LaunchMode.externalApplication,
            ),
            title: Text(
              'سياسة الخصوصية',
              style: TextStyle(
                color: p.text,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            trailing: Icon(Icons.open_in_new_rounded, color: p.textMuted),
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
          Text('وضع الألوان', style: TextStyle(color: p.text, fontSize: 14, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('اختر المظهر الذي يناسب جهازك؛ الوضع التلقائي يتبع iPhone.', style: TextStyle(color: p.textMuted, fontSize: 12)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'dark', label: Text('داكن'), icon: Icon(Icons.dark_mode_rounded, size: 16)),
                ButtonSegment(value: 'light', label: Text('فاتح'), icon: Icon(Icons.light_mode_rounded, size: 16)),
                ButtonSegment(value: 'system', label: Text('تلقائي'), icon: Icon(Icons.phone_iphone_rounded, size: 16)),
              ],
              selected: {store.themeMode},
              onSelectionChanged: (selection) => store.setThemeMode(selection.first),
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                padding: MaterialStatePropertyAll(EdgeInsets.symmetric(horizontal: 5)),
              ),
            ),
          ),
        ],
      ),
    );
  }
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
      child: ListTile(
        onTap: onDelete,
        leading: Icon(Icons.delete_outline_rounded, color: p.danger),
        title: Text('حذف جميع الاشتراكات', style: TextStyle(color: p.danger, fontWeight: FontWeight.w900, fontSize: 13.5)),
        subtitle: Text('يمسح السجل من هذا الجهاز نهائيًا', style: TextStyle(color: p.danger.withOpacity(.7), fontSize: 11.5)),
        trailing: Icon(Icons.chevron_left_rounded, color: p.danger),
      ),
    );
  }
}
