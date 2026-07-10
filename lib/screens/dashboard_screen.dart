/// الرئيسية v2: بطاقة بطل نظيفة، أزرار سريعة، وتايم لاين مجمّع بالأيام.
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/subscription.dart';
import '../services/remote_catalog.dart';
import '../services/subscription_store.dart';
import '../services/update_checker.dart';
import '../theme.dart';
import 'calendar_screen.dart';
import 'edit_subscription_screen.dart';
import 'email_link_screen.dart';
import 'import_screen.dart';

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
        final neverUsed = store.neverUsed;

        final priceAlerts = <(Subscription, double)>[];
        for (final sub in store.active) {
          final hint =
              RemoteCatalog.instance.byName(sub.name)?.priceHint;
          if (hint == null || hint <= 0) continue;
          if (sub.price > hint * 1.10) {
            priceAlerts.add((sub, hint));
          }
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            ValueListenableBuilder<String?>(
              valueListenable: UpdateChecker.newVersion,
              builder: (context, v, _) => v == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AppCard(
                        color: AppColors.goldSoft,
                        borderColor: AppColors.goldDeep,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.system_update_alt_rounded,
                              color: AppColors.gold,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'نسخة أحدث متاحة ($v)',
                                style: const TextStyle(
                                  color: AppColors.ink,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => launchUrl(
                                Uri.parse(
                                  'https://github.com/basilsa77/ishtirakati/actions',
                                ),
                                mode: LaunchMode.externalApplication,
                              ),
                              child: const Text('تنزيل'),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            FadeSlideIn(
              child: _HeroCard(
                monthly: monthlyMain,
                yearly: yearly[currency] ?? 0,
                activeCount: store.active.length,
                pausedCount: store.paused.length,
                currency: currency,
              ),
            ),
            const SizedBox(height: 14),
            FadeSlideIn(
              delayMs: 60,
              child: Row(
                children: [
                  _QuickAction(
                    icon: Icons.add_rounded,
                    label: 'إضافة',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const EditSubscriptionScreen(),
                      ),
                    ),
                  ),
                  _QuickAction(
                    icon: Icons.auto_awesome_rounded,
                    label: 'استيراد',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ImportScreen(),
                      ),
                    ),
                  ),
                  _QuickAction(
                    icon: Icons.alternate_email_rounded,
                    label: 'البريد',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const EmailLinkScreen(),
                      ),
                    ),
                  ),
                  _QuickAction(
                    icon: Icons.calendar_month_rounded,
                    label: 'التقويم',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CalendarScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (trials.isNotEmpty) ...[
              const SizedBox(height: 14),
              FadeSlideIn(
                delayMs: 80,
                child: _NoticeCard(
                  icon: Icons.hourglass_bottom_rounded,
                  color: AppColors.danger,
                  bg: AppColors.dangerSoft,
                  title: 'تجارب مجانية على وشك التحول لمدفوعة',
                  lines: [
                    for (final t in trials.take(3))
                      '«${t.name}» تنتهي ${fmtDate(t.trialEndDate!)} '
                          'ثم يُخصم ${fmtMoney(t.price, t.currency)}',
                  ],
                ),
              ),
            ],
            if (priceAlerts.isNotEmpty) ...[
              const SizedBox(height: 10),
              FadeSlideIn(
                delayMs: 100,
                child: _NoticeCard(
                  icon: Icons.trending_up_rounded,
                  color: AppColors.gold,
                  bg: AppColors.goldSoft,
                  title: 'تدفع أكثر من السعر المعتاد',
                  lines: [
                    for (final (sub, hint) in priceAlerts.take(2))
                      '«${sub.name}»: تدفع ${fmtMoney(sub.price, sub.currency)} '
                          'والمعتاد ${fmtMoney(hint, 'SAR')}',
                  ],
                ),
              ),
            ],
            if (budget > 0) ...[
              const SizedBox(height: 10),
              FadeSlideIn(
                delayMs: 120,
                child: _BudgetCard(
                  spent: monthlyMain,
                  budget: budget,
                  currency: currency,
                ),
              ),
            ],
            if (neverUsed.isNotEmpty) ...[
              const SizedBox(height: 10),
              FadeSlideIn(
                delayMs: 130,
                child: _NoticeCard(
                  icon: Icons.visibility_off_rounded,
                  color: AppColors.gold,
                  bg: AppColors.goldSoft,
                  title: 'راجع قيمة اشتراكاتك',
                  lines: [
                    'لم تسجل استخدام «${neverUsed.first.name}» بعد.',
                    if (neverUsed.length > 1)
                      'لديك ${neverUsed.length} اشتراكات بلا استخدام مسجل.',
                  ],
                ),
              ),
            ],
            if (savings.isNotEmpty || lifetime.isNotEmpty) ...[
              const SizedBox(height: 10),
              FadeSlideIn(
                delayMs: 140,
                child: Row(
                  children: [
                    if (lifetime.isNotEmpty)
                      Expanded(
                        child: _MiniStat(
                          icon: Icons.receipt_long_rounded,
                          color: AppColors.gold,
                          label: 'مدفوع منذ البداية',
                          value: lifetime.entries
                              .map((e) => fmtMoney(e.value, e.key))
                              .join(' + '),
                        ),
                      ),
                    if (savings.isNotEmpty && lifetime.isNotEmpty)
                      const SizedBox(width: 10),
                    if (savings.isNotEmpty)
                      Expanded(
                        child: _MiniStat(
                          icon: Icons.savings_rounded,
                          color: AppColors.primary,
                          label: 'توفير الإيقاف شهريًا',
                          value: savings.entries
                              .map((e) => fmtMoney(e.value, e.key))
                              .join(' + '),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 22),
            Row(
              children: [
                const Expanded(
                  child: SectionTitle('القادم عليك'),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CalendarScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.calendar_month_rounded, size: 18),
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
                      size: 22,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'لا خصومات خلال الشهر القادم. استرخِ!',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ),
                  ],
                ),
              )
            else
              FadeSlideIn(
                delayMs: 180,
                child: _GroupedTimeline(subs: upcoming.take(10).toList()),
              ),
          ],
        );
      },
    );
  }
}

