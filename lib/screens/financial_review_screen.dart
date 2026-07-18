import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../models/subscription.dart';
import '../services/financial_assistant.dart';
import '../services/subscription_store.dart';
import '../theme.dart';
import '../widgets/service_name_text.dart';

Future<void> openPotentialDuplicateReview(
  BuildContext context,
  DuplicateSubscriptionGroup group,
) => Navigator.of(context).push(
  CupertinoPageRoute<void>(
    builder:
        (_) => FinancialReviewScreen(
          currency: group.subscriptions.first.currency,
          initialDuplicateGroupKey: group.groupKey,
        ),
  ),
);

class FinancialReviewScreen extends StatelessWidget {
  final String currency;
  final String? initialDuplicateGroupKey;
  final SubscriptionStore? store;

  const FinancialReviewScreen({
    super.key,
    required this.currency,
    this.initialDuplicateGroupKey,
    this.store,
  });

  @override
  Widget build(BuildContext context) {
    final store = this.store ?? SubscriptionStore.instance;
    final p = context.palette;
    return CupertinoPageScaffold(
      backgroundColor: p.canvas,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: p.canvas.withValues(alpha: .92),
        border: Border(bottom: BorderSide(color: p.stroke)),
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
            final duplicateGroups = FinancialAssistant.findDuplicateGroups(
              store.items,
              currency: currency,
            );
            final targetGroup =
                initialDuplicateGroupKey == null
                    ? null
                    : duplicateGroups
                        .where(
                          (group) => group.groupKey == initialDuplicateGroupKey,
                        )
                        .firstOrNull;
            if (analysis.reviewItems.isEmpty && targetGroup == null) {
              return const _ReviewEmpty();
            }
            final prefixCount = targetGroup == null ? 1 : 2;
            return ListView.separated(
              padding: const EdgeInsetsDirectional.fromSTEB(
                V16Space.ml,
                V16Space.lg,
                V16Space.ml,
                V16Space.xl,
              ),
              itemCount: analysis.reviewItems.length + prefixCount,
              separatorBuilder: (_, __) => const SizedBox(height: V16Space.sm),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return FadeSlideIn(
                    child: _ReviewSummary(
                      analysis: analysis,
                      currency: currency,
                    ),
                  );
                }
                if (targetGroup != null && index == 1) {
                  return FadeSlideIn(
                    delayMs: 35,
                    child: _FocusedDuplicateGroup(
                      group: targetGroup,
                      onIgnore:
                          () => _ignoreGroup(
                            context,
                            store,
                            targetGroup,
                            closeScreen: true,
                          ),
                    ),
                  );
                }
                final item = analysis.reviewItems[index - prefixCount];
                return FadeSlideIn(
                  delayMs: index * 35,
                  child: _ReviewRow(
                    item: item,
                    currency: currency,
                    onPressed:
                        () => _showActions(context, store, item.subscription),
                  ),
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
    final duplicateGroup =
        FinancialAssistant.findDuplicateGroups(store.items, currency: currency)
            .where((group) => group.containsSubscription(subscription.id))
            .firstOrNull;
    await showCupertinoModalPopup<void>(
      context: context,
      builder:
          (sheetContext) => CupertinoActionSheet(
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
              if (duplicateGroup != null)
                CupertinoActionSheetAction(
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    await _ignoreGroup(context, store, duplicateGroup);
                  },
                  child: Text(tr('v17IgnoreDuplicate')),
                ),
            ],
            cancelButton: CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(sheetContext),
              child: Text(tr('ui_9a30dc2a96b8')),
            ),
          ),
    );
  }

  Future<void> _ignoreGroup(
    BuildContext context,
    SubscriptionStore store,
    DuplicateSubscriptionGroup group, {
    bool closeScreen = false,
  }) async {
    try {
      final ignored = await store.ignoreDuplicateGroup(group);
      if (!context.mounted) return;
      if (!ignored) {
        await _showIgnoreFailure(context);
        return;
      }
      await HapticFeedback.selectionClick();
      if (closeScreen && context.mounted) Navigator.of(context).pop();
    } catch (_) {
      if (context.mounted) await _showIgnoreFailure(context);
    }
  }

  Future<void> _showIgnoreFailure(BuildContext context) =>
      showCupertinoDialog<void>(
        context: context,
        builder:
            (dialogContext) => CupertinoAlertDialog(
              content: Text(tr('v17DuplicateIgnoreFailed')),
              actions: [
                CupertinoDialogAction(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(tr('ui_8f7d74ac0eac')),
                ),
              ],
            ),
      );
}

class _FocusedDuplicateGroup extends StatelessWidget {
  final DuplicateSubscriptionGroup group;
  final Future<void> Function() onIgnore;

