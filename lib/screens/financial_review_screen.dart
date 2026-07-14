import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
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
      navigationBar: CupertinoNavigationBar(
        middle: Text(tr('ui_f0cac12b4c73')),
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
        message: Text(tr('ui_fe79a06b79f9')),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(sheetContext);
              await store.recordUsage(subscription.id);
            },
            child: Text(tr('ui_2af3653b0c9f')),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(sheetContext);
              await store.markReviewed(subscription.id);
            },
            child: Text(tr('ui_abb7607440cf')),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: Text(tr('ui_9a30dc2a96b8')),
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
                  tr('ui_1ae481061748', {'value0': analysis.reviewItems.length}),
                  style: TextStyle(color: p.text, fontSize: V15Type.body, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  tr('ui_c7ca26cba27e', {'value0': fmtMoney(analysis.potentialMonthlySavings, currency)}),
                  style: TextStyle(color: p.textMuted, fontSize: V15Type.labelSmall),
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
                  Text(item.subscription.name, style: TextStyle(color: p.text, fontSize: V15Type.bodySmall, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(_labelFor(item.reason), style: TextStyle(color: p.textMuted, fontSize: V15Type.caption)),
                ],
              ),
            ),
            if (_monthlySaving(item) > 0)
              Text(
                fmtMoney(_monthlySaving(item), currency),
                style: TextStyle(color: p.accent, fontSize: V15Type.caption, fontWeight: FontWeight.w800),
              ),
            const SizedBox(width: 6),
            Icon(CupertinoIcons.chevron_left, color: p.textMuted, size: 16),
          ],
        ),
      ),
    );
  }

  static String _labelFor(FinancialReviewReason reason) => switch (reason) {
        FinancialReviewReason.duplicate => tr('ui_b319d9a58104'),
        FinancialReviewReason.unusedAutoRenewal => tr('ui_2ac3ff1ff32b'),
        FinancialReviewReason.priceIncrease => tr('ui_9b64a8bbe48b'),
        FinancialReviewReason.overdueReview => tr('ui_287936e31433'),
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
            Text(tr('ui_84180a00b479'), style: TextStyle(color: p.text, fontSize: V15Type.title, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(tr('ui_cc941d2bd31f'), textAlign: TextAlign.center, style: TextStyle(color: p.textMuted, fontSize: V15Type.labelSmall)),
          ],
        ),
      ),
    );
  }
}
