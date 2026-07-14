/// تحليلات v11: قراءة هادئة قابلة للتنفيذ.
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
        final entries = store.monthlyByCategory(currency).entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final total = entries.fold<double>(0, (sum, entry) => sum + entry.value);
        final history = store.monthlySpendHistory(currency, months: 6);
        final top = store.active.where((item) => item.currency == currency).toList()
          ..sort((a, b) => b.monthlyCost.compareTo(a.monthlyCost));
        final upcoming = store.upcoming(withinDays: 7).length;
        final average = top.isEmpty ? 0.0 : total / top.length;
        final assistant = FinancialAssistant.analyze(
          store.items,
          currency: currency,
        );

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            _InsightsHeader(),
            SizedBox(height: 22),
            if (top.isEmpty)
              _InsightsEmpty()
            else ...[
              _InsightHero(total: total, currency: currency, categories: entries.length),
              SizedBox(height: 14),
              _ForecastCard(snapshot: assistant),
              SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _MiniMetric(label: tr('ui_d734d8e10283'), value: fmtMoney(average, currency), icon: CupertinoIcons.money_dollar_circle)),
                  SizedBox(width: 10),
                  Expanded(child: _MiniMetric(label: tr('ui_2bf7132fc74f'), value: tr('ui_81b71fad9298', {'value0': upcoming}), icon: CupertinoIcons.timer)),
                ],
              ),
              SizedBox(height: 28),
              _InsightsLabel(tr('ui_5721f95a7e69')),
              SizedBox(height: 10),
              _DistributionCard(entries: entries, total: total, currency: currency),
              SizedBox(height: 28),
              _InsightsLabel(tr('ui_12e08f28e326')),
              SizedBox(height: 10),
              _TrendCard(history: history, currency: currency),
              SizedBox(height: 28),
              _InsightsLabel(tr('ui_38304db9f15d')),
              const SizedBox(height: 10),
              for (var index = 0; index < top.take(4).length; index++) ...[
                _TopServiceRow(subscription: top[index], rank: index + 1),
                const SizedBox(height: 9),
              ],
              const SizedBox(height: 18),
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(CupertinoIcons.calendar_badge_plus, color: p.accent, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(tr('ui_8798d8c93a04'), style: TextStyle(color: p.text, fontSize: V15Type.body, fontWeight: FontWeight.w800)),
              ),
              Text(
                fmtMoney(snapshot.next12MonthsForecast, snapshot.currency),
                style: TextStyle(color: p.accent, fontSize: V15Type.caption, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(tr('ui_d572be94e17f'), style: TextStyle(color: p.textMuted, fontSize: V15Type.caption)),
          const SizedBox(height: 18),
          SizedBox(
            height: 106,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: snapshot.forecast.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = snapshot.forecast[index];
                final ratio = maxValue <= 0 ? 0.0 : item.total / maxValue;
                return SizedBox(
                  width: 46,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        item.total <= 0 ? '0' : item.total.toStringAsFixed(0),
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        style: TextStyle(color: p.textMuted, fontSize: V15Type.captionSmall, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        tr('ui_4e55769aaac7', {'value0': item.paymentCount}),
                        maxLines: 1,
                        style: TextStyle(
                          color: p.textMuted,
                          fontSize: V15Type.captionSmall,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 18,
                        height: 12 + (48 * ratio),
                        decoration: BoxDecoration(
                          color: index == 0 ? p.accent : p.accentSoft,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        _monthName(item.month.month),
                        style: TextStyle(color: p.textMuted, fontSize: V15Type.captionSmall),
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

  static String _monthName(int month) => [
        tr('ui_b8178e8dc532'), tr('ui_e55e2876d0b7'), tr('ui_40bf6976617c'), tr('ui_febf2d9a96e0'), tr('ui_795e5a93bd9b'), tr('ui_5e4422defbc2'),
        tr('ui_921d0afb33bf'), tr('ui_68effcdc4e3e'), tr('ui_a648ffa7360b'), tr('ui_d633d9ed1fd0'), tr('ui_8a239d29b450'), tr('ui_d4ee1840e9bb'),
      ][month - 1];
}

class _InsightsHeader extends StatelessWidget {
  const _InsightsHeader();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('ui_0ccf6fbe1b40'), style: TextStyle(color: p.text, fontSize: V15Type.headlineSmall, fontWeight: FontWeight.w900)),
        SizedBox(height: 5),
        Text(tr('ui_b1c64046bb33'), style: TextStyle(color: p.textMuted, fontSize: V15Type.labelSmall)),
      ],
    );
  }
}

class _InsightHero extends StatelessWidget {
  final double total;
  final String currency;
  final int categories;

  const _InsightHero({required this.total, required this.currency, required this.categories});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.stroke),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: p.accentSoft, borderRadius: BorderRadius.circular(16)),
            child: Icon(Icons.insights_rounded, color: p.accent),
          ),
          SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('ui_d7c496f31754'), style: TextStyle(color: p.textMuted, fontSize: V15Type.caption)),
                SizedBox(height: 4),
                Text(fmtMoney(total, currency), style: TextStyle(color: p.text, fontSize: V15Type.title, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          Text(tr('ui_f916d7d0556e', {'value0': categories}), textAlign: TextAlign.center, style: TextStyle(color: p.accent, fontSize: V15Type.caption, height: 1.5, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MiniMetric({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: p.stroke)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: p.accent, size: 20),
          const SizedBox(height: 14),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.text, fontSize: V15Type.label, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(color: p.textMuted, fontSize: V15Type.caption)),
        ],
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
        style: TextStyle(color: context.palette.text, fontSize: V15Type.titleSmall, fontWeight: FontWeight.w900),
      );
}

