import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/subscription.dart';
import '../services/financial_assistant.dart';
import '../services/device_greeting.dart';
import '../services/subscription_store.dart';
import '../theme.dart';
import 'financial_review_screen.dart';
import 'quick_add_sheet.dart';
import 'subscriptions_screen.dart' show showSubscriptionDetails;

class PulseHomeScreen extends StatelessWidget {
  final VoidCallback onOpenCommands;
  final VoidCallback onOpenLibrary;
  final VoidCallback onOpenRenewals;

  const PulseHomeScreen({
    super.key,
    required this.onOpenCommands,
    required this.onOpenLibrary,
    required this.onOpenRenewals,
  });

  @override
  Widget build(BuildContext context) {
    final store = SubscriptionStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final currency = store.dominantCurrency;
        final assistant = FinancialAssistant.analyze(
          store.items,
          currency: currency,
        );
        final upcoming = store.upcoming(withinDays: 30);
        return CustomScrollView(
          key: const PageStorageKey('v12-pulse-home'),
          slivers: [
            SliverPadding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                V16Space.lg,
                V16Space.md,
                V16Space.lg,
                V16Space.xxl,
              ),
              sliver: SliverList.list(
                children: [
                  _PulseHeader(
                    activeCount: store.active.length,
                    onSearch: onOpenCommands,
                    onAdd: () => showQuickAddSheet(context),
                  ),
                  const SizedBox(height: V16Space.lg),
                  if (store.items.isEmpty)
                    _EmptyPulse(onAdd: () => showQuickAddSheet(context))
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth >= 760) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 6,
                                child: _RenewalSummary(
                                  currency: currency,
                                  next12MonthsForecast:
                                      assistant.next12MonthsForecast,
                                  upcoming: upcoming,
                                  onOpen: onOpenRenewals,
                                ),
                              ),
                              const SizedBox(width: V16Space.xl),
                              Expanded(
                                flex: 5,
                                child: _DecisionColumn(
                                  assistant: assistant,
                                  upcoming: upcoming,
                                  onOpenLibrary: onOpenLibrary,
                                  onOpenReviews:
                                      () => Navigator.of(context).push(
                                        CupertinoPageRoute(
                                          builder:
                                              (_) => FinancialReviewScreen(
                                                currency: currency,
                                              ),
                                        ),
                                      ),
                                ),
                              ),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            _RenewalSummary(
                              currency: currency,
                              next12MonthsForecast:
                                  assistant.next12MonthsForecast,
                              upcoming: upcoming,
                              onOpen: onOpenRenewals,
                            ),
                            const SizedBox(height: V16Space.xl),
                            _DecisionColumn(
                              assistant: assistant,
                              upcoming: upcoming,
                              onOpenLibrary: onOpenLibrary,
                              onOpenReviews:
                                  () => Navigator.of(context).push(
                                    CupertinoPageRoute(
                                      builder:
                                          (_) => FinancialReviewScreen(
                                            currency: currency,
                                          ),
                                    ),
                                  ),
                            ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PulseHeader extends StatelessWidget {
  final int activeCount;
  final VoidCallback onSearch;
  final VoidCallback onAdd;

  const _PulseHeader({
    required this.activeCount,
    required this.onSearch,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final greeting = deviceGreeting();
    final actions = Wrap(
      spacing: V16Space.xs,
      children: [
        _HeaderAction(
          tooltip: tr('ui_36d82999c153'),
          icon: Icons.search_rounded,
          onTap: onSearch,
        ),
        _HeaderAction(
          tooltip: tr('ui_7e7a0c30b825'),
          icon: Icons.add_rounded,
          emphasized: true,
          onTap: onAdd,
        ),
      ],
    );
    return AppPageIntro(
      eyebrow: greeting,
      title: tr('ui_e33b470d27ac'),
      description: tr('ui_d286a8d930ae', {'value0': activeCount}),
      trailing: actions,
    );
  }
}

class _HeaderAction extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final bool emphasized;

  const _HeaderAction({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: CupertinoButton(
      onPressed: onTap,
      padding: EdgeInsets.zero,
      color:
          emphasized ? context.palette.accentStrong : context.palette.surface,
      borderRadius: BorderRadius.circular(V16Radius.standard),
      child: SizedBox.square(
        dimension: 48,
        child: Icon(
          icon,
          color: emphasized ? V16Colors.white : context.palette.accent,
        ),
      ),
    ),
  );
}

class _RenewalSummary extends StatelessWidget {
  final String currency;
  final double next12MonthsForecast;
  final List<Subscription> upcoming;
  final VoidCallback onOpen;

  const _RenewalSummary({
    required this.currency,
    required this.next12MonthsForecast,
    required this.upcoming,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: onOpen,
    semanticsLabel:
        upcoming.isEmpty
            ? tr('ui_50680a15e64f')
            : tr('ui_0714259fe05e', {'value0': upcoming.length}),
    padding: const EdgeInsets.all(V16Space.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.palette.accentSoft,
                borderRadius: BorderRadius.circular(V16Radius.standard),
              ),
              child: Icon(
                Icons.event_repeat_rounded,
                color: context.palette.accent,
              ),
            ),
            const SizedBox(width: V16Space.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('ui_67114cde38ee'),
                    style: TextStyle(
                      color: context.palette.text,
                      fontSize: V16Type.title,
                      fontWeight: V16Type.semibold,
                    ),
                  ),
                  Text(
                    upcoming.isEmpty
                        ? tr('ui_500c004577c2')
                        : tr('ui_46bcb22bca02', {'value0': upcoming.length}),
                    style: TextStyle(
                      color: context.palette.textMuted,
                      fontSize: V16Type.caption,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_back_rounded, color: context.palette.textMuted),
          ],
        ),
        const SizedBox(height: V16Space.lg),
        Text(
          tr('ui_08965782a0af'),
          style: TextStyle(color: context.palette.textMuted),
        ),
        AnimatedMoney(
          value: next12MonthsForecast,
          currency: currency,
          style: TextStyle(
            color: context.palette.text,
            fontSize: V16Type.headline,
            fontWeight: V16Type.semibold,
          ),
        ),
        if (upcoming.isNotEmpty) ...[
          const SizedBox(height: V16Space.md),
          Divider(color: context.palette.stroke, height: 1),
          const SizedBox(height: V16Space.sm),
          for (final item in upcoming.take(3))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: V16Space.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: V16Space.xs),
                  RenewalBadge(days: item.daysUntilRenewal()),
                ],
              ),
            ),
        ],
      ],
    ),
  );
}

