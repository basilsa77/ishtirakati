/// تقويم الدفعات في v11.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/subscription.dart';
import '../services/subscription_store.dart';
import '../theme.dart';
import 'subscriptions_screen.dart';

/// صفحة مستقلة للتقويم تُستخدم عند فتحه من خارج الشريط السفلي.
class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return CupertinoPageScaffold(
      backgroundColor: p.canvas,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: p.canvas.withValues(alpha: .92),
        border: Border(bottom: BorderSide(color: p.stroke)),
        middle: Text(
          'جدول التجديدات',
          style: TextStyle(color: p.text, fontSize: 17, fontWeight: FontWeight.w900),
        ),
      ),
      child: const SafeArea(top: false, child: CalendarScreen()),
    );
  }
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const _months = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];
  static const _weekdays = ['ح', 'ن', 'ث', 'ر', 'خ', 'ج', 'س'];

  late DateTime _month;
  bool _calendarView = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final store = SubscriptionStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final byDay = <int, List<Subscription>>{};
        for (final subscription in store.active) {
          for (final date in subscription.renewalsInMonth(_month.year, _month.month)) {
            byDay.putIfAbsent(date.day, () => []).add(subscription);
          }
        }
        final currency = store.dominantCurrency;
        final total = byDay.values
            .expand((items) => items)
            .where((item) => item.currency == currency)
            .fold<double>(0, (sum, item) => sum + item.price);

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            _CalendarHeader(total: total, currency: currency, itemCount: byDay.values.expand((items) => items).length),
            const SizedBox(height: 18),
            Semantics(
              label: 'اختيار طريقة عرض التجديدات',
              child: CupertinoSlidingSegmentedControl<bool>(
                groupValue: _calendarView,
                children: const {
                  false: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('القائمة الزمنية'),
                  ),
                  true: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('التقويم'),
                  ),
                },
                onValueChanged: (value) {
                  if (value != null) setState(() => _calendarView = value);
                },
              ),
            ),
            const SizedBox(height: 18),
            _MonthControl(
              label: '${_months[_month.month - 1]} ${_month.year}',
              onPrevious: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
              onNext: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
              onToday: () {
                final today = DateTime.now();
                setState(() => _month = DateTime(today.year, today.month));
              },
            ),
            if (_calendarView) ...[
              const SizedBox(height: 12),
              _CalendarGrid(
                month: _month,
                weekdays: _weekdays,
                entries: byDay,
                onOpen: (day, subscriptions) =>
                    _openDay(context, day, subscriptions),
              ),
              const SizedBox(height: 24),
            ] else
              const SizedBox(height: 24),
            Text('التجديدات حسب التاريخ', style: TextStyle(color: context.palette.text, fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text(byDay.isEmpty ? 'لا توجد دفعات مسجلة لهذا الشهر.' : 'اختر أي خدمة لعرض تفاصيلها.', style: TextStyle(color: context.palette.textMuted, fontSize: 12.5)),
            const SizedBox(height: 12),
            if (byDay.isEmpty)
              const _CalendarEmpty()
            else
              for (final day in (byDay.keys.toList()..sort()))
                for (final subscription in byDay[day]!) ...[
                  _CalendarPayment(day: day, subscription: subscription),
                  const SizedBox(height: 9),
                ],
          ],
        );
      },
    );
  }

  void _openDay(BuildContext context, int day, List<Subscription> subscriptions) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) {
        final p = sheetContext.palette;
        return DraggableScrollableSheet(
            expand: false,
            initialChildSize: .52,
            minChildSize: .32,
            maxChildSize: .9,
            builder: (context, controller) => SafeArea(
            top: false,
            child: Container(
              decoration: BoxDecoration(color: p.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
              child: ListView.separated(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                itemCount: subscriptions.length + 1,
                separatorBuilder: (_, index) => index == 0 ? const SizedBox(height: 14) : Divider(color: p.stroke, height: 1),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(child: Container(width: 38, height: 4, decoration: BoxDecoration(color: p.stroke, borderRadius: BorderRadius.circular(99)))),
                        const SizedBox(height: 18),
                        Text('دفعات يوم $day', style: TextStyle(color: p.text, fontSize: 18, fontWeight: FontWeight.w900)),
                      ],
                    );
                  }
                  final subscription = subscriptions[index - 1];
                  return CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      showSubscriptionDetails(context, subscription);
                    },
                    child: Row(
                      children: [
                        ServiceAvatar(name: subscription.name, emoji: subscription.emoji, manageUrl: subscription.manageUrl, iconUrl: subscription.iconUrl, tint: categoryColor(subscription.category), size: 42),
                        const SizedBox(width: 10),
                        Expanded(child: Text(subscription.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.text, fontWeight: FontWeight.w800))),
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 96),
                          child: Text(fmtMoneyWithCurrency(subscription.price, subscription.currency), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.accent, fontWeight: FontWeight.w900)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            ),
        );
      },
    );
  }
}

