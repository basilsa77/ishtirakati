/// الرئيسية v2: بطاقة بطل نظيفة، أزرار سريعة، وتايم لاين مجمّع بالأيام.
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
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
            onAdd:
                () => Navigator.of(context).push(
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
          final hint = RemoteCatalog.instance.byName(sub.name)?.priceHint;
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
              builder:
                  (context, v, _) =>
                      v == null
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
                                      tr('ui_a19013d189fa', {'value0': v}),
                                      style: const TextStyle(
                                        color: AppColors.ink,
                                        fontSize: V15Type.labelSmall,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed:
                                        () => launchUrl(
                                          Uri.parse(
                                            'https://github.com/basilsa77/ishtirakati/actions',
                                          ),
                                          mode: LaunchMode.externalApplication,
                                        ),
                                    child: Text(tr('ui_69357e138dca')),
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
                    label: tr('ui_d52453ac627d'),
                    onTap:
                        () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const EditSubscriptionScreen(),
                          ),
                        ),
                  ),
                  _QuickAction(
                    icon: Icons.auto_awesome_rounded,
                    label: tr('ui_e8c12678c3b4'),
                    onTap:
                        () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ImportScreen(),
                          ),
                        ),
                  ),
                  _QuickAction(
                    icon: Icons.alternate_email_rounded,
                    label: tr('ui_cb572218fea7'),
                    onTap:
                        () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const EmailLinkScreen(),
                          ),
                        ),
                  ),
                  _QuickAction(
                    icon: Icons.calendar_month_rounded,
                    label: tr('ui_c6c25b9b516f'),
                    onTap:
                        () => Navigator.of(context).push(
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
                  title: tr('ui_47edefeab4b6'),
                  lines: [
                    for (final t in trials.take(3))
                      tr('ui_45336e9e2ab8', {
                            'value0': t.name,
                            'value1': fmtDate(t.trialEndDate!),
                          }) +
                          tr('ui_27ce6b033958', {
                            'value0': fmtMoney(t.price, t.currency),
                          }),
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
                  title: tr('ui_ad985475cbb8'),
                  lines: [
                    for (final (sub, hint) in priceAlerts.take(2))
                      tr('ui_b9b0ded20cf0', {
                            'value0': sub.name,
                            'value1': fmtMoney(sub.price, sub.currency),
                          }) +
                          tr('ui_d1feaff4c27d', {
                            'value0': fmtMoney(hint, sub.currency),
                          }),
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
                  title: tr('ui_30c2a6dcdae1'),
                  lines: [
                    tr('ui_933f0f6ac584', {'value0': neverUsed.first.name}),
                    if (neverUsed.length > 1)
                      tr('ui_7578fd03e2b1', {'value0': neverUsed.length}),
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
                          label: tr('ui_29e64deb8b19'),
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
                          label: tr('ui_98e0cd1b6e7f'),
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
                Expanded(child: SectionTitle(tr('ui_0eb554a9cdb9'))),
                TextButton.icon(
                  onPressed:
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CalendarScreen(),
                        ),
                      ),
                  icon: const Icon(Icons.calendar_month_rounded, size: 18),
                  label: Text(tr('ui_c6c25b9b516f')),
                ),
              ],
            ),
            if (upcoming.isEmpty)
              AppCard(
                child: Row(
                  children: [
                    const Icon(
                      Icons.nightlight_round,
                      color: AppColors.muted,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tr('ui_9b53e3fd945f'),
                        style: const TextStyle(color: AppColors.muted),
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
          Text(
            tr('ui_6cb053a373e8'),
            style: const TextStyle(
              color: Color(0xCC06231A),
              fontSize: V15Type.label,
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
                  fontSize: V15Type.display,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Text(
                  tr('ui_b4999a258992'),
                  style: const TextStyle(
                    color: Color(0xB306231A),
                    fontSize: V15Type.labelSmall,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0x2E062318),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                _HeroFact(
                  label: tr('ui_a1851a504669'),
                  value: fmtMoney(yearly, currency),
                ),
                _heroDivider(),
                _HeroFact(
                  label: tr('ui_99646e599b41'),
                  value: fmtMoney(daily, currency),
                ),
                _heroDivider(),
                _HeroFact(
                  label: tr('ui_629e90b3af3d'),
                  value:
                      pausedCount > 0
                          ? tr('ui_8b505e631670', {
                            'value0': activeCount,
                            'value1': pausedCount,
                          })
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
              fontSize: V15Type.bodySmall,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xCCE8FFF5),
              fontSize: V15Type.caption,
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
                fontSize: V15Type.caption,
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
                    fontSize: V15Type.label,
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
                  fontSize: V15Type.labelSmall,
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
                    fontSize: V15Type.bodySmall,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: V15Type.caption,
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
    final color =
        over
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
              Text(
                tr('ui_51839e830ce5'),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: V15Type.label,
                  color: AppColors.ink,
                ),
              ),
              const Spacer(),
              Text(
                '${fmtMoney(spent, currency)} / ${fmtMoney(budget, currency)}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: V15Type.labelSmall,
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
                builder:
                    (context, t, _) => FractionallySizedBox(
                      widthFactor: t <= 0 ? 0.01 : t,
                      child: Container(color: color),
                    ),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            over
                ? tr('ui_020e7b265152', {
                  'value0': fmtMoney(spent - budget, currency),
                })
                : tr('ui_8300f5ee63ef', {
                  'value0': fmtMoney(budget - spent, currency),
                }),
            style: TextStyle(
              color: over ? AppColors.danger : AppColors.muted,
              fontSize: V15Type.caption,
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

  static List<String> get _weekDays => [
    tr('ui_69139e9f6f75'),
    tr('ui_3e1154b18e8a'),
    tr('ui_05ae1ca23dcb'),
    tr('ui_74c564a4b5a6'),
    tr('ui_fa35e221b844'),
    tr('ui_a49412504fd0'),
    tr('ui_b74290ce11de'),
  ];

  static String _relative(int days, DateTime d) {
    if (days <= 0) return tr('ui_2422f71e7f4e');
    if (days == 1) return tr('commonTomorrow');
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
              isLastInGroup:
                  s == groups[dates[gi]]!.last && gi == dates.length - 1,
            ),
        ],
      ],
    );
  }

  Widget _dayHeader(DateTime d, List<Subscription> daySubs, bool first) {
    final today = DateTime.now();
    final days =
        DateTime(
          d.year,
          d.month,
          d.day,
        ).difference(DateTime(today.year, today.month, today.day)).inDays;
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
                BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 7),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _relative(days, d),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: V15Type.label,
            ),
          ),
          const Spacer(),
          Text(
            fmtMoney(total, ''),
            style: const TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w800,
              fontSize: V15Type.labelSmall,
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
              color: isLastInGroup ? Colors.transparent : AppColors.border,
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
                              fontSize: V15Type.label,
                              color: AppColors.ink,
                            ),
                          ),
                          Text(
                            sub.kind == PaymentKind.installment &&
                                    sub.remainingInstallments() != null
                                ? tr('ui_cd6d76c191c9', {
                                  'value0': sub.remainingInstallments(),
                                })
                                : sub.kind == PaymentKind.bill
                                ? tr('ui_e02a979a78d0', {
                                  'value0': localizedBillingCycle(
                                    sub.cycle.name,
                                  ),
                                })
                                : localizedBillingCycle(sub.cycle.name),
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: V15Type.caption,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      fmtMoney(sub.price, sub.currency),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: V15Type.bodySmall,
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
                  BoxShadow(color: Color(0x5514B886), blurRadius: 30),
                ],
              ),
              child: const Icon(
                Icons.credit_card_rounded,
                color: Colors.white,
                size: 52,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              tr('ui_24951fbd4c50'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: V15Type.title,
                fontWeight: FontWeight.w900,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr('ui_d00120a9a84f') + tr('ui_f59f967ab825'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, height: 1.6),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: Text(tr('ui_4c0420fa98b8')),
            ),
          ],
        ),
      ),
    );
  }
}
