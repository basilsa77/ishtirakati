/// الرئيسية: نظرة سريعة على المصروف الشهري/السنوي والتجديدات القادمة.
library;

import 'package:flutter/material.dart';

import '../models/subscription.dart';
import '../services/subscription_store.dart';
import '../theme.dart';
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
        final upcoming = store.upcoming(withinDays: 30);
        final savings = store.pausedSavingsMonthly();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _TotalsCard(monthly: monthly, yearly: yearly),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatChip(
                    label: 'اشتراك نشط',
                    value: '${store.active.length}',
                    icon: Icons.check_circle_rounded,
                    color: AppColors.primaryDeep,
                    bg: AppColors.primarySoft,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatChip(
                    label: 'موقوف مؤقتًا',
                    value: '${store.paused.length}',
                    icon: Icons.pause_circle_rounded,
                    color: const Color(0xFF9A6E0C),
                    bg: AppColors.sandSoft,
                  ),
                ),
              ],
            ),
            if (savings.isNotEmpty) ...[
              const SizedBox(height: 12),
              AppCard(
                color: AppColors.sandSoft,
                child: Row(
                  children: [
                    const Text('👏', style: TextStyle(fontSize: 26)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'إيقافك لبعض الاشتراكات يوفّر لك '
                        '${_joinMoney(savings)} شهريًا',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            const Text(
              'التجديدات القادمة (٣٠ يومًا)',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 10),
            if (upcoming.isEmpty)
              const AppCard(
                child: Row(
                  children: [
                    Text('🌙', style: TextStyle(fontSize: 24)),
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
              ...upcoming.take(6).map(
                    (s) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _UpcomingTile(sub: s),
                    ),
                  ),
          ],
        );
      },
    );
  }

  static String _joinMoney(Map<String, double> totals) {
    return totals.entries
        .map((e) => fmtMoney(e.value, e.key))
        .join(' + ');
  }
}

class _TotalsCard extends StatelessWidget {
  final Map<String, double> monthly;
  final Map<String, double> yearly;

  const _TotalsCard({required this.monthly, required this.yearly});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryDeep, AppColors.primary],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x330A6B4C),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'مصروفك الشهري على الاشتراكات',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          if (monthly.isEmpty)
            const Text(
              '0',
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w900,
              ),
            )
          else
            ...monthly.entries.map(
              (e) => Text(
                fmtMoney(e.value, e.key),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  height: 1.25,
                ),
              ),
            ),
          const SizedBox(height: 10),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'سنويًا ≈ ${yearly.entries.map((e) => fmtMoney(e.value, e.key)).join(' + ')}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
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
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Text(sub.emoji, style: const TextStyle(fontSize: 26)),
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
                  '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}'
                  ' • ${fmtMoney(sub.price, sub.currency)}',
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
            const Text('💳', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
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
