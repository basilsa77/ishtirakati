/// تقويم الدفعات في v11.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
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
          tr('ui_43268af638e5'),
          style: TextStyle(color: p.text, fontSize: V15Type.titleSmall, fontWeight: FontWeight.w900),
        ),
      ),
      child: SafeArea(top: false, child: CalendarScreen()),
    );
  }
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  List<String> get _months => [
    tr('ui_bc40bf9bf5db'), tr('ui_4c9195d55893'), tr('ui_121f3712ae7c'), tr('ui_b5021be42c23'), tr('ui_e490a80977c5'), tr('ui_f6c57592aa1d'),
    tr('ui_7f5c6765af36'), tr('ui_47bea73f4ca8'), tr('ui_339eb2be7171'), tr('ui_128ed0f7c924'), tr('ui_0b699e61fe99'), tr('ui_c22ea1f7f156'),
  ];
  List<String> get _weekdays => [tr('ui_56750292f58c'), tr('ui_cb92a8b00c69'), tr('ui_e57c96ba8aea'), tr('ui_36a9d753b0bd'), tr('ui_84d816dcc533'), tr('ui_51c9a584ad13'), tr('ui_861183a44bf3')];

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
            SizedBox(height: 18),
            Semantics(
              label: tr('ui_30e4cbf695ec'),
              child: CupertinoSlidingSegmentedControl<bool>(
                groupValue: _calendarView,
                backgroundColor: context.palette.surfaceAlt,
                thumbColor: context.palette.accent,
                children: {
                  false: _CalendarViewOption(
                    key: Key('renewals-timeline-option'),
                    label: tr('ui_ff0c5210ac46'),
                    icon: CupertinoIcons.list_bullet,
                    selected: !_calendarView,
                  ),
                  true: _CalendarViewOption(
                    key: Key('renewals-calendar-option'),
                    label: tr('ui_c6c25b9b516f'),
                    icon: CupertinoIcons.calendar,
                    selected: _calendarView,
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
              SizedBox(height: 12),
              _CalendarGrid(
                key: Key('renewals-calendar-grid'),
                month: _month,
                weekdays: _weekdays,
                entries: byDay,
                onOpen: (day, subscriptions) =>
                    _openDay(context, day, subscriptions),
              ),
              SizedBox(height: 24),
            ] else
              SizedBox(height: 24),
            Text(tr('ui_fd07cb92b0fe'), style: TextStyle(color: context.palette.text, fontSize: V15Type.titleSmall, fontWeight: FontWeight.w900)),
            SizedBox(height: 5),
            Text(byDay.isEmpty ? tr('ui_cfe0939cd3d2') : tr('ui_221f5f83bb44'), style: TextStyle(color: context.palette.textMuted, fontSize: V15Type.labelSmall)),
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
                separatorBuilder: (_, index) => index == 0 ? SizedBox(height: 14) : Divider(color: p.stroke, height: 1),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(child: Container(width: 38, height: 4, decoration: BoxDecoration(color: p.stroke, borderRadius: BorderRadius.circular(99)))),
                        SizedBox(height: 18),
                        Text(tr('ui_122244edc329', {'value0': day}), style: TextStyle(color: p.text, fontSize: V15Type.titleSmall, fontWeight: FontWeight.w900)),
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

class _CalendarViewOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;

  const _CalendarViewOption({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected
                    ? CupertinoColors.white
                    : context.palette.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? CupertinoColors.white
                      : context.palette.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      );
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
        Text(tr('ui_43268af638e5'), style: TextStyle(color: p.text, fontSize: V15Type.headlineSmall, fontWeight: FontWeight.w900)),
        SizedBox(height: 5),
        Text(tr('ui_dfba2e3d71cb'), style: TextStyle(color: p.textMuted, fontSize: V15Type.labelSmall)),
        SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(21)),
          child: Row(
            children: [
              Icon(Icons.event_available_rounded, color: p.accent),
              SizedBox(width: 10),
              Expanded(child: Text(tr('ui_c594d3d42dde', {'value0': itemCount}), style: TextStyle(color: p.text, fontWeight: FontWeight.w800, fontSize: V15Type.labelSmall))),
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
        Expanded(child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: p.text, fontSize: V15Type.titleSmall, fontWeight: FontWeight.w900))),
        CupertinoButton(
          padding: const EdgeInsets.all(8),
          onPressed: onPrevious,
          child: Icon(CupertinoIcons.chevron_left, color: p.text),
        ),
        CupertinoButton(onPressed: onToday, child: Text(tr('ui_2422f71e7f4e'))),
      ],
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  final DateTime month;
  final List<String> weekdays;
  final Map<int, List<Subscription>> entries;
  final void Function(int day, List<Subscription> subscriptions) onOpen;

  const _CalendarGrid({
    super.key,
    required this.month,
    required this.weekdays,
    required this.entries,
    required this.onOpen,
  });

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
                Expanded(child: Center(child: Text(weekday, style: TextStyle(color: p.textMuted, fontSize: V15Type.caption, fontWeight: FontWeight.w800)))),
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
                      Text('$day', style: TextStyle(color: todaySelected ? Colors.white : subscriptions.isNotEmpty ? p.accent : p.text, fontSize: V15Type.caption, fontWeight: FontWeight.w900)),
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
            Expanded(child: Text(subscription.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.text, fontWeight: FontWeight.w800, fontSize: V15Type.label))),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 92),
              child: Text(
                fmtMoneyWithCurrency(subscription.price, subscription.currency),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: p.accent, fontWeight: FontWeight.w900, fontSize: V15Type.labelSmall),
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
          SizedBox(width: 10),
          Expanded(child: Text(tr('ui_d880c697cfa5'), style: TextStyle(color: p.textMuted, fontSize: V15Type.labelSmall))),
        ],
      ),
    );
  }
}
