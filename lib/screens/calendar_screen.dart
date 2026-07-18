/// تقويم الدفعات بهوية v16.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/subscription.dart';
import '../services/financial_assistant.dart';
import '../services/subscription_store.dart';
import '../theme.dart';
import '../widgets/potential_duplicate_badge.dart';
import '../widgets/service_name_text.dart';
import 'financial_review_screen.dart';
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
          style: TextStyle(
            color: p.text,
            fontSize: V16Type.titleSmall,
            fontWeight: V16Type.semibold,
          ),
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
  List<String> get _weekdays => [
    tr('ui_56750292f58c'),
    tr('ui_cb92a8b00c69'),
    tr('ui_e57c96ba8aea'),
    tr('ui_36a9d753b0bd'),
    tr('ui_84d816dcc533'),
    tr('ui_51c9a584ad13'),
    tr('ui_861183a44bf3'),
  ];

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
        // Keep completed finite installments visible in historical months.
        // renewalsInMonth() itself prevents occurrences after the final payment.
        for (final subscription in store.items.where(
          (item) => !item.isPaused,
        )) {
          for (final date in subscription.renewalsInMonth(
            _month.year,
            _month.month,
          )) {
            byDay.putIfAbsent(date.day, () => []).add(subscription);
          }
        }
        final totals = <String, double>{};
        for (final entry in byDay.entries) {
          final date = DateTime(_month.year, _month.month, entry.key);
          for (final item in entry.value) {
            totals.update(
              item.currency,
              (value) => value + item.priceAt(date),
              ifAbsent: () => item.priceAt(date),
            );
          }
        }
        final dominantCurrency = store.dominantCurrency;
        if (totals.isEmpty) totals[dominantCurrency] = 0;
        final orderedEntries =
            totals.entries.toList()..sort((first, second) {
              if (first.key == dominantCurrency) return -1;
              if (second.key == dominantCurrency) return 1;
              return first.key.compareTo(second.key);
            });
        final orderedTotals = Map<String, double>.fromEntries(orderedEntries);
        final duplicateGroupsBySubscriptionId =
            FinancialAssistant.indexDuplicateGroupsBySubscriptionId(
              FinancialAssistant.findDuplicateGroups(store.items),
            );

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            V16Space.lg,
            V16Space.md,
            V16Space.lg,
            V16Space.xl,
          ),
          children: [
            _CalendarHeader(
              totals: orderedTotals,
              itemCount: byDay.values.expand((items) => items).length,
            ),
            const SizedBox(height: V16Space.lg),
            Semantics(
              label: tr('ui_30e4cbf695ec'),
              child: CupertinoSlidingSegmentedControl<bool>(
                groupValue: _calendarView,
                backgroundColor: context.palette.surfaceAlt,
                thumbColor: context.palette.accentStrong,
                children: {
                  false: _CalendarViewOption(
                    key: const Key('renewals-timeline-option'),
                    label: tr('ui_ff0c5210ac46'),
                    icon: CupertinoIcons.list_bullet,
                    selected: !_calendarView,
                  ),
                  true: _CalendarViewOption(
                    key: const Key('renewals-calendar-option'),
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
            const SizedBox(height: V16Space.lg),
            _MonthControl(
              label: formatMonthYear(_month),
              onPrevious:
                  () => setState(
                    () => _month = DateTime(_month.year, _month.month - 1),
                  ),
              onNext:
                  () => setState(
                    () => _month = DateTime(_month.year, _month.month + 1),
                  ),
              onToday: () {
                final today = DateTime.now();
                setState(() => _month = DateTime(today.year, today.month));
              },
            ),
            if (_calendarView) ...[
              const SizedBox(height: V16Space.sm),
              _CalendarGrid(
                key: const Key('renewals-calendar-grid'),
                month: _month,
                weekdays: _weekdays,
                entries: byDay,
                onOpen:
                    (day, subscriptions) =>
                        _openDay(context, day, subscriptions),
              ),
              const SizedBox(height: V16Space.lg),
            ] else
              const SizedBox(height: V16Space.lg),
            SectionTitle(tr('ui_fd07cb92b0fe')),
            Text(
              byDay.isEmpty ? tr('ui_cfe0939cd3d2') : tr('ui_221f5f83bb44'),
              style: TextStyle(
                color: context.palette.textMuted,
                fontSize: V16Type.labelSmall,
              ),
            ),
            const SizedBox(height: V16Space.sm),
            if (byDay.isEmpty)
              const _CalendarEmpty()
            else
              for (final day in (byDay.keys.toList()..sort()))
                for (final subscription in byDay[day]!) ...[
                  _CalendarPayment(
                    date: DateTime(_month.year, _month.month, day),
                    subscription: subscription,
                    duplicateGroup:
                        duplicateGroupsBySubscriptionId[subscription.id],
                  ),
                  const SizedBox(height: V16Space.sm),
                ],
          ],
        );
      },
    );
  }

  void _openDay(
    BuildContext context,
    int day,
    List<Subscription> subscriptions,
  ) {
    final renewalDate = DateTime(_month.year, _month.month, day);
    final duplicateGroupsBySubscriptionId =
        FinancialAssistant.indexDuplicateGroupsBySubscriptionId(
          FinancialAssistant.findDuplicateGroups(
            SubscriptionStore.instance.items,
          ),
        );
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) {
        final p = sheetContext.palette;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: .52,
          minChildSize: .32,
          maxChildSize: .9,
          builder:
              (context, controller) => SafeArea(
                top: false,
                child: Container(
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(V16Radius.signature),
                    ),
                  ),
                  child: ListView.separated(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(
                      V16Space.lg,
                      V16Space.md,
                      V16Space.lg,
                      V16Space.lg,
                    ),
                    itemCount: subscriptions.length + 1,
                    separatorBuilder:
                        (_, index) =>
                            index == 0
                                ? const SizedBox(height: V16Space.md)
                                : Divider(color: p.stroke, height: 1),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Container(
                                width: 38,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: p.stroke,
                                  borderRadius: BorderRadius.circular(
                                    V16Radius.pill,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: V16Space.lg),
                            Text(
                              tr('v17PaymentsForDate', {
                                'date': formatShortDate(renewalDate),
                              }),
                              style: TextStyle(
                                color: p.text,
                                fontSize: V16Type.titleSmall,
                                fontWeight: V16Type.semibold,
                              ),
                            ),
                          ],
                        );
                      }
                      final subscription = subscriptions[index - 1];
                      final duplicateGroup =
                          duplicateGroupsBySubscriptionId[subscription.id];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(
                              vertical: V16Space.xs,
                            ),
                            onPressed: () {
                              Navigator.pop(sheetContext);
                              showSubscriptionDetails(context, subscription);
                            },
                            child: Row(
                              children: [
                                ServiceAvatar(
                                  name: subscription.name,
                                  emoji: subscription.emoji,
                                  manageUrl: subscription.manageUrl,
                                  iconUrl: subscription.iconUrl,
                                  tint: categoryColor(subscription.category),
                                  size: 42,
                                ),
                                const SizedBox(width: V16Space.sm),
                                Expanded(
                                  child: ServiceNameText(
                                    name: subscription.name,
                                    style: TextStyle(
                                      color: p.text,
                                      fontWeight: V16Type.semibold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: V16Space.xs),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 96,
                                  ),
                                  child: Text(
                                    fmtMoneyWithCurrency(
                                      subscription.priceAt(renewalDate),
                                      subscription.currency,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: p.accent,
                                      fontWeight: V16Type.semibold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (duplicateGroup != null)
                            PotentialDuplicateBadge(
                              key: ValueKey(
                                'duplicate-badge-sheet-${subscription.id}',
                              ),
                              onTap: () {
                                Navigator.pop(sheetContext);
                                openPotentialDuplicateReview(
                                  context,
                                  duplicateGroup,
                                );
                              },
                            ),
                        ],
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
    padding: const EdgeInsets.symmetric(vertical: V16Space.xs),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: selected ? CupertinoColors.white : context.palette.textMuted,
          ),
          const SizedBox(width: V16Space.xs),
          Text(
            label,
            style: TextStyle(
              color: selected ? CupertinoColors.white : context.palette.text,
              fontWeight: V16Type.semibold,
            ),
          ),
        ],
      ),
    ),
  );
}

