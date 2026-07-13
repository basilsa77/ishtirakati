/// لوحة v11: التزام واضح، تدفق قريب، وقرارات قابلة للتنفيذ.
library;

import 'package:flutter/material.dart';

import '../models/subscription.dart';
import '../services/renewal_intelligence.dart';
import '../services/device_greeting.dart';
import '../services/subscription_store.dart';
import '../theme.dart';
import 'calendar_screen.dart';
import 'decision_center_screen.dart';
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
        if (store.items.isEmpty) return const _DashboardEmpty();

        final currency = store.dominantCurrency;
        final monthly = store.monthlyTotals()[currency] ?? 0;
        final yearly = store.yearlyTotals()[currency] ?? 0;
        final budget = store.monthlyBudget;
        final upcoming = store.upcoming(withinDays: 21);
        final byCategory = store.monthlyByCategory(currency).entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final decisions = RenewalIntelligence.decisions(store.items);
        final snapshot = RenewalIntelligence.snapshot(
          store.items,
          currency: currency,
        );

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          children: [
            _DashboardGreeting(activeCount: store.active.length),
            const SizedBox(height: 22),
            _CommitmentHero(
              monthly: monthly,
              yearly: yearly,
              budget: budget,
              currency: currency,
            ),
            const SizedBox(height: 10),
            _CashFlowRibbon(snapshot: snapshot),
            const SizedBox(height: 14),
            _QuickLane(
              onAdd: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EditSubscriptionScreen()),
              ),
              onImport: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ImportScreen()),
              ),
              onCalendar: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CalendarPage()),
              ),
            ),
            if (decisions.isNotEmpty) ...[
              const SizedBox(height: 24),
              _DecisionPreview(
                decisions: decisions.take(3).toList(),
                total: decisions.length,
              ),
            ],
            const SizedBox(height: 28),
            _V8SectionHeader(
              title: 'القادم على حسابك',
              detail: upcoming.isEmpty
                  ? 'الأيام الثلاثة القادمة هادئة'
                  : '${upcoming.length} عمليات قريبة خلال 21 يومًا',
            ),
            const SizedBox(height: 12),
            if (upcoming.isEmpty)
              const _CalmState()
            else
              _RenewalStrip(subscriptions: upcoming.take(5).toList()),
            const SizedBox(height: 28),
            const _V8SectionHeader(
              title: 'ملخص مصروفك',
              detail: 'لقطة سريعة تساعدك على المتابعة',
            ),
            const SizedBox(height: 12),
            _PulseGrid(
              upcoming: upcoming.length,
              unused: store.neverUsed.length,
              saved: store.savingsFor(currency),
              currency: currency,
            ),
            const SizedBox(height: 28),
            const _V8SectionHeader(
              title: 'وجهة الإنفاق',
              detail: 'أكبر التصنيفات هذا الشهر',
            ),
            const SizedBox(height: 12),
            _SpendingMap(
              entries: byCategory.take(5).toList(),
              total: monthly,
              currency: currency,
            ),
            const SizedBox(height: 28),
            const _V8SectionHeader(
              title: 'متابعة الاستخدام',
              detail: 'سجّل استخدام الخدمة لتتضح قيمتها',
            ),
            const SizedBox(height: 12),
            _UsageFocus(subscriptions: store.neverUsed.take(3).toList()),
          ],
        );
      },
    );
  }
}

class _CashFlowRibbon extends StatelessWidget {
  final RenewalSnapshot snapshot;

  const _CashFlowRibbon({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        final tiles = [
          _CashFlowTile(
            icon: Icons.bolt_rounded,
            label: 'خلال 7 أيام',
            value: snapshot.dueIn7Days == 0
                ? 'لا خصومات'
                : fmtMoney(snapshot.amountIn7Days, snapshot.currency),
          ),
          _CashFlowTile(
            icon: Icons.calendar_view_month_rounded,
            label: 'خلال 30 يومًا',
            value: '${snapshot.dueIn30Days} دفعات',
          ),
          if (snapshot.trialsEndingSoon > 0)
            _CashFlowTile(
              icon: Icons.hourglass_bottom_rounded,
              label: 'تجارب تنتهي',
              value: '${snapshot.trialsEndingSoon}',
              warning: true,
            ),
        ];
        if (compact) {
          return Column(
            children: [
              for (var index = 0; index < tiles.length; index++) ...[
                tiles[index],
                if (index != tiles.length - 1) const SizedBox(height: 8),
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var index = 0; index < tiles.length; index++) ...[
              Expanded(child: tiles[index]),
              if (index != tiles.length - 1) const SizedBox(width: 8),
            ],
          ],
        );
      },
    );
  }
}

