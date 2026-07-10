/// الإعدادات: العملة، الميزانية، الذكاء الاصطناعي، والحساب.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/subscription.dart';
import '../services/ai_extractor.dart'
    show kAiProviders, aiProviderById;
import '../services/auth_service.dart';
import '../services/cloud_sync.dart';
import '../services/notification_service.dart';
import '../services/update_checker.dart';
import '../services/subscription_store.dart';
import '../theme.dart';
import 'email_link_screen.dart';
import 'import_screen.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _budget;
  late final TextEditingController _aiKey;

  // Portable backup is intentionally hidden from the product UI.
  bool get _showPortableBackup => false;

  @override
  void initState() {
    super.initState();
    final b = SubscriptionStore.instance.monthlyBudget;
    _budget = TextEditingController(
      text: b <= 0 ? '' : (b == b.roundToDouble() ? b.toStringAsFixed(0) : '$b'),
    );
    _aiKey = TextEditingController(
      text: SubscriptionStore.instance.aiApiKey,
    );
  }

  @override
  void dispose() {
    _budget.dispose();
    _aiKey.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = SubscriptionStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return ListView(
          keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 132),
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تحكم في تجربتك',
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'إعدادات بسيطة تجعل اشتراكاتك تعمل كما تريد',
                    style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'الحساب والمزامنة',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    !AuthService.isAvailable
                        ? 'المزامنة السحابية قيد التجهيز — ستتوفر في تحديث قريب.'
                        : AuthService.isSignedIn
                            ? 'مسجل الدخول: ${AuthService.userEmail}'
                            : 'سجّل دخولك لتُحفظ بياناتك مع حسابك وتستعيدها على أي جهاز.',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12.5,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (!AuthService.isSignedIn)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: !AuthService.isAvailable
                          ? null
                          : () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const LoginScreen(fromSettings: true),
                                ),
                              );
                              if (context.mounted) setState(() {});
                            },
                      icon: const Icon(Icons.login_rounded, size: 20),
                      label: const Text('تسجيل الدخول'),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(46),
                            ),
                            onPressed: () async {
                              final ok = await CloudSync.push();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      ok
                                          ? 'تمت المزامنة بنجاح'
                                          : 'تعذرت المزامنة — تأكد من الإنترنت',
                                    ),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.cloud_upload_rounded,
                                size: 19),
                            label: const Text('مزامنة الآن'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(46),
                              foregroundColor: AppColors.danger,
                              side: const BorderSide(
                                color: AppColors.danger,
                              ),
                            ),
                            onPressed: () async {
                              await AuthService.signOut();
                              if (context.mounted) setState(() {});
                            },
                            icon: const Icon(Icons.logout_rounded, size: 19),
                            label: const Text('خروج'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const _SettingsGroupLabel('التنبيهات والخصوصية'),
            AppCard(
              child: SwitchListTile(
                value: store.notificationsEnabled,
                onChanged: (v) async {
                  if (v) {
                    final ok = await NotificationService.instance
                        .requestPermission();
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'فعّل الإشعارات لتطبيق «اشتراكاتي» من إعدادات iOS أولًا',
                          ),
                        ),
                      );
                    }
                  }
                  await store.setNotificationsEnabled(v);
                },
                title: const Text(
                  'إشعارات التجديد',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: AppColors.ink,
                  ),
                ),
                subtitle: const Text(
                  'تذكير قبل كل خصم وقبل انتهاء التجارب المجانية '
                  '(يُضبط لكل اشتراك من شاشة التعديل)',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12.5,
                    height: 1.6,
                  ),
                ),
                activeColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(height: 14),
            AppCard(
              child: SwitchListTile(
                value: store.appLockEnabled,
                onChanged: (v) => store.setAppLockEnabled(v),
                title: const Text(
                  'قفل التطبيق ببصمة الوجه',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: AppColors.ink,
                  ),
                ),
                subtitle: const Text(
                  'يُطلب Face ID عند فتح التطبيق أو العودة إليه',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12.5,
                  ),
                ),
                activeColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(height: 14),
            const _SettingsGroupLabel('الميزانية والعملات'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'الميزانية الشهرية',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'حدد سقفًا لمصروفك الشهري وسيظهر لك شريط متابعة في الرئيسية.',
                    style:
                        TextStyle(color: AppColors.muted, fontSize: 12.5),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _budget,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textDirection: TextDirection.ltr,
                          decoration: InputDecoration(
                            hintText: 'مثال: 300',
                            suffixText:
                                currencySymbols[store.defaultCurrency],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(90, 52),
                        ),
                        onPressed: () async {
                          final v = double.tryParse(
                                _budget.text
                                    .trim()
                                    .replaceAll('،', '.')
                                    .replaceAll(',', '.'),
                              ) ??
                              0;
                          await store.setMonthlyBudget(v);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  v <= 0
                                      ? 'تم إلغاء الميزانية'
                                      : 'تم ضبط الميزانية على ${fmtMoney(v, store.defaultCurrency)}',
                                ),
                              ),
                            );
                          }
                        },
                        child: const Text('حفظ'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'العملة الافتراضية',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'تُستخدم تلقائيًا عند إضافة اشتراك جديد.',
                    style:
                        TextStyle(color: AppColors.muted, fontSize: 12.5),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: store.defaultCurrency,
                    dropdownColor: AppColors.cardAlt,
                    items: [
                      for (final c in currencySymbols.keys)
                        DropdownMenuItem(
                          value: c,
                          child: Text('${currencySymbols[c]} ($c)'),
                        ),
                    ],
                    onChanged: (v) {
                      if (v != null) store.setDefaultCurrency(v);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const _SettingsGroupLabel('الاستيراد والأتمتة'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'الاستيراد الذكي وربط البريد',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'الصق رسائل البنك أو إيصالات Apple وسنستخرج '
                    'اشتراكاتك بأسعارها تلقائيًا.',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 12.5,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ImportScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.auto_awesome_rounded, size: 20),
                    label: const Text('فتح الاستيراد الذكي'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const EmailLinkScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.alternate_email_rounded, size: 20),
                    label: const Text('ربط البريد وجلب الاشتراكات'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'الذكاء الاصطناعي الخاص بك',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'اختر مزودك المفضل وأدخل مفتاحك الخاص — يجعل الاستيراد '
                    'والمستشار الذكي يعملان لحسابك أنت (المفتاح يبقى على جهازك).',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 12.5,
                      height: 1.7,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: store.aiProvider,
                    dropdownColor: AppColors.cardAlt,
                    decoration:
                        const InputDecoration(labelText: 'المزود'),
                    items: [
                      for (final p in kAiProviders)
                        DropdownMenuItem(
                          value: p.id,
                          child: Text(p.label),
                        ),
                    ],
                    onChanged: (v) {
                      if (v != null) store.setAiProvider(v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _aiKey,
                    obscureText: true,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: 'مفتاح API',
                      hintText: aiProviderById(store.aiProvider).hint,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(46),
                          ),
                          onPressed: () => launchUrl(
                            Uri.parse(
                              aiProviderById(store.aiProvider).keyUrl,
                            ),
                            mode: LaunchMode.externalApplication,
                          ),
                          icon: const Icon(Icons.open_in_new_rounded,
                              size: 18),
                          label: const Text('إنشاء مفتاح'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(90, 46),
                        ),
                        onPressed: () async {
                          try {
                            await store.setAiApiKey(_aiKey.text);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('$e')),
                              );
                            }
                            return;
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  _aiKey.text.trim().isEmpty
                                      ? 'تم إيقاف الذكاء الاصطناعي'
                                      : 'تم حفظ المفتاح — الاستيراد الآن أذكى',
                                ),
                              ),
                            );
                          }
                        },
                        child: const Text('حفظ'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                    ),
                    onPressed: store.aiApiKey.trim().isEmpty
                        ? null
                        : () async {
                            final approved = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('تصنيف بالخدمة السحابية؟'),
                                content: const Text(
                                  'سيُرسل اسم كل خدمة غير مصنفة فقط إلى Gemini. '
                                  'لن تُرسل الأسعار أو الملاحظات أو بيانات البريد.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('إلغاء'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('أوافق'),
                                  ),
                                ],
                              ),
                            );
                            if (approved != true) return;
                            try {
                              final count =
                                  await store.reclassifyUnknownsWithAi();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      count == 0
                                          ? 'لا توجد خدمات غير مصنفة قابلة للتحديث'
                                          : 'تم تصنيف $count خدمات بالذكاء الاصطناعي',
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('$e')),
                                );
                              }
                            }
                          },
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: const Text('تصنيف الخدمات غير المعروفة بالذكاء الاصطناعي'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (_showPortableBackup) ...[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'النسخ الاحتياطي',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'النسخة الاحتياطية قابلة للنقل بين الأجهزة، لكنها نص قابل '
                      'للقراءة. لا تحفظها إلا في مكان خاص ومحمٍ.',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 12.5,
                        height: 1.6,
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                          onPressed: () async {
                            final approved = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('تصدير نسخة قابلة للقراءة؟'),
                                content: const Text(
                                  'سيُنَسخ ملف JSON غير مشفّر إلى الحافظة لتتمكن '
                                  'من نقله إلى جهاز آخر. لا تلصقه في تطبيقات عامة '
                                  'ولا تشاركه مع أي شخص.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('إلغاء'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('أفهم، صدّر'),
                                  ),
                                ],
                              ),
                            );
                            if (approved != true) return;
                            await Clipboard.setData(
                              ClipboardData(text: store.exportJson()),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'تم نسخ البيانات — ألصقها في الملاحظات لحفظها',
                                  ),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.upload_rounded, size: 20),
                          label: const Text('تصدير'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            foregroundColor: AppColors.gold,
                            side:
                                const BorderSide(color: AppColors.goldDeep),
                          ),
                          onPressed: () => _import(context, store),
                          icon:
                              const Icon(Icons.download_rounded, size: 20),
                          label: const Text('استعادة'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: buildCsv(store.items)),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'تم نسخ جدول CSV — ألصقه في Excel أو Numbers',
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.table_chart_rounded, size: 20),
                    label: const Text('تصدير جدول CSV'),
                  ),
                ],
              ),
              ),
              const SizedBox(height: 14),
            ],
            const _SettingsGroupLabel('عن التطبيق'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'حول التطبيق',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const _AboutRow(label: 'الاسم', value: 'اشتراكاتي'),
                  const _AboutRow(label: 'الإصدار', value: kAppVersion),
                  const _AboutRow(label: 'المطوّر', value: 'باسل'),
                  const _AboutRow(
                    label: 'الخصوصية',
                    value: 'بيانات الاشتراكات مشفّرة على جهازك.\n'
                        'التحليل بالذكاء الاصطناعي وربط البريد اختياريان\n'
                        'ولا يرسلان بيانات إلا بعد موافقتك.',
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'صُنع بحب في السعودية 🇸🇦',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const _SettingsGroupLabel('إدارة البيانات'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'إدارة البيانات',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () => _confirmWipe(context, store),
                    icon: const Icon(Icons.delete_forever_rounded),
                    label: const Text('حذف جميع الاشتراكات'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _import(
    BuildContext context,
    SubscriptionStore store,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('استعادة من الحافظة؟'),
        content: const Text(
          'انسخ نص النسخة الاحتياطية أولًا (من الملاحظات مثلًا)، '
          'ثم اضغط «استعادة». سيتم دمج الاشتراكات مع الموجود حاليًا.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('استعادة'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final data = await Clipboard.getData('text/plain');
    final raw = data?.text ?? '';
    final count = raw.trim().isEmpty ? -1 : await store.importJson(raw);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          count >= 0
              ? 'تمت استعادة $count اشتراكًا بنجاح ✅'
              : 'الحافظة لا تحتوي نسخة احتياطية صالحة',
        ),
      ),
    );
  }

  Future<void> _confirmWipe(
    BuildContext context,
    SubscriptionStore store,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف كل البيانات؟'),
        content: const Text(
          'سيتم حذف جميع اشتراكاتك نهائيًا من هذا الجهاز. '
          'لا يمكن التراجع عن هذه الخطوة.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('حذف الكل'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await store.clearAll();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف جميع البيانات')),
        );
      }
    }
  }
}

class _SettingsGroupLabel extends StatelessWidget {
  final String text;

  const _SettingsGroupLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 4, bottom: 8),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 18,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  final String label;
  final String value;

  const _AboutRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