class _CalendarHeader extends StatelessWidget {
  final Map<String, double> totals;
  final int itemCount;

  const _CalendarHeader({required this.totals, required this.itemCount});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AppPageIntro(
        title: tr('ui_43268af638e5'),
        description: tr('ui_dfba2e3d71cb'),
      ),
      const SizedBox(height: V16Space.md),
      RenewalsSummaryCard(totals: totals, itemCount: itemCount),
    ],
  );
}

@visibleForTesting
class RenewalsSummaryCard extends StatelessWidget {
  final Map<String, double> totals;
  final int itemCount;

  const RenewalsSummaryCard({
    super.key,
    required this.totals,
    required this.itemCount,
  });

  @override
  Widget build(BuildContext context) {
    final countLabel = Text(
      localizedPlural('v17PaymentsThisMonthCount', itemCount),
      key: const Key('renewals-summary-count'),
      style: const TextStyle(
        color: V16Colors.white,
        fontWeight: V16Type.semibold,
        fontSize: V16Type.labelSmall,
      ),
    );
    final amounts = Wrap(
      spacing: V16Space.sm,
      runSpacing: V16Space.xxs,
      children: [
        for (final entry in totals.entries)
          AnimatedMoney(
            key: ValueKey('renewals-summary-amount-${entry.key}'),
            value: entry.value,
            currency: entry.key,
            style: const TextStyle(
              color: V16Colors.white,
              fontWeight: V16Type.semibold,
            ),
          ),
      ],
    );
    return AppCard(
      key: const Key('renewals-summary-card'),
      tone: AppCardTone.accent,
      padding: const EdgeInsets.all(V16Space.lg),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stack =
              constraints.maxWidth < 360 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.3;
          final heading = Row(
            children: [
              const Icon(Icons.event_available_rounded, color: V16Colors.white),
              const SizedBox(width: V16Space.sm),
              Expanded(child: countLabel),
            ],
          );
          if (stack) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [heading, const SizedBox(height: V16Space.sm), amounts],
            );
          }
          return Row(
            children: [
              Expanded(child: heading),
              const SizedBox(width: V16Space.sm),
              Flexible(child: amounts),
            ],
          );
        },
      ),
    );
  }
}

