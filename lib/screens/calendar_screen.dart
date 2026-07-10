/// تقويم التجديدات: شبكة شهرية تُظهر أيام الخصم ومبالغها.
library;

import 'package:flutter/material.dart';

import '../models/subscription.dart';
import '../services/subscription_store.dart';
import '../theme.dart';
import 'subscriptions_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _month;

  static const List<String> _monthNames = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];
  static const List<String> _weekDays = [
    'أحد', 'إثن', 'ثلا', 'أرب', 'خمي', 'جمع', 'سبت',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
  }

  void _shift(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = SubscriptionStore.instance;
    final today = DateTime.now();

    // اجمع تجديدات الشهر: يوم → قائمة اشتراكات.
    final byDay = <int, List<Subscription>>{};
    for (final s in store.active) {
      for (final d in s.renewalsInMonth(_month.year, _month.month)) {
        byDay.putIfAbsent(d.day, () => []).add(s);
      }
    }
    var monthTotal = 0.0;
    final currency = store.dominantCurrency;
    for (final list in byDay.values) {
      for (final s in list.where((s) => s.currency == currency)) {
        monthTotal += s.price;
      }
    }

    final daysInMonth =
        DateTime(_month.year, _month.month + 1, 0).day;
    // weekday: الإثنين=1 ... الأحد=7؛ شبكتنا تبدأ بالأحد.
    final firstWeekday = DateTime(_month.year, _month.month, 1).weekday % 7;

    return Scaffold(
      appBar: AppBar(title: const Text('تقويم التجديدات')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 132),
          children: [
            AppCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => _shift(1),
                        icon: const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.primary,
                          size: 30,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '${_monthNames[_month.month - 1]} ${_month.year}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              monthTotal <= 0
                                  ? 'لا خصومات هذا الشهر'
                                  : 'خصومات الشهر ≈ ${fmtMoney(monthTotal, currency)}',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => _shift(-1),
                        icon: const Icon(
                          Icons.chevron_left_rounded,
                          color: AppColors.primary,
                          size: 30,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final w in _weekDays)
                        Expanded(
                          child: Text(
                            w,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: firstWeekday + daysInMonth,
                    itemBuilder: (context, i) {
                      if (i < firstWeekday) return const SizedBox();
                      final day = i - firstWeekday + 1;
                      final subs = byDay[day] ?? const <Subscription>[];
                      final isToday = today.year == _month.year &&
                          today.month == _month.month &&
                          today.day == day;
                      return InkWell(
                        onTap: subs.isEmpty
                            ? null
                            : () => _showDay(context, day, subs),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          decoration: BoxDecoration(
                            color: subs.isNotEmpty
                                ? AppColors.primarySoft
                                : AppColors.cardAlt,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isToday
                                  ? AppColors.primary
                                  : subs.isNotEmpty
                                      ? AppColors.primaryDeep
                                      : AppColors.border,
                              width: isToday ? 1.6 : 1,
                            ),
                          ),
                          padding: const EdgeInsets.only(top: 4),
                          child: Column(
                            children: [
                              Text(
                                '$day',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: subs.isNotEmpty
                                      ? AppColors.primary
                                      : AppColors.muted,
                                ),
                              ),
                              if (subs.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Wrap(
                                  spacing: 2,
                                  alignment: WrapAlignment.center,
                                  children: [
                                    for (final s in subs.take(3))
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color:
                                              categoryColor(s.category),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (byDay.isNotEmpty) ...[
              const SectionTitle('خصومات هذا الشهر'),
              for (final day in (byDay.keys.toList()..sort()))
                for (final s in byDay[day]!)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: InkWell(
                        onTap: () => showSubscriptionDetails(context, s),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.primarySoft,
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Text(
                                '$day',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                s.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                ),
                              ),
                            ),
                            Text(
                              fmtMoney(s.price, s.currency),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDay(BuildContext context, int day, List<Subscription> subs) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'خصومات يوم $day ${_monthNames[_month.month - 1]}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 12),
              for (final s in subs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      ServiceAvatar(
                        name: s.name,
                        emoji: s.emoji,
                        manageUrl: s.manageUrl,
                        iconUrl: s.iconUrl,
                        tint: categoryColor(s.category),
                        size: 40,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          s.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      Text(
                        fmtMoney(s.price, s.currency),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
