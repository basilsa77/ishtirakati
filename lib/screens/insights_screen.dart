/// v16 insights: a calm, accessible view of local financial intelligence.
library;

import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/subscription.dart';
import '../services/ai_advisor.dart';
import '../services/ai_consent_service.dart';
import '../services/ai_extractor.dart'
    show AiExtractionException, LocalizedAiProviderInfo, aiProviderById;
import '../services/financial_assistant.dart';
import '../services/subscription_store.dart';
import '../theme.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = SubscriptionStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final currency = store.dominantCurrency;
        final entries =
            store.monthlyByCategory(currency).entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));
        final total = entries.fold<double>(
          0,
          (sum, entry) => sum + entry.value,
        );
        final history = store.monthlySpendHistory(currency, months: 6);
        final top =
            store.active.where((item) => item.currency == currency).toList()
              ..sort((a, b) => b.monthlyCost.compareTo(a.monthlyCost));
        final upcoming = store.upcoming(withinDays: 7).length;
        final average = top.isEmpty ? 0.0 : total / top.length;
        final assistant = FinancialAssistant.analyze(
          store.items,
          currency: currency,
        );

        return ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(
            V16Space.ml,
            V16Space.md,
            V16Space.ml,
            V16Space.xl,
          ),
          children: [
            const _InsightsHeader(),
            const SizedBox(height: V16Space.lg),
            if (top.isEmpty)
              const _InsightsEmpty()
            else ...[
              FadeSlideIn(
                child: _InsightHero(
                  total: total,
                  currency: currency,
                  categories: entries.length,
                ),
              ),
              const SizedBox(height: V16Space.md),
              FadeSlideIn(
                delayMs: 40,
                child: _ForecastCard(snapshot: assistant),
              ),
              const SizedBox(height: V16Space.md),
              _MetricsGrid(
                average: average,
                currency: currency,
                upcoming: upcoming,
              ),
              const SizedBox(height: V16Space.xl),
              _DistributionCard(
                entries: entries,
                total: total,
                currency: currency,
              ),
              const SizedBox(height: V16Space.xl),
              _TrendCard(history: history, currency: currency),
              const SizedBox(height: V16Space.xl),
              _InsightsLabel(tr('ui_38304db9f15d')),
              const SizedBox(height: V16Space.sm),
              for (var index = 0; index < top.take(4).length; index++) ...[
                FadeSlideIn(
                  delayMs: 60 + (index * 30),
                  child: _TopServiceRow(
                    subscription: top[index],
                    rank: index + 1,
                  ),
                ),
                const SizedBox(height: V16Space.sm),
              ],
              const SizedBox(height: V16Space.sm),
              const _AdvisorPanel(),
            ],
          ],
        );
      },
    );
  }
}

class _ForecastCard extends StatelessWidget {
  final FinancialAssistantSnapshot snapshot;

