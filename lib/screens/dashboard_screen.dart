/// الرئيسية: بطاقة المصروف المتحركة، الميزانية، الإحصائيات، والتجديدات.
library;

import 'package:flutter/material.dart';

import '../models/subscription.dart';
import '../services/subscription_store.dart';
import '../theme.dart';
import 'calendar_screen.dart';
import 'edit_subscription_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = SubscriptionStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        if (store.items.isEmpty) {
          return _EmptyState(
            onAdd: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const EditSubscriptionScreen(),
              ),
            ),
          );
        }

        final monthly = store.monthlyTotals();
        final yearly = store.yearlyTotals();
        final lifetime = store.lifetimeTotals();
        final upcoming = store.upcoming(withinDays: 30);
        final savings = store.pausedSavingsMonthly();
        final trials = store.activeTrials;
        final currency = store.dominantCurrency;
        final monthlyMain = monthly[currency] ?? 0;
        final budget = store.monthlyBudget;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            FadeSlideIn(
              child: _HeroCard(
                monthly: monthly,
                yearly: yearly,
                currency: currency,
              ),
            ),
            if (trials.isNotEmpty) ...[
              const SizedBox(height: 12),
              FadeSlideIn(
                delayMs: 40,
                child: AppCard(
                  color: AppColors.dangerSoft,
                  borderColor: AppColors.danger,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'تجارب مجانية على وشك التحول لمدفوعة',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14.5,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final t in trials.take(3))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '• «${t.name}» تنتهي في ${fmtDate(t.trialEndDate!)} '
                            'ثم يُخصم ${fmtMoney(t.price, t.currency)}',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12.5,
                              height: 1.6,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            if (budget > 0) ...[
              const SizedBox(height: 12),
              FadeSlideIn(
                delayMs: 60,
                child: _BudgetCard(
                  spent: monthlyMain,
                  budget: budget,
                  currency: currency,
                ),
              ),
            ],
            const SizedBox(height: 12),
            FadeSlideIn(
              delayMs: 120,
              child: Row(
                children: [
                  Expanded(
                    child: _StatChip(
                      label: 'اشتراك نشط',
                      value: '${store.active.length}',
                      icon: Icons.check_circle_rounded,
                      color: AppColors.primary,
                      bg: AppColors.primarySoft,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatChip(
                      label: 'موقوف مؤقتًا',
                      value: '${store.paused.length}',
                      icon: Icons.pause_circle_rounded,
                      color: AppColors.gold,
                      bg: AppColors.goldSoft,
                    ),
                  ),
                ],
              ),
            ),
            if (lifetime.isNotEmpty) ...[
              const SizedBox(height: 12),
              FadeSlideIn(
                delayMs: 160,
                child: AppCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.goldSoft,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.receipt_long_rounded,
                          color: AppColors.gold,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'إجمالي ما دفعته منذ البداية',
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 12.5,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              lifetime.entries
                                  .map((e) => fmtMoney(e.value, e.key))
                                  .join(' + '),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
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
            ],
            if (savings.isNotEmpty) ...[
              const SizedBox(height: 12),
              FadeSlideIn(
                delayMs: 200,
                child: AppCard(
                  color: AppColors.primarySoft,
                  borderColor: AppColors.primaryDeep,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.savings_rounded,
                        color: AppColors.primary,
                        size: 26,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'إيقافك لبعض الاشتراكات يوفّر لك '
                          '${savings.entries.map((e) => fmtMoney(e.value, e.key)).join(' + ')} شهريًا',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(
                  child: SectionTitle('التجديدات القادمة (٣٠ يومًا)'),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CalendarScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.calendar_month_rounded, size: 19),
                  label: const Text('التقويم'),
                ),
              ],
            ),
            if (upcoming.isEmpty)
              const AppCard(
                child: Row(
                  children: [
                    Icon(
                      Icons.nightlight_round,
                      color: AppColors.muted,
                      size: 24,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'لا توجد تجديدات خلال الشهر القادم. استرخِ!',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...List.generate(
                upcoming.take(6).length,
                (i) => FadeSlideIn(
                  delayMs: 240 + i * 60,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _UpcomingTile(sub: upcoming[i]),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _HeroCard extends StatelessWidget {
  final Map<String, double> monthly;
  final Map<String, double> yearly;
  final String currency;

  const _HeroCard({
    required this.monthly,
    required this.yearly,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final mainValue = monthly[currency] ?? 0;
    final others =
        monthly.entries.where((e) => e.key != currency).toList();
    final daily = mainValue * 12 / 365;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x5514B886),
            blurRadius: 26,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x33062318),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'مصروفك الشهري',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.credit_card_rounded,
                color: Colors.white,
                size: 26,
              ),
            ],
          ),
          const SizedBox(height: 14),
          AnimatedMoney(
            value: mainValue,
            currency: currency,
            style: const TextStyle(
              color: Color(0xFF06231A),
              fontSize: 40,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          if (others.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '+ ${others.map((e) => fmtMoney(e.value, e.key)).join(' + ')}',
                style: const TextStyle(
                  color: Color(0xCC06231A),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              _HeroPill(
                text:
                    'سنويًا ≈ ${yearly.entries.map((e) => fmtMoney(e.value, e.key)).join(' + ')}',
              ),
              const SizedBox(width: 8),
              _HeroPill(text: 'يوميًا ≈ ${fmtMoney(daily, currency)}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  final String text;

  const _HeroPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0x2E062318),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  final double spent;
  final double budget;
  final String currency;

  const _BudgetCard({
    required this.spent,
    required this.budget,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = budget <= 0 ? 0.0 : (spent / budget).clamp(0.0, 1.0);
    final over = spent > budget;
    final color = over
        ? AppColors.danger
        : ratio > 0.8
            ? AppColors.warn
            : AppColors.primary;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'الميزانية الشهرية',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: AppColors.ink,
                ),
              ),
              const Spacer(),
              Text(
                '${fmtMoney(spent, currency)} / ${fmtMoney(budget, currency)}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 12,
              color: AppColors.cardAlt,
              alignment: AlignmentDirectional.centerStart,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: ratio),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (context, t, _) => FractionallySizedBox(
                  widthFactor: t <= 0 ? 0.01 : t,
                  child: Container(color: color),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            over
                ? '⚠️ تجاوزت ميزانيتك بـ ${fmtMoney(spent - budget, currency)}'
                : 'متبقي ${fmtMoney(budget - spent, currency)} من ميزانيتك',
            style: TextStyle(
              color: over ? AppColors.danger : AppColors.muted,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color bg;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UpcomingTile extends StatelessWidget {
  final Subscription sub;

  const _UpcomingTile({required this.sub});

  @override
  Widget build(BuildContext context) {
    final days = sub.daysUntilRenewal();
    final d = sub.nextRenewal();
    final catColor = categoryColor(sub.category);
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          ServiceAvatar(
            name: sub.name,
            emoji: sub.emoji,
            manageUrl: sub.manageUrl,
            tint: catColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sub.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${fmtDate(d)} • ${fmtMoney(sub.price, sub.currency)}',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          RenewalBadge(days: days),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 110,
              height: 110,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: AppColors.heroGradient,
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x5514B886),
                    blurRadius: 30,
                  ),
                ],
              ),
              child: const Icon(
                Icons.credit_card_rounded,
                color: Colors.white,
                size: 52,
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'كم تدفع فعليًا كل شهر؟',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'أضف اشتراكاتك (شاهد، نتفلكس، iCloud، النادي...) '
              'واكتشف مجموعها الحقيقي ومواعيد تجديدها قبل أن تُخصم.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, height: 1.6),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('أضف أول اشتراك'),
            ),
          ],
        ),
      ),
    );
  }
}