class _DistributionCard extends StatelessWidget {
  final List<MapEntry<String, double>> entries;
  final double total;
  final String currency;

  const _DistributionCard({required this.entries, required this.total, required this.currency});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 365;
          final chart = SizedBox(
            width: compact ? 112 : 128,
            height: compact ? 112 : 128,
            child: CustomPaint(
              painter: _DistributionPainter(entries: entries, total: total, track: p.surfaceAlt),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${entries.length}', style: TextStyle(color: p.text, fontSize: V15Type.headlineSmall, fontWeight: FontWeight.w900)),
                    Text(tr('ui_92c216f0e607'), style: TextStyle(color: p.textMuted, fontSize: V15Type.caption)),
                  ],
                ),
              ),
            ),
          );
          final legend = Column(
            children: [
              for (final entry in entries.take(5))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: categoryColor(entry.key), shape: BoxShape.circle)),
                      SizedBox(width: 7),
                      Expanded(child: Text(localizedCategory(entry.key), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.text, fontSize: V15Type.caption, fontWeight: FontWeight.w700))),
                      Text(tr('ui_bb234490a0b0', {'value0': total <= 0 ? 0 : (entry.value / total * 100).round()}), style: TextStyle(color: p.textMuted, fontSize: V15Type.caption, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
            ],
          );
          return compact
              ? Column(
                  children: [
                    chart,
                    const SizedBox(height: 18),
                    SizedBox(width: double.infinity, child: legend),
                  ],
                )
              : Row(children: [chart, const SizedBox(width: 16), Expanded(child: legend)]);
        },
      ),
    );
  }
}

class _DistributionPainter extends CustomPainter {
  final List<MapEntry<String, double>> entries;
  final double total;
  final Color track;

  const _DistributionPainter({required this.entries, required this.total, required this.track});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 9;
    final base = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = 15
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, base);
    if (total <= 0) return;
    var start = -math.pi / 2;
    for (final entry in entries) {
      final sweep = math.max(0.035, entry.value / total * (math.pi * 2 - .20));
      final paint = Paint()
        ..color = categoryColor(entry.key)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 15
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start, sweep, false, paint);
      start += sweep + .04;
    }
  }

  @override
  bool shouldRepaint(covariant _DistributionPainter oldDelegate) => oldDelegate.entries != entries || oldDelegate.total != total || oldDelegate.track != track;
}

class _TrendCard extends StatelessWidget {
  final List<MapEntry<String, double>> history;
  final String currency;

