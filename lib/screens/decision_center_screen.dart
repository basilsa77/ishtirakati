/// v16 decision center: a local, actionable and accessible review queue.
library;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/renewal_intelligence.dart';
import '../services/subscription_store.dart';
import '../theme.dart';
import 'subscriptions_screen.dart' show showSubscriptionDetails;

class DecisionCenterScreen extends StatefulWidget {
  const DecisionCenterScreen({super.key});

  @override
  State<DecisionCenterScreen> createState() => _DecisionCenterScreenState();
}

class _DecisionCenterScreenState extends State<DecisionCenterScreen> {
  DecisionPriority? _filter;

  @override
  Widget build(BuildContext context) {
    final store = SubscriptionStore.instance;
    return Scaffold(
      appBar: AppBar(title: Text(tr('ui_28960e5355cb'))),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final all = RenewalIntelligence.decisions(store.items);
          final items =
              _filter == null
                  ? all
                  : all.where((item) => item.priority == _filter).toList();
          final urgent =
              all
                  .where((item) => item.priority == DecisionPriority.urgent)
                  .length;
          return ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(
              V16Space.ml,
              V16Space.sm,
              V16Space.ml,
              V16Space.xl,
            ),
            children: [
              FadeSlideIn(
                child: _DecisionHero(total: all.length, urgent: urgent),
              ),
              const SizedBox(height: V16Space.lg),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: tr('ui_65f276da33cf'),
                      selected: _filter == null,
                      onTap: () => setState(() => _filter = null),
                    ),
                    const SizedBox(width: V16Space.xs),
                    _FilterChip(
                      label: tr('ui_5858bf88ec0b'),
                      selected: _filter == DecisionPriority.urgent,
                      onTap:
                          () =>
                              setState(() => _filter = DecisionPriority.urgent),
                    ),
                    const SizedBox(width: V16Space.xs),
                    _FilterChip(
                      label: tr('ui_d0ac893de481'),
                      selected: _filter == DecisionPriority.high,
                      onTap:
                          () => setState(() => _filter = DecisionPriority.high),
                    ),
                    const SizedBox(width: V16Space.xs),
                    _FilterChip(
                      label: tr('ui_573fb812710c'),
                      selected: _filter == DecisionPriority.normal,
                      onTap:
                          () =>
                              setState(() => _filter = DecisionPriority.normal),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: V16Space.lg),
              if (items.isEmpty)
                const _DecisionEmpty()
              else
                for (var index = 0; index < items.length; index++) ...[
                  FadeSlideIn(
                    delayMs: index * 35,
                    child: _DecisionCard(insight: items[index]),
                  ),
                  const SizedBox(height: V16Space.sm),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _DecisionHero extends StatelessWidget {
  final int total;
  final int urgent;

  const _DecisionHero({required this.total, required this.urgent});

  @override
  Widget build(BuildContext context) {
    final detail =
        total == 0
            ? tr('ui_92a21744db1f')
            : tr('ui_23f338c9231e', {'value0': total, 'value1': urgent});
    return Semantics(
      container: true,
      label: '${tr('ui_2374a9a65ea0')}. $detail',
      child: AppCard(
        tone: AppCardTone.accent,
        padding: const EdgeInsets.all(V16Space.lg),
        child: ExcludeSemantics(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.2;
              final copy = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('ui_2374a9a65ea0'),
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
                      fontSize: V16Type.caption,
                      height: V16Type.captionHeight,
                    ),
                  ),
                ],
              );
              final count = Text(
                '$total',
                style: const TextStyle(
                  color: V16Colors.white,
                  fontSize: V16Type.headline,
                  fontWeight: V16Type.semibold,
                ),
              );
              if (largeText || constraints.maxWidth < 330) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [copy, const SizedBox(height: V16Space.md), count],
                );
              }
              return Row(
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
                      Icons.rule_folder_rounded,
                      color: V16Colors.white,
                    ),
                  ),
                  const SizedBox(width: V16Space.sm),
                  Expanded(child: copy),
                  const SizedBox(width: V16Space.sm),
                  count,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      selectedColor: p.accentStrong,
      backgroundColor: p.surface,
      side: BorderSide(color: selected ? p.accentStrong : p.stroke),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(V16Radius.pill),
      ),
      labelStyle: TextStyle(
        color: selected ? V16Colors.white : p.text,
        fontWeight: V16Type.semibold,
      ),
    );
  }
}

class _DecisionCard extends StatelessWidget {
  final DecisionInsight insight;

  const _DecisionCard({required this.insight});

  Future<void> _recordUsage(BuildContext context) async {
    await SubscriptionStore.instance.recordUsage(insight.subscription.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          tr('ui_178651ef6495', {'value0': insight.subscription.name}),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final item = insight.subscription;
    final urgent = insight.priority == DecisionPriority.urgent;
    return Semantics(
      container: true,
      label: '${insight.title}. ${insight.detail}',
      explicitChildNodes: true,
      child: AppCard(
        borderColor: urgent ? p.danger.withValues(alpha: .45) : p.stroke,
        elevated: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ServiceAvatar(
                  name: item.name,
                  emoji: item.emoji,
                  manageUrl: item.manageUrl,
                  iconUrl: item.iconUrl,
                  tint: categoryColor(item.category),
                  size: 44,
                ),
                const SizedBox(width: V16Space.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        insight.title,
                        style: TextStyle(
                          color: p.text,
                          fontSize: V16Type.label,
                          fontWeight: V16Type.semibold,
                        ),
                      ),
                      const SizedBox(height: V16Space.xxs),
                      Text(
                        insight.detail,
                        style: TextStyle(
                          color: p.textMuted,
                          fontSize: V16Type.caption,
                          height: V16Type.captionHeight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: V16Space.sm),
            Row(
              children: [
                RenewalBadge(days: item.daysUntilRenewal()),
                const Spacer(),
                if (insight.kind == DecisionKind.neverUsed ||
                    insight.kind == DecisionKind.renewalSoon)
                  IconButton(
                    tooltip: tr('ui_6a4c67c60827'),
                    onPressed: () => _recordUsage(context),
                    icon: const Icon(Icons.add_task_rounded),
                  ),
                IconButton(
                  tooltip: tr('ui_7605930f1ed9'),
                  onPressed: () => showSubscriptionDetails(context, item),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DecisionEmpty extends StatelessWidget {
  const _DecisionEmpty();

  @override
  Widget build(BuildContext context) => AppEmptyState(
    icon: Icons.verified_rounded,
    title: tr('ui_462367b2ae1a'),
    description: tr('ui_a5f497bfa756'),
  );
}
