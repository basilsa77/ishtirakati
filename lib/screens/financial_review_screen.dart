import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../models/subscription.dart';
import '../services/financial_assistant.dart';
import '../services/subscription_store.dart';
import '../theme.dart';

class FinancialReviewScreen extends StatelessWidget {
  final String currency;

  const FinancialReviewScreen({super.key, required this.currency});

  @override
  Widget build(BuildContext context) {
    final store = SubscriptionStore.instance;
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('المراجعات المالية'),
      ),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            final analysis = FinancialAssistant.analyze(
              store.items,
              currency: currency,
            );
            if (analysis.reviewItems.isEmpty) {
              return const _ReviewEmpty();
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
              itemCount: analysis.reviewItems.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _ReviewSummary(analysis: analysis, currency: currency);
                }
                final item = analysis.reviewItems[index - 1];
                return _ReviewRow(
                  item: item,
                  currency: currency,
                  onPressed: () => _showActions(context, store, item.subscription),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _showActions(
    BuildContext context,
    SubscriptionStore store,
    Subscription subscription,
  ) async {
    await HapticFeedback.selectionClick();
    if (!context.mounted) return;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(subscription.name),
        message: const Text('اختر الإجراء الذي يعكس قرارك الحالي.'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(sheetContext);
              await store.recordUsage(subscription.id);
            },
            child: const Text('تسجيل استخدام اليوم'),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(sheetContext);
              await store.markReviewed(subscription.id);
            },
            child: const Text('تمت مراجعة الاشتراك'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('إلغاء'),
        ),
      ),
    );
  }
}

class _ReviewSummary extends StatelessWidget {
  final FinancialAssistantSnapshot analysis;
  final String currency;

  const _ReviewSummary({required this.analysis, required this.currency});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: p.accentSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.stroke),
      ),
      child: Row(
        children: [
          Icon(CupertinoIcons.chart_bar_alt_fill, color: p.accent, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${analysis.reviewItems.length} عناصر تحتاج قرارًا',
                  style: TextStyle(color: p.text, fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'توفير محتمل ${fmtMoney(analysis.potentialMonthlySavings, currency)} شهريًا',
                  style: TextStyle(color: p.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final FinancialReviewItem item;
  final String currency;
  final VoidCallback onPressed;

  const _ReviewRow({required this.item, required this.currency, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: p.stroke),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(13)),
              child: Icon(_iconFor(item.reason), color: p.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.subscription.name, style: TextStyle(color: p.text, fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(_labelFor(item.reason), style: TextStyle(color: p.textMuted, fontSize: 12)),
                ],
              ),
            ),
            if (_monthlySaving(item) > 0)
              Text(
                fmtMoney(_monthlySaving(item), currency),
                style: TextStyle(color: p.accent, fontSize: 12, fontWeight: FontWeight.w800),
              ),
            const SizedBox(width: 6),
            Icon(CupertinoIcons.chevron_left, color: p.textMuted, size: 16),
          ],
        ),
      ),
    );
  }

  static String _labelFor(FinancialReviewReason reason) => switch (reason) {
        FinancialReviewReason.duplicate => 'اشتراك مكرر في الخدمة نفسها',
        FinancialReviewReason.unusedAutoRenewal => 'متجدد تلقائيًا ولم يُسجل استخدامه',
        FinancialReviewReason.priceIncrease => 'ارتفع سعره ويستحق المقارنة',
        FinancialReviewReason.overdueReview => 'لم تُراجع شروطه منذ مدة',
      };

  static IconData _iconFor(FinancialReviewReason reason) => switch (reason) {
        FinancialReviewReason.duplicate => CupertinoIcons.square_on_square,
        FinancialReviewReason.unusedAutoRenewal => CupertinoIcons.refresh_circled,
        FinancialReviewReason.priceIncrease => CupertinoIcons.arrow_up_right,
        FinancialReviewReason.overdueReview => CupertinoIcons.checkmark_seal,
      };

  static double _monthlySaving(FinancialReviewItem item) => switch (item.reason) {
        FinancialReviewReason.duplicate ||
        FinancialReviewReason.unusedAutoRenewal => item.subscription.monthlyCost,
        FinancialReviewReason.priceIncrease ||
        FinancialReviewReason.overdueReview => 0,
      };
}

class _ReviewEmpty extends StatelessWidget {
  const _ReviewEmpty();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.checkmark_shield_fill, color: p.accent, size: 48),
            const SizedBox(height: 14),
            Text('لا توجد مراجعات معلقة', style: TextStyle(color: p.text, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('اشتراكاتك الحالية لا تعرض مؤشرات تستدعي قرارًا الآن.', textAlign: TextAlign.center, style: TextStyle(color: p.textMuted, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