  const _ForecastCard({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final maxValue = snapshot.forecast.fold<double>(
      0,
      (value, month) => math.max(value, month.total),
    );
    final forecastMoney = fmtMoneyWithCurrency(
      snapshot.next12MonthsForecast,
      snapshot.currency,
    );
    final forecastSummary = snapshot.forecast
        .map((item) {
          return '${_monthName(item.month.month)} '
              '${fmtMoneyWithCurrency(item.total, snapshot.currency)}, '
              '${tr('ui_4e55769aaac7', {'value0': item.paymentCount})}';
        })
        .join('. ');
    return AppChartSurface(
      title: tr('ui_8798d8c93a04'),
      subtitle: tr('ui_d572be94e17f'),
      semanticsLabel:
          '${tr('ui_8798d8c93a04')}. $forecastMoney. '
          '${tr('ui_d572be94e17f')}. $forecastSummary',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                CupertinoIcons.calendar_badge_plus,
                color: p.accent,
                size: V16Type.title,
              ),
              const Spacer(),
              Text(
                forecastMoney,
                style: TextStyle(
                  color: p.accent,
                  fontSize: V16Type.labelSmall,
                  fontWeight: V16Type.semibold,
                ),
              ),
            ],
          ),
          const SizedBox(height: V16Space.md),
          SizedBox(
            height: 116,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: snapshot.forecast.length,
              separatorBuilder: (_, __) => const SizedBox(width: V16Space.xs),
              itemBuilder: (context, index) {
                final item = snapshot.forecast[index];
                final ratio = maxValue <= 0 ? 0.0 : item.total / maxValue;
                return SizedBox(
                  width: 48,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        item.total <= 0 ? '0' : item.total.toStringAsFixed(0),
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        style: TextStyle(
                          color: p.textMuted,
                          fontSize: V16Type.captionSmall,
                          fontWeight: V16Type.semibold,
                        ),
                      ),
                      Text(
                        tr('ui_4e55769aaac7', {'value0': item.paymentCount}),
                        maxLines: 1,
                        style: TextStyle(
                          color: p.textMuted,
                          fontSize: V16Type.captionSmall,
                        ),
                      ),
                      const SizedBox(height: V16Space.xxs),
                      _ForecastBar(ratio: ratio, highlighted: index == 0),
                      const SizedBox(height: V16Space.xxs),
                      Text(
                        _monthName(item.month.month),
                        style: TextStyle(
                          color: p.textMuted,
                          fontSize: V16Type.captionSmall,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _monthName(int month) =>
      [
        tr('ui_b8178e8dc532'),
        tr('ui_e55e2876d0b7'),
        tr('ui_40bf6976617c'),
        tr('ui_febf2d9a96e0'),
        tr('ui_795e5a93bd9b'),
        tr('ui_5e4422defbc2'),
        tr('ui_921d0afb33bf'),
        tr('ui_68effcdc4e3e'),
        tr('ui_a648ffa7360b'),
        tr('ui_d633d9ed1fd0'),
        tr('ui_8a239d29b450'),
        tr('ui_d4ee1840e9bb'),
      ][month - 1];
}

class _ForecastBar extends StatelessWidget {
  final double ratio;
  final bool highlighted;

  const _ForecastBar({required this.ratio, required this.highlighted});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final normalizedRatio = ratio.clamp(0.0, 1.0).toDouble();
    final target = 14.0 + (52.0 * normalizedRatio);
    final decoration = BoxDecoration(
      gradient:
          highlighted
              ? LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [p.accentStrong, p.accent],
              )
              : null,
      color: highlighted ? null : p.accentSoft,
      borderRadius: BorderRadius.circular(V16Radius.pill),
    );
    if (reduceMotion(context)) {
      return Container(
        width: V16Space.md,
        height: target,
        decoration: decoration,
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 14, end: target),
      duration: V16Motion.entrance,
      curve: V16Motion.standardCurve,
      builder:
          (context, height, _) => Container(
            width: V16Space.md,
            height: height,
            decoration: decoration,
          ),
    );
  }
}

class _InsightsHeader extends StatelessWidget {
  const _InsightsHeader();

  @override
  Widget build(BuildContext context) => AppPageIntro(
    title: tr('ui_0ccf6fbe1b40'),
    description: tr('ui_b1c64046bb33'),
  );
}

class _MetricsGrid extends StatelessWidget {
  final double average;
  final String currency;
  final int upcoming;

  const _MetricsGrid({
    required this.average,
    required this.currency,
    required this.upcoming,
  });

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      AppMetricTile(
        label: tr('ui_d734d8e10283'),
        value: fmtMoney(average, currency),
        icon: CupertinoIcons.money_dollar_circle,
      ),
      AppMetricTile(
        label: tr('ui_2bf7132fc74f'),
        value: tr('ui_81b71fad9298', {'value0': upcoming}),
        icon: CupertinoIcons.timer,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.2;
        if (largeText || constraints.maxWidth < 420) {
          return Column(
            children: [
              tiles.first,
              const SizedBox(height: V16Space.sm),
              tiles.last,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: tiles.first),
            const SizedBox(width: V16Space.sm),
            Expanded(child: tiles.last),
          ],
        );
      },
    );
  }
}

class _InsightHero extends StatelessWidget {
  final double total;
  final String currency;
  final int categories;

  const _InsightHero({
    required this.total,
    required this.currency,
    required this.categories,
  });