class _CashFlowTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool warning;

  const _CashFlowTile({
    required this.icon,
    required this.label,
    required this.value,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = warning ? p.warning : p.accent;
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.stroke),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.textMuted, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DecisionPreview extends StatelessWidget {
  final List<DecisionInsight> decisions;
  final int total;

  const _DecisionPreview({required this.decisions, required this.total});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: p.stroke),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: p.accentSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.rule_rounded, color: p.accent, size: 21),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مركز القرار',
                      style: TextStyle(
                        color: p.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '$total مراجعات مرتبة حسب الأولوية',
                      style: TextStyle(color: p.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'عرض مركز القرار',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const DecisionCenterScreen(),
                  ),
                ),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < decisions.length; index++) ...[
            Row(
              children: [
                Icon(
                  decisions[index].priority == DecisionPriority.urgent
                      ? Icons.priority_high_rounded
                      : Icons.check_circle_outline_rounded,
                  color: decisions[index].priority == DecisionPriority.urgent
                      ? p.danger
                      : p.accent,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    decisions[index].title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: p.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (index != decisions.length - 1)
              Divider(color: p.stroke, height: 18),
          ],
        ],
      ),
    );
  }
}

class _DashboardGreeting extends StatelessWidget {
  final int activeCount;

  const _DashboardGreeting({required this.activeCount});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final salutation = deviceGreeting();
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                salutation,
                style: TextStyle(
                  color: p.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'مساحتك المالية',
                style: TextStyle(
                  color: p.text,
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: p.accentSoft,
            borderRadius: BorderRadius.circular(17),
          ),
          child: Text(
            '$activeCount',
            style: TextStyle(
              color: p.accent,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _CommitmentHero extends StatelessWidget {
  final double monthly;
  final double yearly;
  final double budget;
  final String currency;

  const _CommitmentHero({
    required this.monthly,
    required this.yearly,
    required this.budget,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final ratio = budget <= 0 ? 0.0 : (monthly / budget).clamp(0.0, 1.0);
    final isOver = budget > 0 && monthly > budget;
    final progressColor = isOver ? p.danger : p.accent;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: p.accentStrong,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: p.accentStrong.withValues(alpha: .30),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_rounded,
                color: Color(0xD9FFFFFF),
                size: 19,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'التزامك لهذا الشهر',
                  style: TextStyle(
                    color: Color(0xD9FFFFFF),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 112),
                child: Text(
                  'سنويًا ${fmtMoney(yearly, currency)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: Color(0xBFFFFFFF),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            fmtMoney(monthly, currency),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 35,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 22),
          if (budget <= 0)
            const Text(
              'أضف ميزانية شهرية من الإعدادات لتتابعها هنا.',
              style: TextStyle(
                color: Color(0xBFFFFFFF),
                fontSize: 12,
              ),
            )
          else ...[
            Row(
              children: [
                Text(
                  isOver ? 'تجاوزت الميزانية' : 'ضمن الميزانية',
                  style: TextStyle(
                    color: isOver ? const Color(0xFFFFC5CA) : const Color(0xCFFFFFFF),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Text(
                  '${(ratio * 100).round()}٪',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                backgroundColor: const Color(0x38FFFFFF),
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickLane extends StatelessWidget {
  final VoidCallback onAdd;
  final VoidCallback onImport;
  final VoidCallback onCalendar;

  const _QuickLane({
    required this.onAdd,
    required this.onImport,
    required this.onCalendar,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 390 ? 2 : 3;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: columns == 2 ? 2.1 : 1.35,
          children: [
            _QuickAction(icon: Icons.add_rounded, label: 'إضافة', onTap: onAdd),
            _QuickAction(icon: Icons.document_scanner_rounded, label: 'استيراد', onTap: onImport),
            _QuickAction(icon: Icons.calendar_today_rounded, label: 'التقويم', onTap: onCalendar),
          ],
        );
      },
    );
  }
}

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
    final p = context.palette;
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          height: double.infinity,
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: p.stroke),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: p.accent, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: p.text,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _V8SectionHeader extends StatelessWidget {
  final String title;
  final String detail;

  const _V8SectionHeader({required this.title, required this.detail});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: p.text,
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          detail,
          style: TextStyle(color: p.textMuted, fontSize: 12.5),
        ),
      ],
    );
  }
}

class _RenewalStrip extends StatelessWidget {
  final List<Subscription> subscriptions;

  const _RenewalStrip({required this.subscriptions});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var index = 0; index < subscriptions.length; index++) ...[
            _RenewalCard(sub: subscriptions[index]),
            if (index != subscriptions.length - 1) Divider(height: 1, color: context.palette.stroke),
          ],
        ],
      ),
    );
  }
}

class _RenewalCard extends StatelessWidget {
  final Subscription sub;

  const _RenewalCard({required this.sub});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
        onTap: () => showSubscriptionDetails(context, sub),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              ServiceAvatar(
                name: sub.name,
                emoji: sub.emoji,
                manageUrl: sub.manageUrl,
                iconUrl: sub.iconUrl,
                tint: categoryColor(sub.category),
                size: 42,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sub.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.text, fontWeight: FontWeight.w900, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text('بعد ${sub.daysUntilRenewal()} يوم', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.textMuted, fontSize: 11.5)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                fmtMoney(sub.price, sub.currency),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: p.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
    );
  }
}

class _PulseGrid extends StatelessWidget {
  final int upcoming;
  final int unused;
  final double saved;
  final String currency;