/// بطاقة البطل: الرقم الكبير + ثلاث حقائق سريعة في سطر واحد.
class _HeroCard extends StatelessWidget {
  final double monthly;
  final double yearly;
  final int activeCount;
  final int pausedCount;
  final String currency;

  const _HeroCard({
    required this.monthly,
    required this.yearly,
    required this.activeCount,
    required this.pausedCount,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final daily = monthly * 12 / 365;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x4414B886),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'مصروفك الشهري',
            style: TextStyle(
              color: Color(0xCC06231A),
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AnimatedMoney(
                value: monthly,
                currency: currency,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(bottom: 7),
                child: Text(
                  'شهريًا',
                  style: TextStyle(
                    color: Color(0xB306231A),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 9,
            ),
            decoration: BoxDecoration(
              color: const Color(0x2E062318),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                _HeroFact(label: 'سنويًا', value: fmtMoney(yearly, currency)),
                _heroDivider(),
                _HeroFact(label: 'يوميًا', value: fmtMoney(daily, currency)),
                _heroDivider(),
                _HeroFact(
                  label: 'نشط',
                  value: pausedCount > 0
                      ? '$activeCount (+$pausedCount موقوف)'
                      : '$activeCount',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroDivider() => Container(
        width: 1,
        height: 26,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        color: const Color(0x33FFFFFF),
      );
}

class _HeroFact extends StatelessWidget {
  final String label;
  final String value;

  const _HeroFact({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xCCE8FFF5),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// زر إجراء سريع دائري.
class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Container(
              width: 54,
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(icon, color: AppColors.primary, size: 25),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// بطاقة تنبيه موحّدة (تجارب/أسعار).
class _NoticeCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bg;
  final String title;
  final List<String> lines;

  const _NoticeCard({
    required this.icon,
    required this.color,
    required this.bg,
    required this.title,
    required this.lines,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: bg,
      borderColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                '• $l',
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12.5,
                  height: 1.55,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _MiniStat({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'الميزانية الشهرية',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13.5,
                  color: AppColors.ink,
                ),
              ),
              const Spacer(),
              Text(
                '${fmtMoney(spent, currency)} / ${fmtMoney(budget, currency)}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 10,
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
          const SizedBox(height: 7),
          Text(
            over
                ? 'تجاوزت ميزانيتك بـ ${fmtMoney(spent - budget, currency)}'
                : 'متبقي ${fmtMoney(budget - spent, currency)}',
            style: TextStyle(
              color: over ? AppColors.danger : AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// تايم لاين v2: مجمّع بالأيام برؤوس تواريخ ومجموع كل يوم.
class _GroupedTimeline extends StatelessWidget {
  final List<Subscription> subs;

  const _GroupedTimeline({required this.subs});

  static const List<String> _weekDays = [
    'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس',
    'الجمعة', 'السبت', 'الأحد',
  ];

  static String _relative(int days, DateTime d) {
    if (days <= 0) return 'اليوم';
    if (days == 1) return 'غدًا';
    return '${_weekDays[d.weekday - 1]} ${d.day}/${d.month}';
  }

  static Color _urgency(int days) {
    if (days <= 1) return AppColors.danger;
    if (days <= 7) return AppColors.gold;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    // تجميع حسب تاريخ التجديد.
    final groups = <DateTime, List<Subscription>>{};
    for (final s in subs) {
      final d = s.nextRenewal();
      final key = DateTime(d.year, d.month, d.day);
      groups.putIfAbsent(key, () => []).add(s);
    }
    final dates = groups.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var gi = 0; gi < dates.length; gi++) ...[
          _dayHeader(dates[gi], groups[dates[gi]]!, gi == 0),
          for (final s in groups[dates[gi]]!)
            _TimelineCard(
              sub: s,
              color: _urgency(s.daysUntilRenewal()),
              isLastInGroup: s == groups[dates[gi]]!.last &&
                  gi == dates.length - 1,
            ),
        ],
      ],
    );
  }

  Widget _dayHeader(DateTime d, List<Subscription> daySubs, bool first) {
    final today = DateTime.now();
    final days = DateTime(d.year, d.month, d.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
    final color = _urgency(days);
    var total = 0.0;
    for (final s in daySubs) {
      total += s.price;
    }
    return Padding(
      padding: EdgeInsets.only(top: first ? 2 : 14, bottom: 8),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: color.withOpacity(0.5), blurRadius: 7),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _relative(days, d),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 13.5,
            ),
          ),
          const Spacer(),
          Text(
            fmtMoney(total, ''),
            style: const TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  final Subscription sub;
  final Color color;
  final bool isLastInGroup;

  const _TimelineCard({
    required this.sub,
    required this.color,
    required this.isLastInGroup,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 4, bottom: 8),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 2,
              margin: const EdgeInsetsDirectional.only(start: 3, end: 15),
              color: isLastInGroup
                  ? Colors.transparent
                  : AppColors.border,
            ),
            Expanded(
              child: AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                child: Row(
                  children: [
                    ServiceAvatar(
                      name: sub.name,
                      emoji: sub.emoji,
                      manageUrl: sub.manageUrl,
                      iconUrl: sub.iconUrl,
                      tint: categoryColor(sub.category),
                      size: 38,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sub.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: AppColors.ink,
                            ),
                          ),
                          Text(
                            sub.kind == PaymentKind.installment &&
                                    sub.remainingInstallments() != null
                                ? 'قسط • متبقي ${sub.remainingInstallments()}'
                                : sub.kind == PaymentKind.bill
                                    ? 'فاتورة • ${sub.cycle.labelAr}'
                                    : sub.cycle.labelAr,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      fmtMoney(sub.price, sub.currency),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: color,
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
              decoration: const BoxDecoration(
                gradient: AppColors.heroGradient,
                shape: BoxShape.circle,
                boxShadow: [
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
              'أضف اشتراكاتك وأقساطك وفواتيرك واكتشف مجموعها الحقيقي '
              'ومواعيد خصمها قبل أن تُخصم.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, height: 1.6),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('أضف أول التزام'),
            ),
          ],
        ),
      ),
    );
  }
}