  const _TrendCard({required this.history, required this.currency});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final maxValue = history.fold<double>(0, (max, item) => math.max(max, item.value));
    final current = history.isEmpty ? 0.0 : history.last.value;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('ui_67636ff4cd0e'), style: TextStyle(color: p.textMuted, fontSize: V15Type.caption)),
          const SizedBox(height: 4),
          Text(fmtMoney(current, currency), style: TextStyle(color: p.text, fontSize: V15Type.title, fontWeight: FontWeight.w900)),
          const SizedBox(height: 18),
          SizedBox(
            height: 118,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final item in history)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                heightFactor: maxValue <= 0 ? .05 : (item.value / maxValue).clamp(.05, 1.0),
                                child: Container(
                                  decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(item.key, style: TextStyle(color: p.textMuted, fontSize: V15Type.caption, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
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
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 25,
            height: 25,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: rank == 1 ? p.warningSoft : p.surfaceAlt, shape: BoxShape.circle),
            child: Text('$rank', style: TextStyle(color: rank == 1 ? p.warning : p.textMuted, fontSize: V15Type.caption, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 10),
          ServiceAvatar(name: subscription.name, emoji: subscription.emoji, manageUrl: subscription.manageUrl, iconUrl: subscription.iconUrl, tint: categoryColor(subscription.category), size: 40),
          const SizedBox(width: 10),
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
                    fontSize: V15Type.label,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subscription.displayQualifier,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.textMuted, fontSize: V15Type.caption),
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 92),
            child: Text(
              fmtMoney(subscription.monthlyCost, subscription.currency),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: p.accent, fontSize: V15Type.labelSmall, fontWeight: FontWeight.w900),
            ),
          ),
        ],
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('ui_9bd9d2dd3287'))));
      return;
    }
    final provider = aiProviderById(store.aiProvider);
    if (!await AiConsentService.hasAdvisorConsent(provider.id)) {
      if (!mounted) return;
      var remember = true;
      final approved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(tr('ui_0fa7afa000eb')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('ui_d966ce5d4f37', {'value0': provider.localizedLabel}) +
                  '${tr('advisorFields')}.\n\n' +
                  tr('ui_9b1aedeb7ba4') +
                  tr('ui_30aec583e95d'),
                  style: TextStyle(height: 1.6),
                ),
                SizedBox(height: 12),
                CheckboxListTile(
                  value: remember,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(tr('ui_0230af2320da')),
                  onChanged: (value) =>
                      setDialogState(() => remember = value ?? false),
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
      final answer = await AiAdvisor.advise(store.items, store.aiApiKey, providerId: store.aiProvider);
      if (!mounted) return;
      setState(() => _loading = false);
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (sheetContext) => SafeArea(
          top: false,
          child: Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * .72),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            decoration: BoxDecoration(color: sheetContext.palette.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: sheetContext.palette.stroke, borderRadius: BorderRadius.circular(99)))),
                  SizedBox(height: 18),
                  Text(tr('ui_8f0829c0c27c'), style: TextStyle(color: sheetContext.palette.text, fontSize: V15Type.titleSmall, fontWeight: FontWeight.w900)),
                  SizedBox(height: 12),
                  Text(answer, style: TextStyle(color: sheetContext.palette.text, height: 1.8, fontSize: V15Type.label)),
                ],
              ),
            ),
          ),
        ),
      );
    } on AiExtractionException catch (error) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('ui_119b3ae79afa'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: p.accentStrong, borderRadius: BorderRadius.circular(22)),
      child: Row(
        children: [
          Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 25),
          SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('ui_4e0cddfd6647'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: V15Type.bodySmall)),
                SizedBox(height: 3),
                Text(tr('ui_592f4ddb5b3a'), style: TextStyle(color: Color(0xCCFFFFFF), fontSize: V15Type.caption)),
              ],
            ),
          ),
          IconButton.filled(
            tooltip: tr('ui_9f6ebae84a2f'),
            style: IconButton.styleFrom(backgroundColor: Colors.white, foregroundColor: p.accentStrong),
            onPressed: _loading ? null : _advise,
            icon: _loading
                ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: p.accentStrong))
                : Icon(Icons.arrow_back_rounded),
          ),
        ],
      ),
    );
  }
}

class _InsightsEmpty extends StatelessWidget {
  const _InsightsEmpty();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        children: [
          Icon(Icons.query_stats_rounded, size: 44, color: p.textMuted),
          SizedBox(height: 12),
          Text(tr('ui_4b58101a9f82'), style: TextStyle(color: p.text, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