class _DecisionColumn extends StatelessWidget {
  final FinancialAssistantSnapshot assistant;
  final List<Subscription> upcoming;
  final VoidCallback onOpenLibrary;
  final VoidCallback onOpenReviews;

  const _DecisionColumn({
    required this.assistant,
    required this.upcoming,
    required this.onOpenLibrary,
    required this.onOpenReviews,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _LeakageBand(snapshot: assistant, onReview: onOpenReviews),
      const SizedBox(height: V16Space.xl),
      _SectionHeading(
        title: tr('ui_de80197a70d0'),
        detail:
            upcoming.isEmpty
                ? tr('ui_918e81b61c22')
                : tr('ui_04f46fabefa1', {'value0': upcoming.length}),
        onTap: onOpenLibrary,
      ),
      const SizedBox(height: V16Space.sm),
      if (upcoming.isEmpty)
        const _QuietLine()
      else
        for (final item in upcoming.take(4)) _RenewalLine(subscription: item),
    ],
  );
}

class _LeakageBand extends StatelessWidget {
  final FinancialAssistantSnapshot snapshot;
  final VoidCallback onReview;

  const _LeakageBand({required this.snapshot, required this.onReview});

  @override
  Widget build(BuildContext context) {
    final reviews = snapshot.reviewItems.length;
    return Semantics(
      label:
          reviews == 0
              ? tr('ui_6614ee580a9b')
              : tr('ui_414fcd139acc', {'value0': reviews}),
      child: AppCard(
        tone: reviews == 0 ? AppCardTone.muted : AppCardTone.danger,
        elevated: reviews > 0,
        padding: const EdgeInsets.all(V16Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  CupertinoIcons.chart_bar_alt_fill,
                  color: context.palette.danger,
                  size: 20,
                ),
                const SizedBox(width: V16Space.xs),
                Expanded(
                  child: Text(
                    tr('ui_6e9931c44667'),
                    style: TextStyle(
                      color: context.palette.text,
                      fontSize: V16Type.body,
                      fontWeight: V16Type.semibold,
                    ),
                  ),
                ),
                Text(
                  '$reviews',
                  style: TextStyle(
                    color: context.palette.danger,
                    fontWeight: V16Type.semibold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: V16Space.sm),
            Text(
              reviews == 0
                  ? tr('ui_9cc5fd21d8ef')
                  : tr('ui_0b3e0a219d7f', {
                    'value0': fmtMoneyWithCurrency(
                      snapshot.potentialMonthlySavings,
                      snapshot.currency,
                    ),
                  }),
              style: TextStyle(
                color: context.palette.textMuted,
                fontSize: V16Type.body,
                height: V16Type.bodyHeight,
              ),
            ),
            if (snapshot.duplicateGroups.isNotEmpty) ...[
              const SizedBox(height: V16Space.xs),
              Text(
                tr('ui_45afc79a51a9', {
                  'value0': snapshot.duplicateCandidateCount,
                  'value1': snapshot.duplicateGroups.length,
                }),
                style: TextStyle(
                  color: context.palette.text,
                  fontSize: V16Type.caption,
                  fontWeight: V16Type.semibold,
                ),
              ),
            ],
            if (reviews > 0) ...[
              const SizedBox(height: V16Space.md),
              CupertinoButton.filled(
                onPressed: onReview,
                padding: const EdgeInsets.symmetric(
                  horizontal: V16Space.md,
                  vertical: V16Space.sm,
                ),
                child: Text(tr('ui_cd7ce5a9fe89', {'value0': reviews})),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;
  final String detail;
  final VoidCallback onTap;

  const _SectionHeading({
    required this.title,
    required this.detail,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: context.palette.text,
                fontSize: V16Type.title,
                fontWeight: V16Type.semibold,
              ),
            ),
            Text(
              detail,
              style: TextStyle(
                color: context.palette.textMuted,
                fontSize: V16Type.caption,
              ),
            ),
          ],
        ),
      ),
      CupertinoButton(
        padding: const EdgeInsets.all(V16Space.xs),
        onPressed: onTap,
        child: const Icon(CupertinoIcons.chevron_back),
      ),
    ],
  );
}

class _RenewalLine extends StatelessWidget {
  final Subscription subscription;