class _MonthControl extends StatelessWidget {
  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  const _MonthControl({
    required this.label,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        CupertinoButton(
          padding: const EdgeInsets.all(V16Space.xs),
          onPressed: onNext,
          child: Icon(CupertinoIcons.chevron_right, color: p.text),
        ),
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: p.text,
              fontSize: V16Type.titleSmall,
              fontWeight: V16Type.semibold,
            ),
          ),
        ),
        CupertinoButton(
          padding: const EdgeInsets.all(V16Space.xs),
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
      padding: const EdgeInsets.all(V16Space.md),
      child: Column(
        children: [
          Row(
            children: [
              for (final weekday in weekdays)
                Expanded(
                  child: Center(
                    child: Text(
                      weekday,
                      style: TextStyle(
                        color: p.textMuted,
                        fontSize: V16Type.caption,
                        fontWeight: V16Type.semibold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: V16Space.sm),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: .87,
            ),
            itemCount: first + days,
            itemBuilder: (context, index) {
              if (index < first) return const SizedBox();
              final day = index - first + 1;
              final subscriptions = entries[day] ?? const <Subscription>[];
              final todaySelected =
                  today.year == month.year &&
                  today.month == month.month &&
                  today.day == day;
              return GestureDetector(
                onTap:
                    subscriptions.isEmpty
                        ? null
                        : () => onOpen(day, subscriptions),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration:
                      reduceMotion(context) ? Duration.zero : V16Motion.quick,
                  curve: V16Motion.standardCurve,
                  decoration: BoxDecoration(
                    color:
                        todaySelected
                            ? p.accentStrong
                            : subscriptions.isNotEmpty
                            ? p.accentSoft
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(V16Radius.compact),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        localizedInteger(day),
                        style: TextStyle(
                          color:
                              todaySelected
                                  ? Colors.white
                                  : subscriptions.isNotEmpty
                                  ? p.accent
                                  : p.text,
                          fontSize: V16Type.caption,
                          fontWeight: V16Type.semibold,
                        ),
                      ),
                      if (subscriptions.isNotEmpty) ...[
                        const SizedBox(height: V16Space.xxs),
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color:
                                todaySelected
                                    ? Colors.white
                                    : categoryColor(
                                      subscriptions.first.category,
                                    ),
                            shape: BoxShape.circle,
                          ),
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
    );
  }
}

class _CalendarPayment extends StatelessWidget {
  final DateTime date;
  final Subscription subscription;
  final DuplicateSubscriptionGroup? duplicateGroup;

  const _CalendarPayment({
    required this.date,
    required this.subscription,
    this.duplicateGroup,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final day = date.day;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          onTap: () => showSubscriptionDetails(context, subscription),
          padding: const EdgeInsets.all(V16Space.md),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: p.accentSoft,
                  borderRadius: BorderRadius.circular(V16Radius.compact),
                ),
                child: Text(
                  localizedInteger(day),
                  style: TextStyle(
                    color: p.accent,
                    fontWeight: V16Type.semibold,
                  ),
                ),
              ),
              const SizedBox(width: V16Space.sm),
              ServiceAvatar(
                name: subscription.name,
                emoji: subscription.emoji,
                manageUrl: subscription.manageUrl,
                iconUrl: subscription.iconUrl,
                tint: categoryColor(subscription.category),
                size: 40,
              ),
              const SizedBox(width: V16Space.sm),
              Expanded(
                child: ServiceNameText(
                  name: subscription.name,
                  style: TextStyle(
                    color: p.text,
                    fontWeight: V16Type.semibold,
                    fontSize: V16Type.label,
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 92),
                child: Text(
                  fmtMoneyWithCurrency(
                    subscription.priceAt(date),
                    subscription.currency,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.accent,
                    fontWeight: V16Type.semibold,
                    fontSize: V16Type.labelSmall,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (duplicateGroup case final group?)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              top: V16Space.xs,
              start: V16Space.md,
            ),
            child: PotentialDuplicateBadge(
              key: ValueKey('duplicate-badge-${subscription.id}'),
              onTap: () => openPotentialDuplicateReview(context, group),
            ),
          ),
      ],
    );
  }
}

class _CalendarEmpty extends StatelessWidget {
  const _CalendarEmpty();

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: CupertinoIcons.calendar_badge_minus,
      title: tr('ui_cfe0939cd3d2'),
      description: tr('ui_d880c697cfa5'),
    );
  }
}