  @override
  Widget build(BuildContext context) {
    final totalLabel = fmtMoney(total, currency);
    return Semantics(
      container: true,
      label:
          '${tr('ui_d7c496f31754')}: $totalLabel. ${tr('ui_f916d7d0556e', {'value0': categories})}',
      child: AppCard(
        tone: AppCardTone.accent,
        padding: const EdgeInsets.all(V16Space.lg),
        child: ExcludeSemantics(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.2;
              final amount = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('ui_d7c496f31754'),
                    style: const TextStyle(
                      color: Color(0xD9FFFFFF),
                      fontSize: V16Type.caption,
                    ),
                  ),
                  const SizedBox(height: V16Space.xxs),
                  AnimatedMoney(
                    value: total,
                    currency: currency,
                    style: const TextStyle(
                      color: V16Colors.white,
                      fontSize: V16Type.headline,
                      fontWeight: V16Type.semibold,
                    ),
                  ),
                ],
              );
              final categoryLabel = Text(
                tr('ui_f916d7d0556e', {'value0': categories}),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: V16Colors.white,
                  fontSize: V16Type.caption,
                  height: V16Type.captionHeight,
                  fontWeight: V16Type.semibold,
                ),
              );
              if (largeText || constraints.maxWidth < 340) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    amount,
                    const SizedBox(height: V16Space.md),
                    categoryLabel,
                  ],
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
                      Icons.insights_rounded,
                      color: V16Colors.white,
                    ),
                  ),
                  const SizedBox(width: V16Space.sm),
                  Expanded(child: amount),
                  categoryLabel,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _InsightsLabel extends StatelessWidget {
  final String text;

  const _InsightsLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      color: context.palette.text,
      fontSize: V16Type.titleSmall,
      fontWeight: V16Type.semibold,
    ),
  );
}

class _DistributionCard extends StatelessWidget {
  final List<MapEntry<String, double>> entries;
  final double total;
  final String currency;

