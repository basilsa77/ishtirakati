/// تحليلات v11: قراءة هادئة قابلة للتنفيذ.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/subscription.dart';
import '../services/ai_advisor.dart';
import '../services/ai_consent_service.dart';
import '../services/ai_extractor.dart'
    show AiExtractionException, aiProviderById;
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

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            const _InsightsHeader(),
            const SizedBox(height: 22),
            if (top.isEmpty)
              const _InsightsEmpty()
            else ...[
              _InsightHero(total: total, currency: currency, categories: entries.length),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _MiniMetric(label: 'متوسط الخدمة', value: fmtMoney(average, currency), icon: Icons.balance_rounded)),
                  const SizedBox(width: 10),
                  Expanded(child: _MiniMetric(label: 'خلال أسبوع', value: '$upcoming تجديد', icon: Icons.timer_outlined)),
                ],
              ),
              const SizedBox(height: 28),
              const _InsightsLabel('توزيع الالتزامات'),
              const SizedBox(height: 10),
              _DistributionCard(entries: entries, total: total, currency: currency),
              const SizedBox(height: 28),
              const _InsightsLabel('مسار الإنفاق'),
              const SizedBox(height: 10),
              _TrendCard(history: history, currency: currency),
              const SizedBox(height: 28),
              const _InsightsLabel('الخدمات الأعلى أثرًا'),
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

class _InsightsHeader extends StatelessWidget {
  const _InsightsHeader();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('تحليلاتك', style: TextStyle(color: p.text, fontSize: 27, fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        Text('قراءة مختصرة لما يذهب إليه إنفاقك.', style: TextStyle(color: p.textMuted, fontSize: 13)),
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
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('إجمالي الالتزامات الشهرية', style: TextStyle(color: p.textMuted, fontSize: 12)),
                const SizedBox(height: 4),
                Text(fmtMoney(total, currency), style: TextStyle(color: p.text, fontSize: 22, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          Text('$categories\nتصنيفات', textAlign: TextAlign.center, style: TextStyle(color: p.accent, fontSize: 11, height: 1.5, fontWeight: FontWeight.w900)),
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
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.text, fontSize: 13.5, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(color: p.textMuted, fontSize: 10.5)),
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
        style: TextStyle(color: context.palette.text, fontSize: 18, fontWeight: FontWeight.w900),
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
                    Text('${entries.length}', style: TextStyle(color: p.text, fontSize: 24, fontWeight: FontWeight.w900)),
                    Text('تصنيفات', style: TextStyle(color: p.textMuted, fontSize: 10.5)),
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
                      const SizedBox(width: 7),
                      Expanded(child: Text(entry.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.text, fontSize: 11.5, fontWeight: FontWeight.w700))),
                      Text('${total <= 0 ? 0 : (entry.value / total * 100).round()}٪', style: TextStyle(color: p.textMuted, fontSize: 11, fontWeight: FontWeight.w800)),
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
          Text('آخر 6 أشهر', style: TextStyle(color: p.textMuted, fontSize: 12)),
          const SizedBox(height: 4),
          Text(fmtMoney(current, currency), style: TextStyle(color: p.text, fontSize: 20, fontWeight: FontWeight.w900)),
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
                          Text(item.key, style: TextStyle(color: p.textMuted, fontSize: 10.5, fontWeight: FontWeight.w700)),
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
            child: Text('$rank', style: TextStyle(color: rank == 1 ? p.warning : p.textMuted, fontSize: 11, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 10),
          ServiceAvatar(name: subscription.name, emoji: subscription.emoji, manageUrl: subscription.manageUrl, iconUrl: subscription.iconUrl, tint: categoryColor(subscription.category), size: 40),
          const SizedBox(width: 10),
          Expanded(child: Text(subscription.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.text, fontSize: 13.5, fontWeight: FontWeight.w800))),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 92),
            child: Text(
              fmtMoney(subscription.monthlyCost, subscription.currency),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: p.accent, fontSize: 12.5, fontWeight: FontWeight.w900),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أضف مفتاح الذكاء الاصطناعي من الإعدادات أولًا.')));
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
            title: const Text('إرسال للتحليل الذكي؟'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'سيُرسل إلى ${provider.label}:\n'
                  '${AiConsentService.advisorFieldsAr}.\n\n'
                  'لن تُرسل مفاتيح API أو كلمة مرور البريد. يخضع المحتوى '
                  'لسياسة خصوصية المزود، ويمكنك الإلغاء الآن.',
                  style: const TextStyle(height: 1.6),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: remember,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('تذكّر موافقتي لهذا المزود'),
                  onChanged: (value) =>
                      setDialogState(() => remember = value ?? false),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('أوافق وأحلل'),
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
                  const SizedBox(height: 18),
                  Text('قراءة المستشار', style: TextStyle(color: sheetContext.palette.text, fontSize: 19, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  Text(answer, style: TextStyle(color: sheetContext.palette.text, height: 1.8, fontSize: 14)),
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر الاتصال بالمستشار الآن.')));
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
          const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 25),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('اسأل مستشارك', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                SizedBox(height: 3),
                Text('اقرأ فرص التوفير والتكرارات.', style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 11.5)),
              ],
            ),
          ),
          IconButton.filled(
            tooltip: 'تحليل ذكي',
            style: IconButton.styleFrom(backgroundColor: Colors.white, foregroundColor: p.accentStrong),
            onPressed: _loading ? null : _advise,
            icon: _loading
                ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: p.accentStrong))
                : const Icon(Icons.arrow_back_rounded),
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
          const SizedBox(height: 12),
          Text('أضف اشتراكًا نشطًا لتبدأ القراءة.', style: TextStyle(color: p.text, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
