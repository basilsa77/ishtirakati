/// مركز اشتراكاتي 7: لوحة مالية مركزة للعمل اليومي واتخاذ القرار.
library;

import 'package:flutter/material.dart';

import '../models/subscription.dart';
import '../services/subscription_store.dart';
import '../theme.dart';
import 'calendar_screen.dart';
import 'edit_subscription_screen.dart';
import 'import_screen.dart';
import 'subscriptions_screen.dart' show showSubscriptionDetails;

class CommandCenterScreen extends StatelessWidget {
  const CommandCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = SubscriptionStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        if (store.items.isEmpty) return const _EmptyWorkspace();

        final currency = store.dominantCurrency;
        final monthly = store.monthlyTotals()[currency] ?? 0;
        final yearly = store.yearlyTotals()[currency] ?? 0;
        final budget = store.monthlyBudget;
        final upcoming = store.upcoming(withinDays: 14);
        final byCategory = store.monthlyByCategory(currency).entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 122),
          children: [
            const _TopBar(),
            const SizedBox(height: 14),
            _FinancialHero(
              monthly: monthly,
              yearly: yearly,
              budget: budget,
              currency: currency,
            ),
            const SizedBox(height: 14),
            _ActionGrid(
              onAdd: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EditSubscriptionScreen()),
              ),
              onImport: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ImportScreen()),
              ),
              onCalendar: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CalendarScreen()),
              ),
              onReview: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const _ReviewRoute(),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _SectionHeader(
              title: 'القرار القادم',
              subtitle: upcoming.isEmpty
                  ? 'لا توجد خصومات قريبة خلال أسبوعين'
                  : '${upcoming.length} تجديدات تحتاج انتباهك خلال 14 يومًا',
            ),
            const SizedBox(height: 10),
            if (upcoming.isEmpty)
              const _QuietState()
            else
              _UpcomingTimeline(
                subscriptions: upcoming.take(4).toList(),
                onOpen: (sub) => showSubscriptionDetails(context, sub),
              ),
            const SizedBox(height: 20),
            _SectionHeader(
              title: 'فرص التوفير',
              subtitle: 'قرارات صغيرة قد تخفّض مصروفك الشهري',
            ),
            const SizedBox(height: 10),
            _SavingsActions(
              store: store,
              currency: currency,
              monthlySavings: store.savingsFor(currency),
            ),
            const SizedBox(height: 20),
            _SectionHeader(
              title: 'خريطة المصروف',
              subtitle: 'أين يذهب مصروفك الشهري؟',
            ),
            const SizedBox(height: 10),
            _CategoryBreakdown(
              entries: byCategory.take(5).toList(),
              total: monthly,
              currency: currency,
            ),
            const SizedBox(height: 20),
            _SectionHeader(
              title: 'قيمة الاشتراكات',
              subtitle: 'سجّل الاستخدام لتعرف ما يستحق الاستمرار',
            ),
            const SizedBox(height: 10),
            _UsageReview(store: store),
          ],
        );
      },
    );
  }

}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'صباح الخير' : hour < 18 ? 'مساء الخير' : 'مساء الهدوء';
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              const Text(
                'مركزك المالي',
                style: TextStyle(color: AppColors.ink, fontSize: 23, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(
            Icons.account_balance_wallet_rounded,
            color: AppColors.primary,
            size: 22,
          ),
        ),
      ],
    );
  }
}

class _FinancialHero extends StatelessWidget {
  final double monthly;
  final double yearly;
  final double budget;
  final String currency;