  const _DistributionCard({
    required this.entries,
    required this.total,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final semanticParts = entries
        .take(5)
        .map((entry) {
          final percentage =
              total <= 0 ? 0 : (entry.value / total * 100).round();
          return '${localizedCategory(entry.key)} $percentage%';
        })
        .join('. ');
    return AppChartSurface(
      title: tr('ui_5721f95a7e69'),
      subtitle: fmtMoney(total, currency),
      semanticsLabel:
          '${tr('ui_5721f95a7e69')}. ${fmtMoney(total, currency)}. $semanticParts',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth < 365 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.2;
          final chart = SizedBox(
            width: compact ? 116 : 132,
            height: compact ? 116 : 132,
            child: CustomPaint(
              painter: _DistributionPainter(
                entries: entries,
                total: total,
                track: p.surfaceAlt,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${entries.length}',
                      style: TextStyle(
                        color: p.text,
                        fontSize: V16Type.headlineSmall,
                        fontWeight: V16Type.semibold,
                      ),
                    ),
                    Text(
                      tr('ui_92c216f0e607'),
                      style: TextStyle(
                        color: p.textMuted,
                        fontSize: V16Type.caption,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
          final legend = Column(
            children: [
              for (final entry in entries.take(5))
                Padding(
                  padding: const EdgeInsets.only(bottom: V16Space.sm),
                  child: Row(
                    children: [
                      Container(
                        width: V16Space.xs,
                        height: V16Space.xs,
                        decoration: BoxDecoration(
                          color: categoryColor(entry.key),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: V16Space.xs),
                      Expanded(
                        child: Text(
                          localizedCategory(entry.key),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: p.text,
                            fontSize: V16Type.caption,
                            fontWeight: V16Type.semibold,
                          ),
                        ),
                      ),
                      Text(
                        tr('ui_bb234490a0b0', {
                          'value0':
                              total <= 0
                                  ? 0
                                  : (entry.value / total * 100).round(),
                        }),
                        style: TextStyle(
                          color: p.textMuted,
                          fontSize: V16Type.caption,
                          fontWeight: V16Type.semibold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
          if (compact) {
            return Column(
              children: [
                chart,
                const SizedBox(height: V16Space.lg),
                SizedBox(width: double.infinity, child: legend),
              ],
            );
          }
          return Row(
            children: [
              chart,
              const SizedBox(width: V16Space.lg),
              Expanded(child: legend),
            ],
          );
        },
      ),
    );
  }
}

class _DistributionPainter extends CustomPainter {
  final List<MapEntry<String, double>> entries;
  final double total;
  final Color track;

  const _DistributionPainter({
    required this.entries,
    required this.total,
    required this.track,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - V16Space.sm;
    final base =
        Paint()
          ..color = track
          ..style = PaintingStyle.stroke
          ..strokeWidth = V16Space.md
          ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, base);
    if (total <= 0) return;
    final visible = entries.where((entry) => entry.value > 0).toList();
    final gap = visible.length > 1 ? .04 : 0.0;
    final availableSweep = math.pi * 2 - (gap * visible.length);
    var start = -math.pi / 2;
    for (final entry in visible) {
      final sweep = entry.value / total * availableSweep;
      final paint =
          Paint()
            ..color = categoryColor(entry.key)
            ..style = PaintingStyle.stroke
            ..strokeWidth = V16Space.md
            ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint,
      );
      start += sweep + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DistributionPainter oldDelegate) =>
      oldDelegate.entries != entries ||
      oldDelegate.total != total ||
      oldDelegate.track != track;
}

class _TrendCard extends StatelessWidget {
  final List<MapEntry<String, double>> history;
  final String currency;

  const _TrendCard({required this.history, required this.currency});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final maxValue = history.fold<double>(
      0,
      (max, item) => math.max(max, item.value),
    );
    final current = history.isEmpty ? 0.0 : history.last.value;
    final summary = history
        .map((item) => '${item.key} ${fmtMoney(item.value, currency)}')
        .join('. ');
    return AppChartSurface(
      title: tr('ui_12e08f28e326'),
      subtitle: '${tr('ui_67636ff4cd0e')}: ${fmtMoney(current, currency)}',
      semanticsLabel: '${tr('ui_12e08f28e326')}. $summary',
      child: SizedBox(
        height: 128,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var index = 0; index < history.length; index++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: V16Space.xxs),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: _TrendBar(
                            ratio:
                                maxValue <= 0
                                    ? .05
                                    : (history[index].value / maxValue)
                                        .clamp(.05, 1.0)
                                        .toDouble(),
                            highlighted: index == history.length - 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: V16Space.xs),
                      Text(
                        history[index].key,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: p.textMuted,
                          fontSize: V16Type.caption,
                          fontWeight: V16Type.semibold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TrendBar extends StatelessWidget {
  final double ratio;
  final bool highlighted;

  const _TrendBar({required this.ratio, required this.highlighted});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final decoration = BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors:
            highlighted
                ? [p.accentStrong, p.accent]
                : [p.accentSoft, p.accent.withValues(alpha: .58)],
      ),
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(V16Radius.compact),
      ),
    );
    if (reduceMotion(context)) {
      return FractionallySizedBox(
        widthFactor: .72,
        heightFactor: ratio,
        child: DecoratedBox(decoration: decoration),
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: .05, end: ratio),
      duration: V16Motion.entrance,
      curve: V16Motion.standardCurve,
      builder:
          (context, heightFactor, child) => FractionallySizedBox(
            widthFactor: .72,
            heightFactor: heightFactor,
            child: child,
          ),
      child: DecoratedBox(decoration: decoration),
    );
  }
}

class _TopServiceRow extends StatelessWidget {
  final Subscription subscription;
  final int rank;

  const _TopServiceRow({required this.subscription, required this.rank});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      container: true,
      label:
          '$rank. ${subscription.name}. ${fmtMoneyWithCurrency(subscription.monthlyCost, subscription.currency)}',
      child: ExcludeSemantics(
        child: AppCard(
          elevated: false,
          padding: const EdgeInsets.symmetric(
            horizontal: V16Space.md,
            vertical: V16Space.sm,
          ),
          child: Row(
            children: [
              Container(
                width: 25,
                height: 25,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: rank == 1 ? p.warningSoft : p.surfaceAlt,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$rank',
                  style: TextStyle(
                    color: rank == 1 ? p.warning : p.textMuted,
                    fontSize: V16Type.caption,
                    fontWeight: V16Type.semibold,
                  ),
                ),
              ),
              const SizedBox(width: V16Space.sm),
              ServiceAvatar(
                name: subscription.name,
                emoji: subscription.emoji,
                manageUrl: subscription.manageUrl,
                iconUrl: subscription.iconUrl,
                tint: categoryColor(subscription.category),
                size: 40,
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
                        color: p.text,
                        fontSize: V16Type.label,
                        fontWeight: V16Type.semibold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subscription.displayQualifier,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: p.textMuted,
                        fontSize: V16Type.caption,
                      ),
                    ),
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 92),
                child: Text(
                  fmtMoneyWithCurrency(
                    subscription.monthlyCost,
                    subscription.currency,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.accent,
                    fontSize: V16Type.labelSmall,
                    fontWeight: V16Type.semibold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdvisorPanel extends StatefulWidget {
  const _AdvisorPanel();

  @override
  State<_AdvisorPanel> createState() => _AdvisorPanelState();
}

class _AdvisorPanelState extends State<_AdvisorPanel> {
  bool _loading = false;

  Future<void> _advise() async {
    final store = SubscriptionStore.instance;
    if (store.aiApiKey.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('ui_9bd9d2dd3287'))));
      return;
    }
    final provider = aiProviderById(store.aiProvider);
    if (!await AiConsentService.hasAdvisorConsent(provider.id)) {
      if (!mounted) return;
      var remember = true;
      final approved = await showDialog<bool>(
        context: context,
        builder:
            (dialogContext) => StatefulBuilder(
              builder:
                  (context, setDialogState) => AlertDialog(
                    title: Text(tr('ui_0fa7afa000eb')),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${tr('ui_d966ce5d4f37', {'value0': provider.localizedLabel})}'
                          '${tr('advisorFields')}.\n\n'
                          '${tr('ui_9b1aedeb7ba4')}'
                          '${tr('ui_30aec583e95d')}',
                          style: const TextStyle(height: V16Type.bodyHeight),
                        ),
                        const SizedBox(height: V16Space.sm),
                        CheckboxListTile(
                          value: remember,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(tr('ui_0230af2320da')),
                          onChanged:
                              (value) => setDialogState(
                                () => remember = value ?? false,
                              ),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: Text(tr('ui_9a30dc2a96b8')),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: Text(tr('ui_77eea08e3919')),
                      ),
                    ],
                  ),
            ),
      );
      if (approved != true) return;
      if (remember) {
        await AiConsentService.rememberAdvisorConsent(provider.id);
      }
    }
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final answer = await AiAdvisor.advise(
        store.items,
        store.aiApiKey,
        providerId: store.aiProvider,
      );
      if (!mounted) return;
      setState(() => _loading = false);
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder:
            (sheetContext) => SafeArea(
              top: false,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(sheetContext).height * .72,
                ),
                padding: const EdgeInsetsDirectional.fromSTEB(
                  V16Space.ml,
                  V16Space.sm,
                  V16Space.ml,
                  V16Space.xl,
                ),
                decoration: BoxDecoration(
                  color: sheetContext.palette.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(V16Radius.hero),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: V16Space.xxs,
                          decoration: BoxDecoration(
                            color: sheetContext.palette.stroke,
                            borderRadius: BorderRadius.circular(V16Radius.pill),
                          ),
                        ),
                      ),
                      const SizedBox(height: V16Space.lg),
                      Text(
                        tr('ui_8f0829c0c27c'),
                        style: TextStyle(
                          color: sheetContext.palette.text,
                          fontSize: V16Type.titleSmall,
                          fontWeight: V16Type.semibold,
                        ),
                      ),
                      const SizedBox(height: V16Space.sm),
                      Text(
                        answer,
                        style: TextStyle(
                          color: sheetContext.palette.text,
                          height: V16Type.bodyHeight,
                          fontSize: V16Type.label,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      );
    } on AiExtractionException catch (error) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr('ui_119b3ae79afa'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      container: true,
      label: '${tr('ui_4e0cddfd6647')}. ${tr('ui_592f4ddb5b3a')}',
      explicitChildNodes: true,
      child: AppCard(
        tone: AppCardTone.accent,
        padding: const EdgeInsets.all(V16Space.md),
        child: Row(
          children: [
            const Icon(
              Icons.auto_awesome_rounded,
              color: V16Colors.white,
              size: 25,
            ),
            const SizedBox(width: V16Space.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('ui_4e0cddfd6647'),
                    style: const TextStyle(
                      color: V16Colors.white,
                      fontWeight: V16Type.semibold,
                      fontSize: V16Type.bodySmall,
                    ),
                  ),
                  const SizedBox(height: V16Space.xxs),
                  Text(
                    tr('ui_592f4ddb5b3a'),
                    style: const TextStyle(
                      color: Color(0xD9FFFFFF),
                      fontSize: V16Type.caption,
                    ),
                  ),
                ],
              ),
            ),
            IconButton.filled(
              tooltip: tr('ui_9f6ebae84a2f'),
              style: IconButton.styleFrom(
                backgroundColor: V16Colors.white,
                foregroundColor: p.accentStrong,
              ),
              onPressed: _loading ? null : _advise,
              icon:
                  _loading
                      ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: p.accentStrong,
                        ),
                      )
                      : const Icon(Icons.arrow_back_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightsEmpty extends StatelessWidget {
  const _InsightsEmpty();

  @override
  Widget build(BuildContext context) => AppEmptyState(
    icon: Icons.query_stats_rounded,
    title: tr('ui_4b58101a9f82'),
    description: tr('ui_b1c64046bb33'),
  );
}