class _CalendarHeader extends StatelessWidget {
  final double total;
  final String currency;
  final int itemCount;

  const _CalendarHeader({required this.total, required this.currency, required this.itemCount});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('جدول التجديدات', style: TextStyle(color: p.text, fontSize: 27, fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        Text('موعد كل خصم أمامك، بلا مفاجآت.', style: TextStyle(color: p.textMuted, fontSize: 13)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(21)),
          child: Row(
            children: [
              Icon(Icons.event_available_rounded, color: p.accent),
              const SizedBox(width: 10),
              Expanded(child: Text('$itemCount دفعات في هذا الشهر', style: TextStyle(color: p.text, fontWeight: FontWeight.w800, fontSize: 13))),
              Text(fmtMoney(total, currency), style: TextStyle(color: p.accent, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ],
    );
  }
}

class _MonthControl extends StatelessWidget {
  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  const _MonthControl({required this.label, required this.onPrevious, required this.onNext, required this.onToday});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        CupertinoButton(
          padding: const EdgeInsets.all(8),
          onPressed: onNext,
          child: Icon(CupertinoIcons.chevron_right, color: p.text),
        ),
        Expanded(child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: p.text, fontSize: 18, fontWeight: FontWeight.w900))),
        CupertinoButton(
          padding: const EdgeInsets.all(8),
          onPressed: onPrevious,
          child: Icon(CupertinoIcons.chevron_left, color: p.text),
        ),
        CupertinoButton(onPressed: onToday, child: const Text('اليوم')),
      ],
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  final DateTime month;
  final List<String> weekdays;
  final Map<int, List<Subscription>> entries;
  final void Function(int day, List<Subscription> subscriptions) onOpen;

  const _CalendarGrid({required this.month, required this.weekdays, required this.entries, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final first = DateTime(month.year, month.month, 1).weekday % 7;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final today = DateTime.now();
    return AppCard(
      padding: const EdgeInsets.all(13),
      child: Column(
        children: [
          Row(
            children: [
              for (final weekday in weekdays)
                Expanded(child: Center(child: Text(weekday, style: TextStyle(color: p.textMuted, fontSize: 11, fontWeight: FontWeight.w800)))),
            ],
          ),
          const SizedBox(height: 9),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 6, crossAxisSpacing: 6, childAspectRatio: .87),
            itemCount: first + days,
            itemBuilder: (context, index) {
              if (index < first) return const SizedBox();
              final day = index - first + 1;
              final subscriptions = entries[day] ?? const <Subscription>[];
              final todaySelected = today.year == month.year && today.month == month.month && today.day == day;
              return GestureDetector(
                onTap: subscriptions.isEmpty ? null : () => onOpen(day, subscriptions),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  decoration: BoxDecoration(
                    color: todaySelected ? p.accent : subscriptions.isNotEmpty ? p.accentSoft : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$day', style: TextStyle(color: todaySelected ? Colors.white : subscriptions.isNotEmpty ? p.accent : p.text, fontSize: 12, fontWeight: FontWeight.w900)),
                      if (subscriptions.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Container(width: 5, height: 5, decoration: BoxDecoration(color: todaySelected ? Colors.white : categoryColor(subscriptions.first.category), shape: BoxShape.circle)),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CalendarPayment extends StatelessWidget {
  final int day;
  final Subscription subscription;

  const _CalendarPayment({required this.day, required this.subscription});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return CupertinoButton(
      onPressed: () => showSubscriptionDetails(context, subscription),
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: p.stroke)),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: p.accentSoft, borderRadius: BorderRadius.circular(13)),
              child: Text('$day', style: TextStyle(color: p.accent, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 10),
            ServiceAvatar(name: subscription.name, emoji: subscription.emoji, manageUrl: subscription.manageUrl, iconUrl: subscription.iconUrl, tint: categoryColor(subscription.category), size: 40),
            const SizedBox(width: 10),
            Expanded(child: Text(subscription.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.text, fontWeight: FontWeight.w800, fontSize: 13.5))),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 92),
              child: Text(
                fmtMoneyWithCurrency(subscription.price, subscription.currency),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: p.accent, fontWeight: FontWeight.w900, fontSize: 12.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarEmpty extends StatelessWidget {
  const _CalendarEmpty();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          Icon(CupertinoIcons.calendar_badge_minus, color: p.textMuted),
          const SizedBox(width: 10),
          Expanded(child: Text('لا توجد تجديدات مسجلة في هذا الشهر.', style: TextStyle(color: p.textMuted, fontSize: 12.5))),
        ],
      ),
    );
  }
}