  const _FocusedDuplicateGroup({required this.group, required this.onIgnore});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppCard(
      key: ValueKey('duplicate-review-${group.groupKey}'),
      tone: AppCardTone.warning,
      padding: const EdgeInsets.all(V16Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('v17DuplicateGroupTitle'),
            style: TextStyle(
              color: p.text,
              fontSize: V16Type.titleSmall,
              fontWeight: V16Type.semibold,
            ),
          ),
          const SizedBox(height: V16Space.xs),
          Text(
            tr('v17DuplicateGroupDescription'),
            style: TextStyle(
              color: p.textMuted,
              fontSize: V16Type.bodySmall,
              height: V16Type.bodyHeight,
            ),
          ),
          const SizedBox(height: V16Space.md),
          for (final subscription in group.subscriptions)
            Padding(
              padding: const EdgeInsets.only(bottom: V16Space.xs),
              child: Row(
                children: [
                  Expanded(
                    child: ServiceNameText(
                      name: subscription.name,
                      style: TextStyle(
                        color: p.text,
                        fontWeight: V16Type.semibold,
                      ),
                    ),
                  ),
                  const SizedBox(width: V16Space.sm),
                  Text(
                    fmtMoneyWithCurrency(
                      subscription.price,
                      subscription.currency,
                    ),
                    style: TextStyle(color: p.textMuted),
                  ),
                ],
              ),
            ),
          const SizedBox(height: V16Space.sm),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton.filled(
              key: const Key('ignore-duplicate-group'),
              onPressed: onIgnore,
              child: Text(tr('v17IgnoreDuplicate')),
            ),
          ),
        ],
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
    final title = localizedPlural(
      'v17DecisionItemCount',
      analysis.reviewItems.length,
    );
    final detail = tr('ui_c7ca26cba27e', {
      'value0': fmtMoneyWithCurrency(
        analysis.potentialMonthlySavings,
        currency,
      ),
    });
    return Semantics(
      container: true,
      label: '$title. $detail',
      child: AppCard(
        tone: AppCardTone.accent,
        padding: const EdgeInsets.all(V16Space.lg),
        child: ExcludeSemantics(
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: V16Colors.white.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(V16Radius.standard),
                ),
                child: const Icon(
                  CupertinoIcons.chart_bar_alt_fill,
                  color: V16Colors.white,
                ),
              ),
              const SizedBox(width: V16Space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: V16Colors.white,
                        fontSize: V16Type.body,
                        fontWeight: V16Type.semibold,
                      ),
                    ),
                    const SizedBox(height: V16Space.xxs),
                    Text(
                      detail,
                      style: const TextStyle(
                        color: Color(0xD9FFFFFF),
                        fontSize: V16Type.labelSmall,
                        height: V16Type.labelHeight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final FinancialReviewItem item;
  final String currency;
  final VoidCallback onPressed;

  const _ReviewRow({
    required this.item,
    required this.currency,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final saving = _monthlySaving(item);
    final savingLabel =
        saving > 0 ? fmtMoneyWithCurrency(saving, currency) : '';
    return AppCard(
      onTap: onPressed,
      semanticsLabel:
          '${item.subscription.name}. ${_labelFor(item.reason)}${savingLabel.isEmpty ? '' : '. $savingLabel'}',
      elevated: false,
      padding: const EdgeInsets.all(V16Space.md),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.accentSoft,
              borderRadius: BorderRadius.circular(V16Radius.compact),
            ),
            child: Icon(_iconFor(item.reason), color: p.accent),
          ),
          const SizedBox(width: V16Space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ServiceNameText(
                  name: item.subscription.name,
                  style: TextStyle(
                    color: p.text,
                    fontSize: V16Type.bodySmall,
                    fontWeight: V16Type.semibold,
                  ),
                ),
                const SizedBox(height: V16Space.xxs),
                Text(
                  _labelFor(item.reason),
                  style: TextStyle(
                    color: p.textMuted,
                    fontSize: V16Type.caption,
                  ),
                ),
              ],
            ),
          ),
          if (saving > 0)
            Text(
              savingLabel,
              style: TextStyle(
                color: p.accent,
                fontSize: V16Type.caption,
                fontWeight: V16Type.semibold,
              ),
            ),
          const SizedBox(width: V16Space.xs),
          Icon(
            Directionality.of(context) == TextDirection.rtl
                ? CupertinoIcons.chevron_left
                : CupertinoIcons.chevron_right,
            color: p.textMuted,
            size: V16Type.body,
          ),
        ],
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

  static double _monthlySaving(FinancialReviewItem item) => switch (item
      .reason) {
    FinancialReviewReason.duplicate ||
    FinancialReviewReason.unusedAutoRenewal => item.subscription.monthlyCost,
    FinancialReviewReason.priceIncrease ||
    FinancialReviewReason.overdueReview => 0,
  };
}

class _ReviewEmpty extends StatelessWidget {
  const _ReviewEmpty();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(V16Space.ml),
      child: AppEmptyState(
        icon: CupertinoIcons.checkmark_shield_fill,
        title: tr('ui_84180a00b479'),
        description: tr('ui_cc941d2bd31f'),
      ),
    ),
  );
}
