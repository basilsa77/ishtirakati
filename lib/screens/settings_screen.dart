/// الإعدادات: العملة الافتراضية، إدارة البيانات، وحول التطبيق.
library;

import 'package:flutter/material.dart';

import '../models/subscription.dart';
import '../services/subscription_store.dart';
import '../theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = SubscriptionStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
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
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('⭐', style: TextStyle(fontSize: 24)),
                      const SizedBox(width: 8),
                      const Text(
                        'النسخة الاحترافية',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'قريبًا',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryDeep,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '• تنبيهات قبل موعد التجديد بيوم و٣ أيام\n'
                    '• نسخ احتياطي واستعادة عبر iCloud\n'
                    '• تقارير شهرية PDF قابلة للمشاركة\n'
                    '• تحويل تلقائي بين العملات',
                    style: TextStyle(
                      color: AppColors.muted,
                      height: 1.9,
                      fontSize: 13.5,
                    ),
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
                    'حول التطبيق',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const _AboutRow(label: 'الاسم', value: 'اشتراكاتي'),
                  const _AboutRow(label: 'الإصدار', value: '1.0.0'),
                  const _AboutRow(label: 'المطوّر', value: 'باسل'),
                  const _AboutRow(
                    label: 'الخصوصية',
                    value: 'بياناتك محفوظة على جهازك فقط،\nولا تُرسل لأي خادم.',
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
