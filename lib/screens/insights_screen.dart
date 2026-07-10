/// تحليلات الإنفاق: رسم دائري تفاعلي، مؤشرات ذكية، وأعلى الاشتراكات.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/subscription.dart';
import '../services/ai_advisor.dart';
import '../services/ai_extractor.dart' show AiExtractionException;
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
        if (store.active.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Text(
                'أضف اشتراكات نشطة أولًا\nلتظهر لك تحليلات إنفاقك هنا.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.muted,
                  height: 1.8,
                  fontSize: 16,
                ),
              ),
            ),
          );
        }

        final currency = store.dominantCurrency;
        final byCategory = store.monthlyByCategory(currency);
        final sortedCats = byCategory.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final totalMonthly =
            sortedCats.fold<double>(0, (sum, e) => sum + e.value);

        final top = store.active
            .where((s) => s.currency == currency)
            .toList()
          ..sort((a, b) => b.monthlyCost.compareTo(a.monthlyCost));

        final otherCurrencies = store
            .monthlyTotals()
            .entries
            .where((e) => e.key != currency)
            .toList();

        final avgPerSub =
            top.isEmpty ? 0.0 : totalMonthly / top.length;
        final within7 = store.upcoming(withinDays: 7).length;
        final heaviest = sortedCats.isEmpty ? null : sortedCats.first;

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 132),
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'قراءة إنفاقك',
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'صورة واضحة تساعدك على اتخاذ قرار أفضل',
                    style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            FadeSlideIn(
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'توزيع مصروفك الشهري',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        SizedBox(
                          width: 150,
                          height: 150,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: const Duration(milliseconds: 1000),
                            curve: Curves.easeOutCubic,
                            builder: (context, t, _) => CustomPaint(
                              painter: _DonutPainter(
                                entries: sortedCats,
                                total: totalMonthly,
                                progress: t,
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      fmtMoney(totalMonthly, currency),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                    const Text(
                                      'شهريًا',
                                      style: TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final e in sortedCats.take(6))
                                Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: categoryColor(e.key),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 7),
                                      Expanded(
                                        child: Text(
                                          e.key,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.ink,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        totalMonthly <= 0
                                            ? ''
                                            : '${(e.value / totalMonthly * 100).round()}٪',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.muted,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (otherCurrencies.isNotEmpty) ...[
                      const Divider(height: 24),
                      Text(
                        'اشتراكات بعملات أخرى: '
                        '${otherCurrencies.map((e) => fmtMoney(e.value, e.key)).join(' + ')} شهريًا',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const FadeSlideIn(
              delayMs: 40,
              child: _AdvisorCard(),
            ),
            const SizedBox(height: 12),
            FadeSlideIn(
              delayMs: 60,
              child: _HistoryCard(
                history: store.monthlySpendHistory(currency, months: 6),
                currency: currency,
              ),
            ),
            const SizedBox(height: 12),
            FadeSlideIn(
              delayMs: 80,
              child: Row(
                children: [
                  Expanded(
                    child: _InsightChip(
                      icon: Icons.balance_rounded,
                      label: 'متوسط الاشتراك',
                      value: fmtMoney(avgPerSub, currency),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _InsightChip(
                      icon: Icons.schedule_rounded,
                      label: 'تجديد خلال ٧ أيام',
                      value: '$within7',
                    ),
                  ),
                ],
              ),
            ),
            if (heaviest != null) ...[
              const SizedBox(height: 10),
              FadeSlideIn(
                delayMs: 120,
                child: AppCard(
                  color: AppColors.goldSoft,
                  borderColor: AppColors.goldDeep,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.workspace_premium_rounded,
                        color: AppColors.gold,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'أثقل تصنيف على جيبك: «${heaviest.key}» '
                          'بـ ${fmtMoney(heaviest.value, currency)} شهريًا',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                            fontSize: 13.5,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            FadeSlideIn(
              delayMs: 160,
              child: AppCard(
                child: Row(
                  children: [
                    const Icon(
                      Icons.event_repeat_rounded,
                      color: AppColors.gold,
                      size: 30,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'توقّع إنفاقك السنوي',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            store
                                .yearlyTotals()
                                .entries
                                .map((e) => fmtMoney(e.value, e.key))
                                .join(' + '),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                              color: AppColors.gold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const SectionTitle('أغلى اشتراكاتك (شهريًا)'),
            for (var i = 0; i < top.take(5).length; i++) ...[
              FadeSlideIn(
                delayMs: 200 + i * 60,
                child: _TopTile(sub: top[i], rank: i),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 6),
            const Text(
              'نصيحة: أي اشتراك لم تستخدمه خلال آخر ٣٠ يومًا مرشّح قوي '
              'للإيقاف المؤقت — جرّب إيقافه وشاهد أثره على مصروفك أعلاه.',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 12.5,
                height: 1.7,
              ),
            ),
          ],
        );
      },
    );
  }
}


class _AdvisorCard extends StatefulWidget {
  const _AdvisorCard();

  @override
  State<_AdvisorCard> createState() => _AdvisorCardState();
}

class _AdvisorCardState extends State<_AdvisorCard> {
  bool _busy = false;

  Future<void> _run() async {
    final store = SubscriptionStore.instance;
    if (store.aiApiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'أضف مفتاح الذكاء الاصطناعي المجاني من الإعدادات أولًا',
          ),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final advice =
          await AiAdvisor.advise(
        store.items,
        store.aiApiKey,
        providerId: store.aiProvider,
      );
      if (!mounted) return;
      setState(() => _busy = false);
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Icon(
                      Icons.psychology_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'نصائح مستشارك الذكي',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: SingleChildScrollView(
                    child: Text(
                      advice,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 14.5,
                        height: 1.9,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } on AiExtractionException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر الاتصال — تأكد من الإنترنت')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.primarySoft,
      borderColor: AppColors.primary.withOpacity(.22),
      child: Row(
        children: [
          const Icon(
            Icons.psychology_rounded,
            color: AppColors.primary,
            size: 30,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'المستشار الذكي',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: AppColors.ink,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'تحليل اشتراكاتك: تكرارات، فرص توفير، وبدائل',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(84, 44),
            ),
            onPressed: _busy ? null : _run,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text('حلّل'),
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<MapEntry<String, double>> entries;
  final double total;
  final double progress;

  _DonutPainter({
    required this.entries,
    required this.total,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0 || entries.isEmpty) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 10;
    const stroke = 18.0;
    const gap = 0.045; // فجوة صغيرة بين الشرائح (راديان)

    var start = -math.pi / 2;
    for (final e in entries) {
      final sweep =
          (e.value / total) * 2 * math.pi * progress - gap;
      if (sweep <= 0) {
        start += (e.value / total) * 2 * math.pi * progress;
        continue;
      }
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = categoryColor(e.key);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start + gap / 2,
        sweep,
        false,
        paint,
      );
      start += (e.value / total) * 2 * math.pi * progress;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.progress != progress ||
      old.total != total ||
      old.entries.length != entries.length;
}

class _HistoryCard extends StatelessWidget {
  final List<MapEntry<String, double>> history;
  final String currency;

  const _HistoryCard({required this.history, required this.currency});

  @override
  Widget build(BuildContext context) {
    final maxVal = history.fold<double>(
      0,
      (m, e) => e.value > m ? e.value : m,
    );
    final trendUp = history.length >= 2 &&
        history.last.value > history[history.length - 2].value;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'إنفاقك آخر ٦ أشهر',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: AppColors.ink,
                ),
              ),
              const Spacer(),
              if (maxVal > 0)
                Text(
                  trendUp ? 'في ازدياد ↑' : 'مستقر ↓',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color:
                        trendUp ? AppColors.warn : AppColors.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 130,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < history.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          history[i].value <= 0
                              ? ''
                              : history[i].value.toStringAsFixed(0),
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TweenAnimationBuilder<double>(
                          tween: Tween(
                            begin: 0,
                            end: maxVal <= 0
                                ? 0.02
                                : (history[i].value / maxVal)
                                    .clamp(0.02, 1.0),
                          ),
                          duration: Duration(
                            milliseconds: 500 + i * 90,
                          ),
                          curve: Curves.easeOutCubic,
                          builder: (context, t, _) => Container(
                            height: 80 * t,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  AppColors.primaryDeep,
                                  AppColors.primary,
                                ],
                              ),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          history[i].key,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'محسوب من دفعات اشتراكاتك الفعلية',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InsightChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.muted,
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

class _TopTile extends StatelessWidget {
  final Subscription sub;
  final int rank;

  const _TopTile({required this.sub, required this.rank});



  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: rank == 0 ? AppColors.goldSoft : AppColors.cardAlt,
              shape: BoxShape.circle,
              border: Border.all(
                color: rank == 0 ? AppColors.goldDeep : AppColors.border,
              ),
            ),
            child: Text(
              '${rank + 1}',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: rank == 0 ? AppColors.gold : AppColors.muted,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(sub.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              sub.name,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ),
          Text(
            '${fmtMoney(sub.monthlyCost, sub.currency)} / شهر',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