  const _RenewalLine({required this.subscription});

  @override
  Widget build(BuildContext context) {
    final days = subscription.daysUntilRenewal();
    return Semantics(
      button: true,
      label: tr('ui_a8ac629bd984', {
        'value0': subscription.name,
        'value1': days,
      }),
      child: CupertinoButton(
        onPressed: () => showSubscriptionDetails(context, subscription),
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(V16Radius.standard),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: V16Space.sm),
          child: Row(
            children: [
              ServiceAvatar(
                name: subscription.name,
                emoji: subscription.emoji,
                iconUrl: subscription.iconUrl,
                manageUrl: subscription.manageUrl,
                tint: categoryColor(subscription.category),
                size: 44,
              ),
              const SizedBox(width: V16Space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subscription.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.palette.text,
                        fontWeight: V16Type.semibold,
                      ),
                    ),
                    RenewalBadge(days: days),
                  ],
                ),
              ),
              Text(
                fmtMoneyWithCurrency(subscription.price, subscription.currency),
                style: TextStyle(
                  color: context.palette.text,
                  fontWeight: V16Type.semibold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuietLine extends StatelessWidget {
  const _QuietLine();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: V16Space.lg),
    child: Row(
      children: [
        Icon(Icons.check_circle_outline_rounded, color: context.palette.accent),
        const SizedBox(width: V16Space.sm),
        Text(
          tr('ui_f8fc79378323'),
          style: TextStyle(color: context.palette.textMuted),
        ),
      ],
    ),
  );
}

class _EmptyPulse extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyPulse({required this.onAdd});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: V16Space.xxl),
    child: AppEmptyState(
      icon: Icons.radar_rounded,
      title: tr('ui_a88ab7c3c0fb'),
      description: tr('ui_3f6a0fb930be'),
      actionLabel: tr('ui_7e7a0c30b825'),
      onAction: onAdd,
    ),
  );
}
