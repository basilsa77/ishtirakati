import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../design/design_tokens.dart';
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
                V12Space.lg,
                V12Space.md,
                V12Space.lg,
                V12Space.xxl,
              ),
              sliver: SliverList.list(
                children: [
                  _PulseHeader(
                    activeCount: store.active.length,
                    onSearch: onOpenCommands,
                    onAdd: () => showQuickAddSheet(context),
                  ),
                  const SizedBox(height: V12Space.lg),
                  if (store.items.isEmpty)
                    _EmptyPulse(
                      onAdd: () => showQuickAddSheet(context),
                    )
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
                              const SizedBox(width: V12Space.xl),
                              Expanded(
                                flex: 5,
                                child: _DecisionColumn(
                                  assistant: assistant,
                                  upcoming: upcoming,
                                  onOpenLibrary: onOpenLibrary,
                                  onOpenReviews: () => Navigator.of(context).push(
                                    CupertinoPageRoute(
                                      builder: (_) => FinancialReviewScreen(
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
                            const SizedBox(height: V12Space.xl),
                            _DecisionColumn(
                              assistant: assistant,
                              upcoming: upcoming,
                              onOpenLibrary: onOpenLibrary,
                              onOpenReviews: () => Navigator.of(context).push(
                                CupertinoPageRoute(
                                  builder: (_) => FinancialReviewScreen(
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
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greeting,
          style: TextStyle(
            color: context.palette.textMuted,
            fontSize: V15Type.body,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: V12Space.xxs),
        Text(
          tr('ui_e33b470d27ac'),
          style: TextStyle(
            color: context.palette.text,
            fontFamily: V15Type.displayFamily,
            fontFamilyFallback: V15Type.fallbacks,
            fontSize: V15Type.headline,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          tr('ui_d286a8d930ae', {'value0': activeCount}),
          style: TextStyle(
            color: context.palette.textMuted,
            fontSize: V15Type.caption,
          ),
        ),
      ],
    );
    final actions = Wrap(
      spacing: V12Space.xs,
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
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    if (textScale > 1.2) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          copy,
          const SizedBox(height: V12Space.sm),
          Align(alignment: AlignmentDirectional.centerEnd, child: actions),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: copy),
        const SizedBox(width: V12Space.sm),
        actions,
      ],
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
          color: emphasized
              ? context.palette.accentStrong
              : context.palette.surface,
          borderRadius: BorderRadius.circular(V12Radius.standard),
          child: SizedBox.square(
            dimension: 48,
            child: Icon(
              icon,
              color: emphasized
                  ? V12Colors.white
                  : context.palette.accent,
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
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: upcoming.isEmpty
            ? tr('ui_50680a15e64f')
            : tr('ui_0714259fe05e', {'value0': upcoming.length}),
        child: CupertinoButton(
          onPressed: onOpen,
          padding: EdgeInsets.zero,
          borderRadius: BorderRadius.circular(V12Radius.signature),
          child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.palette.surface,
          border: Border.all(color: context.palette.stroke),
          borderRadius: BorderRadius.circular(V12Radius.signature),
        ),
            child: Padding(
          padding: const EdgeInsets.all(V12Space.md),
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
                          borderRadius: BorderRadius.circular(V12Radius.standard),
                        ),
                        child: Icon(Icons.event_repeat_rounded,
                            color: context.palette.accent),
                      ),
                      SizedBox(width: V12Space.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tr('ui_67114cde38ee'),
                                style: TextStyle(
                                  color: context.palette.text,
                                  fontSize: V15Type.title,
                                  fontWeight: FontWeight.w800,
                                )),
                            Text(
                              upcoming.isEmpty
                                  ? tr('ui_500c004577c2')
                                  : tr('ui_46bcb22bca02', {'value0': upcoming.length}),
                              style: TextStyle(
                                color: context.palette.textMuted,
                                fontSize: V15Type.caption,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_back_rounded),
                    ],
                  ),
                  SizedBox(height: V12Space.lg),
                  Text(tr('ui_08965782a0af'),
                      style: TextStyle(color: context.palette.textMuted)),
                  Text(
                    fmtMoney(next12MonthsForecast, currency),
                    style: TextStyle(
                      color: context.palette.text,
                      fontSize: V15Type.headline,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (upcoming.isNotEmpty) ...[
                    const SizedBox(height: V12Space.md),
                    Divider(color: context.palette.stroke, height: 1),
                    SizedBox(height: V12Space.sm),
                    for (final item in upcoming.take(3))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: V12Space.xs),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(item.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                            Text(
                              item.daysUntilRenewal() == 0
                                  ? tr('ui_2422f71e7f4e')
                                  : tr('ui_a9d288efc42d', {'value0': item.daysUntilRenewal()}),
                              style: TextStyle(color: context.palette.textMuted),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
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
          _LeakageBand(
            snapshot: assistant,
            onReview: onOpenReviews,
          ),
          SizedBox(height: V12Space.xl),
          _SectionHeading(
            title: tr('ui_de80197a70d0'),
            detail: upcoming.isEmpty
                ? tr('ui_918e81b61c22')
                : tr('ui_04f46fabefa1', {'value0': upcoming.length}),
            onTap: onOpenLibrary,
          ),
          SizedBox(height: V12Space.sm),
          if (upcoming.isEmpty)
            _QuietLine()
          else
            for (final item in upcoming.take(4))
              _RenewalLine(subscription: item),
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
      label: reviews == 0
          ? tr('ui_6614ee580a9b')
          : tr('ui_414fcd139acc', {'value0': reviews}),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.palette.surfaceAlt,
          borderRadius: BorderRadius.circular(V12Radius.standard),
          border: BorderDirectional(
            start: BorderSide(color: context.palette.danger, width: 4),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(V12Space.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(CupertinoIcons.chart_bar_alt_fill,
                      color: context.palette.danger, size: 20),
                  SizedBox(width: V12Space.xs),
                  Expanded(
                    child: Text(
                      tr('ui_6e9931c44667'),
                      style: TextStyle(
                        color: context.palette.text,
                        fontSize: V15Type.body,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '$reviews',
                    style: TextStyle(
                      color: context.palette.danger,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              SizedBox(height: V12Space.sm),
              Text(
                reviews == 0
                    ? tr('ui_9cc5fd21d8ef')
                    : tr('ui_0b3e0a219d7f', {'value0': fmtMoney(snapshot.potentialMonthlySavings, snapshot.currency)}),
                style: TextStyle(
                  color: context.palette.textMuted,
                  fontSize: V15Type.body,
                  height: 1.5,
                ),
              ),
              if (snapshot.duplicateGroups.isNotEmpty) ...[
                SizedBox(height: V12Space.xs),
                Text(
                  tr('ui_45afc79a51a9', {'value0': snapshot.duplicateCandidateCount, 'value1': snapshot.duplicateGroups.length}),
                  style: TextStyle(
                    color: context.palette.text,
                    fontSize: V15Type.caption,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (reviews > 0) ...[
                SizedBox(height: V12Space.md),
                CupertinoButton.filled(
                  onPressed: onReview,
                  padding: const EdgeInsets.symmetric(
                    horizontal: V12Space.md,
                    vertical: V12Space.sm,
                  ),
                  child: Text(tr('ui_cd7ce5a9fe89', {'value0': reviews})),
                ),
              ],
            ],
          ),
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
                    fontSize: V15Type.title,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  detail,
                  style: TextStyle(
                    color: context.palette.textMuted,
                    fontSize: V15Type.caption,
                  ),
                ),
              ],
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.all(8),
            onPressed: onTap,
            child: Icon(CupertinoIcons.chevron_back),
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
      label: tr('ui_a8ac629bd984', {'value0': subscription.name, 'value1': days}),
      child: CupertinoButton(
        onPressed: () => showSubscriptionDetails(context, subscription),
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(V12Radius.standard),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: V12Space.sm),
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
              const SizedBox(width: V12Space.sm),
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
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      localizedDaysAfter(days),
                      style: TextStyle(
                        color: days <= 3
                            ? context.palette.danger
                            : context.palette.textMuted,
                        fontSize: V15Type.caption,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                fmtMoney(subscription.price, subscription.currency),
                style: TextStyle(
                  color: context.palette.text,
                  fontWeight: FontWeight.w800,
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
        padding: const EdgeInsets.symmetric(vertical: V12Space.lg),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline_rounded,
                color: context.palette.accent),
            SizedBox(width: V12Space.sm),
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
        padding: const EdgeInsets.symmetric(vertical: V12Space.xxl),
        child: Column(
          children: [
            Icon(Icons.radar_rounded, size: 72, color: context.palette.accent),
            SizedBox(height: V12Space.lg),
            Text(
              tr('ui_a88ab7c3c0fb'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.palette.text,
                fontSize: V15Type.title,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: V12Space.xs),
            Text(
              tr('ui_3f6a0fb930be'),
              textAlign: TextAlign.center,
              style: TextStyle(color: context.palette.textMuted),
            ),
            SizedBox(height: V12Space.lg),
            CupertinoButton.filled(
              onPressed: onAdd,
              child: Text(tr('ui_7e7a0c30b825')),
            ),
          ],
        ),
      );
}
