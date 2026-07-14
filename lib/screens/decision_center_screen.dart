/// v11 decision center: a local, actionable review queue.
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
          final items = _filter == null
              ? all
              : all.where((item) => item.priority == _filter).toList();
          final urgent = all
              .where((item) => item.priority == DecisionPriority.urgent)
              .length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
            children: [
              _DecisionHero(total: all.length, urgent: urgent),
              const SizedBox(height: 18),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: tr('ui_65f276da33cf'),
                      selected: _filter == null,
                      onTap: () => setState(() => _filter = null),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: tr('ui_5858bf88ec0b'),
                      selected: _filter == DecisionPriority.urgent,
                      onTap: () => setState(
                        () => _filter = DecisionPriority.urgent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: tr('ui_d0ac893de481'),
                      selected: _filter == DecisionPriority.high,
                      onTap: () => setState(
                        () => _filter = DecisionPriority.high,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: tr('ui_573fb812710c'),
                      selected: _filter == DecisionPriority.normal,
                      onTap: () => setState(
                        () => _filter = DecisionPriority.normal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (items.isEmpty)
                const _DecisionEmpty()
              else
                for (final item in items) ...[
                  _DecisionCard(insight: item),
                  const SizedBox(height: 10),
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
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.accentStrong,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0x24FFFFFF),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.rule_folder_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('ui_2374a9a65ea0'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: V15Type.body,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  total == 0
                      ? tr('ui_92a21744db1f')
                      : tr('ui_23f338c9231e', {'value0': total, 'value1': urgent}),
                  style: const TextStyle(
                    color: Color(0xCCFFFFFF),
                    fontSize: V15Type.caption,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$total',
            style: const TextStyle(
              color: Colors.white,
              fontSize: V15Type.headline,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
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
      labelStyle: TextStyle(
        color: selected ? Colors.white : p.text,
        fontWeight: FontWeight.w800,
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
      SnackBar(content: Text(tr('ui_178651ef6495', {'value0': insight.subscription.name}))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final item = insight.subscription;
    final urgent = insight.priority == DecisionPriority.urgent;
    return AppCard(
      borderColor: urgent ? p.danger.withValues(alpha: .45) : p.stroke,
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
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      insight.title,
                      style: TextStyle(
                        color: p.text,
                        fontSize: V15Type.label,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      insight.detail,
                      style: TextStyle(
                        color: p.textMuted,
                        fontSize: V15Type.caption,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
    );
  }
}

class _DecisionEmpty extends StatelessWidget {
  const _DecisionEmpty();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 70),
      child: Column(
        children: [
          Icon(Icons.verified_rounded, color: p.accent, size: 46),
          const SizedBox(height: 12),
          Text(
            tr('ui_462367b2ae1a'),
            style: TextStyle(
              color: p.text,
              fontSize: V15Type.body,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            tr('ui_a5f497bfa756'),
            textAlign: TextAlign.center,
            style: TextStyle(color: p.textMuted, fontSize: V15Type.labelSmall),
          ),
        ],
      ),
    );
  }
}