  const _FinancialHero({
    required this.monthly,
    required this.yearly,
    required this.budget,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final budgetProgress = budget <= 0
        ? 0.0
        : (monthly / budget).clamp(0.0, 1.0).toDouble();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x260B6F52),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'التزامك الشهري',
                  style: TextStyle(
                    color: Color(0xD9E8FFF5),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0x26FFFFFF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'شهريًا',
                  style: TextStyle(
                    color: Color(0xE6FFFFFF),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          AnimatedMoney(
            value: monthly,
            currency: currency,
            style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w900, height: 1),
          ),
          const SizedBox(height: 4),
          Text(
            'توقع سنوي ${fmtMoney(yearly, currency)}',
            style: const TextStyle(color: Color(0xC9E8FFF5), fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 18),
          _HeroMetric(
            icon: Icons.account_balance_wallet_rounded,
            label: budget <= 0 ? 'ميزانية' : 'من الميزانية',
            value: budget <= 0 ? 'غير محددة' : '${(budgetProgress * 100).round()}٪',
            color: budget > 0 && monthly > budget ? AppColors.danger : AppColors.gold,
          ),
          if (budget > 0) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: budgetProgress,
                minHeight: 7,
                backgroundColor: const Color(0x3278FFF0),
                valueColor: AlwaysStoppedAnimation<Color>(
                  monthly > budget ? AppColors.danger : AppColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _HeroMetric({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0x26000000),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x1FFFFFFF)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Color(0xC9E8FFF5), fontSize: 10.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(value, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _ActionGrid extends StatelessWidget {
  final VoidCallback onAdd;
  final VoidCallback onImport;
  final VoidCallback onCalendar;
  final VoidCallback onReview;

  const _ActionGrid({required this.onAdd, required this.onImport, required this.onCalendar, required this.onReview});

  @override
  Widget build(BuildContext context) {
    final actions = [
      (Icons.add_circle_outline_rounded, 'إضافة', onAdd),
      (Icons.document_scanner_outlined, 'استيراد', onImport),
      (Icons.calendar_month_outlined, 'التقويم', onCalendar),
      (Icons.fact_check_outlined, 'مراجعة', onReview),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.35,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        return Tooltip(
          message: action.$2,
          child: InkWell(
            onTap: action.$3,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0F0B3D2E),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(action.$1, color: AppColors.primary, size: 19),
                  ),
                  const SizedBox(width: 8),
                  Text(action.$2, style: const TextStyle(color: AppColors.ink, fontSize: 12, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 22,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ],
      );
}

class _UpcomingTimeline extends StatelessWidget {
  final List<Subscription> subscriptions;
  final ValueChanged<Subscription> onOpen;
  const _UpcomingTimeline({required this.subscriptions, required this.onOpen});

  @override
  Widget build(BuildContext context) => AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (var i = 0; i < subscriptions.length; i++) ...[
              _UpcomingRow(sub: subscriptions[i], onTap: () => onOpen(subscriptions[i])),
              if (i != subscriptions.length - 1) const Divider(height: 1),
            ],
          ],
        ),
      );
}

class _UpcomingRow extends StatelessWidget {
  final Subscription sub;
  final VoidCallback onTap;
  const _UpcomingRow({required this.sub, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: categoryColor(sub.category).withOpacity(.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(sub.emoji, style: const TextStyle(fontSize: 21)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sub.name, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text('بعد ${sub.daysUntilRenewal()} يوم', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    fmtMoney(sub.price, sub.currency),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Icon(
                    Icons.chevron_left_rounded,
                    color: AppColors.muted,
                    size: 17,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _SavingsActions extends StatelessWidget {
  final SubscriptionStore store;
  final String currency;
  final double monthlySavings;
  const _SavingsActions({required this.store, required this.currency, required this.monthlySavings});

  @override
  Widget build(BuildContext context) {
    final unknown = store.items.where((s) => s.category == 'أخرى').length;
    final unused = store.neverUsed;
    return Column(
      children: [
        if (monthlySavings > 0)
          _ActionNotice(
            icon: Icons.savings_outlined,
            color: AppColors.primary,
            title: 'أنت توفّر بالفعل',
            detail: '${fmtMoney(monthlySavings, currency)} شهريًا من الاشتراكات الموقوفة',
          ),
        if (unused.isNotEmpty) ...[
          if (monthlySavings > 0) const SizedBox(height: 8),
          _ActionNotice(
            icon: Icons.visibility_off_outlined,
            color: AppColors.gold,
            title: 'راجع ${unused.length} اشتراكات بلا استخدام مسجل',
            detail: 'ابدأ بـ «${unused.first.name}» قبل التجديد القادم',
          ),
        ],
        if (unknown > 0) ...[
          if (monthlySavings > 0 || unused.isNotEmpty) const SizedBox(height: 8),
          _ActionNotice(
            icon: Icons.auto_awesome_outlined,
            color: AppColors.warn,
            title: '$unknown خدمات تحتاج تصنيفًا أدق',
            detail: 'افتح اشتراكاتي ثم اختر تحسين الآن',
          ),
        ],
        if (monthlySavings <= 0 && unused.isEmpty && unknown == 0)
          const _ActionNotice(
            icon: Icons.check_circle_outline_rounded,
            color: AppColors.primary,
            title: 'وضعك منظم',
            detail: 'لا توجد فرص توفير واضحة حاليًا',
          ),
      ],
    );
  }
}

class _ActionNotice extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String detail;
  const _ActionNotice({required this.icon, required this.color, required this.title, required this.detail});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: color.withOpacity(.07),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(.18)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800, fontSize: 13.5)),
                  const SizedBox(height: 2),
                  Text(detail, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _CategoryBreakdown extends StatelessWidget {
  final List<MapEntry<String, double>> entries;
  final double total;
  final String currency;
  const _CategoryBreakdown({required this.entries, required this.total, required this.currency});

  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.all(14),
        child: entries.isEmpty
            ? const Text('لا توجد بيانات كافية بعد', style: TextStyle(color: AppColors.muted))
            : Column(
                children: [
                  for (final entry in entries) ...[
                    Row(
                      children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: categoryColor(entry.key), shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(entry.key, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700, fontSize: 12.5))),
                        Text(fmtMoney(entry.value, currency), style: const TextStyle(color: AppColors.ink, fontSize: 12.5, fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: total <= 0 ? 0 : entry.value / total,
                        minHeight: 5,
                        backgroundColor: AppColors.cardAlt,
                        valueColor: AlwaysStoppedAnimation<Color>(categoryColor(entry.key)),
                      ),
                    ),
                    if (entry != entries.last) const SizedBox(height: 12),
                  ],
                ],
              ),
      );
}

class _UsageReview extends StatelessWidget {
  final SubscriptionStore store;
  const _UsageReview({required this.store});

  @override
  Widget build(BuildContext context) {
    final pending = store.neverUsed.take(3).toList();
    if (pending.isEmpty) {
      return const _ActionNotice(
        icon: Icons.verified_outlined,
        color: AppColors.primary,
        title: 'سجل استخدامك جيد',
        detail: 'استمر في تسجيل الاستخدام عند فتح الخدمة',
      );
    }
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < pending.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
              child: Row(
                children: [
                  Text(pending[i].emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 9),
                  Expanded(child: Text(pending[i].name, style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800))),
                  IconButton(
                    tooltip: 'تسجيل استخدام',
                    onPressed: () => store.recordUsage(pending[i].id),
                    icon: const Icon(Icons.check_circle_outline_rounded, color: AppColors.primary),
                  ),
                ],
              ),
            ),
            if (i != pending.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _QuietState extends StatelessWidget {
  const _QuietState();
  @override
  Widget build(BuildContext context) => const AppCard(
        child: Row(
          children: [
            Icon(Icons.event_available_outlined, color: AppColors.primary),
            SizedBox(width: 10),
            Expanded(child: Text('الأسبوعان القادمان هادئان.', style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700))),
          ],
        ),
      );
}

class _EmptyWorkspace extends StatelessWidget {
  const _EmptyWorkspace();
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.primary, size: 36),
              ),
              const SizedBox(height: 16),
              const Text('ابدأ صورة مالية أوضح', style: TextStyle(color: AppColors.ink, fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              const Text('أضف أول اشتراك وستظهر لك التوقعات والتنبيهات وفرص التوفير هنا.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, height: 1.6)),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditSubscriptionScreen())),
                icon: const Icon(Icons.add_rounded),
                label: const Text('إضافة اشتراك'),
              ),
            ],
          ),
        ),
      );
}

class _ReviewRoute extends StatelessWidget {
  const _ReviewRoute();
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('مراجعة الاشتراكات')),
        body: const _ReviewList(),
      );
}

class _ReviewList extends StatelessWidget {
  const _ReviewList();
  @override
  Widget build(BuildContext context) {
    final store = SubscriptionStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final review = store.neverUsed;
        if (review.isEmpty) {
          return const Center(child: Text('لا توجد اشتراكات تحتاج مراجعة الآن.', style: TextStyle(color: AppColors.muted)));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: review.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final sub = review[index];
            return AppCard(
              padding: const EdgeInsets.all(13),
              child: Row(
                children: [
                  Text(sub.emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(sub.name, style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w900)), Text('${fmtMoney(sub.monthlyCost, sub.currency)} شهريًا', style: const TextStyle(color: AppColors.muted, fontSize: 12))])),
                  IconButton(tooltip: 'تسجيل استخدام', onPressed: () => store.recordUsage(sub.id), icon: const Icon(Icons.check_circle_outline_rounded, color: AppColors.primary)),
                  IconButton(tooltip: 'فتح التفاصيل', onPressed: () => showSubscriptionDetails(context, sub), icon: const Icon(Icons.open_in_new_rounded, color: AppColors.muted)),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
