/// تحليلات الإنفاق: توزيع التصنيفات، أغلى الاشتراكات، والتوقع السنوي.
library;

import 'package:flutter/material.dart';

import '../data/presets.dart';
import '../services/subscription_store.dart';
import '../models/subscription.dart';
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
                '📊\n\nأضف اشتراكات نشطة أولًا\nلتظهر لك تحليلات إنفاقك هنا.',
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
        final maxVal =
            sortedCats.isEmpty ? 1.0 : sortedCats.first.value;

        final top = store.active
            .where((s) => s.currency == currency)
            .toList()
          ..sort((a, b) => b.monthlyCost.compareTo(a.monthlyCost));

        final otherCurrencies = store
            .monthlyTotals()
            .entries
            .where((e) => e.key != currency)
            .toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'توزيع مصروفك الشهري حسب التصنيف',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: AppColors.ink,
                    ),
                  ),
                  Text(
                    'بعملة ${currencySymbols[currency] ?? currency}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final e in sortedCats) ...[
                    _CategoryBar(
                      label:
                          '${kCategoryEmoji[e.key] ?? '🔖'} ${e.key}',
                      value: e.value,
                      maxValue: maxVal,
                      currency: currency,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (otherCurrencies.isNotEmpty) ...[
                    const Divider(height: 20),
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
            const SizedBox(height: 14),
            AppCard(
              color: AppColors.sandSoft,
              child: Row(
                children: [
                  const Text('📅', style: TextStyle(fontSize: 30)),
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
                            color: Color(0xFF7A5A10),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'أغلى اشتراكاتك (شهريًا)',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 10),
            for (final s in top.take(5)) ...[
              _TopTile(sub: s),
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

class _CategoryBar extends StatelessWidget {
  final String label;
  final double value;
  final double maxValue;
  final String currency;

  const _CategoryBar({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final factor = maxValue <= 0 ? 0.0 : (value / maxValue).clamp(0.05, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
                color: AppColors.ink,
              ),
            ),
            Text(
              fmtMoney(value, currency),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: AppColors.primaryDeep,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 10,
            color: const Color(0xFFEDE7DA),
            alignment: AlignmentDirectional.centerStart,
            child: FractionallySizedBox(
              widthFactor: factor,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDeep],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TopTile extends StatelessWidget {
  final Subscription sub;

  const _TopTile({required this.sub});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Text(sub.emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
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
              color: AppColors.primaryDeep,
            ),
          ),
        ],
      ),
    );
  }
}