  const _PulseGrid({
    required this.upcoming,
    required this.unused,
    required this.saved,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 390 ? 2 : 3;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: columns == 2 ? 1.85 : 1.05,
          children: [
            _PulseTile(icon: Icons.notifications_active_outlined, label: 'قريب', value: '$upcoming'),
            _PulseTile(icon: Icons.visibility_off_outlined, label: 'بلا استخدام', value: '$unused'),
            _PulseTile(icon: Icons.savings_outlined, label: 'توفير', value: saved <= 0 ? '—' : fmtMoney(saved, currency)),
          ],
        );
      },
    );
  }
}

class _PulseTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _PulseTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      constraints: const BoxConstraints(minHeight: 106),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: p.accent, size: 20),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: p.text,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: p.textMuted, fontSize: 10.5)),
        ],
      ),
    );
  }
}

class _SpendingMap extends StatelessWidget {
  final List<MapEntry<String, double>> entries;
  final double total;
  final String currency;

  const _SpendingMap({
    required this.entries,
    required this.total,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (entries.isEmpty) {
      return const _CalmState(message: 'تحتاج بعض الاشتراكات لتظهر خريطة الإنفاق.');
    }
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            _CategoryLine(
              name: entries[i].key,
              amount: entries[i].value,
              total: total,
              currency: currency,
            ),
            if (i != entries.length - 1) const SizedBox(height: 16),
          ],
          const SizedBox(height: 2),
          Divider(color: p.stroke, height: 22),
          Row(
            children: [
              Text('إجمالي الشهر', style: TextStyle(color: p.textMuted, fontSize: 12)),
              const Spacer(),
              Text(
                fmtMoney(total, currency),
                style: TextStyle(color: p.text, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryLine extends StatelessWidget {
  final String name;
  final double amount;
  final double total;
  final String currency;

  const _CategoryLine({
    required this.name,
    required this.amount,
    required this.total,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = categoryColor(name);
    final value = total <= 0 ? 0.0 : amount / total;
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: p.text, fontWeight: FontWeight.w800, fontSize: 12.5),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 96),
              child: Text(
                fmtMoney(amount, currency),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: TextStyle(color: p.text, fontWeight: FontWeight.w900, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: p.surfaceAlt,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _UsageFocus extends StatelessWidget {
  final List<Subscription> subscriptions;

  const _UsageFocus({required this.subscriptions});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (subscriptions.isEmpty) {
      return const _CalmState(message: 'لا توجد خدمات تحتاج متابعة الآن.');
    }
    final store = SubscriptionStore.instance;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < subscriptions.length; i++) ...[
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: ServiceAvatar(
                name: subscriptions[i].name,
                emoji: subscriptions[i].emoji,
                manageUrl: subscriptions[i].manageUrl,
                iconUrl: subscriptions[i].iconUrl,
                tint: categoryColor(subscriptions[i].category),
                size: 40,
              ),
              title: Text(
                subscriptions[i].name,
                style: TextStyle(color: p.text, fontWeight: FontWeight.w800, fontSize: 13),
              ),
              subtitle: Text(
                'لم يُسجل له استخدام بعد',
                style: TextStyle(color: p.textMuted, fontSize: 11.5),
              ),
              trailing: IconButton(
                tooltip: 'تسجيل استخدام',
                onPressed: () => store.recordUsage(subscriptions[i].id),
                icon: Icon(Icons.check_circle_outline_rounded, color: p.accent),
              ),
            ),
            if (i != subscriptions.length - 1)
              Divider(height: 1, color: p.stroke),
          ],
        ],
      ),
    );
  }
}

class _CalmState extends StatelessWidget {
  final String message;

  const _CalmState({this.message = 'لا توجد دفعات قريبة تحتاج انتباهك.'});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: p.accentSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_rounded, color: p.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: p.text, fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardEmpty extends StatelessWidget {
  const _DashboardEmpty();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: p.accentSoft, shape: BoxShape.circle),
              child: Icon(Icons.space_dashboard_rounded, color: p.accent, size: 34),
            ),
            const SizedBox(height: 18),
            Text(
              'ابدأ مساحة مالية خاصة بك',
              textAlign: TextAlign.center,
              style: TextStyle(color: p.text, fontSize: 21, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'أضف أول اشتراك لتظهر لك الدفعات، الإنفاق، والتنبيهات في مكان واحد.',
              textAlign: TextAlign.center,
              style: TextStyle(color: p.textMuted, height: 1.6),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EditSubscriptionScreen()),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('إضافة اشتراك'),
            ),
          ],
        ),
      ),
    );
  }
}
