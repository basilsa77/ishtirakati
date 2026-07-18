/// مكتبة الاشتراكات بهوية v16.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../data/presets.dart';
import '../models/subscription.dart';
import '../services/financial_assistant.dart';
import '../services/subscription_store.dart';
import '../services/safe_url.dart';
import '../theme.dart';
import '../widgets/ios_controls.dart';
import '../widgets/potential_duplicate_badge.dart';
import 'edit_subscription_screen.dart';
import 'financial_review_screen.dart';
import 'import_screen.dart';
import 'quick_add_sheet.dart';

enum _SortOrder { renewal, cost, name }

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  final _search = TextEditingController();
  PaymentKind? _kind;
  String? _category;
  _SortOrder _sort = _SortOrder.renewal;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = SubscriptionStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final subscriptions = _filtered(store);
        final duplicateGroupsBySubscriptionId =
            FinancialAssistant.indexDuplicateGroupsBySubscriptionId(
              FinancialAssistant.findDuplicateGroups(store.items),
            );
        return CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  V16Space.lg,
                  V16Space.md,
                  V16Space.lg,
                  0,
                ),
                child: _LibraryHeader(
                  total: store.active.length,
                  onAdd: () => showQuickAddSheet(context),
                  onImport:
                      () => Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (_) => const ImportScreen(),
                        ),
                      ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  V16Space.lg,
                  V16Space.md,
                  V16Space.lg,
                  0,
                ),
                child: _SearchLine(
                  controller: _search,
                  sort: _sort,
                  onChanged: () => setState(() {}),
                  onSort: (sort) => setState(() => _sort = sort),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: V16Space.md),
                child: _FilterRail(
                  selectedKind: _kind,
                  selectedCategory: _category,
                  usedCategories: {
                    for (final item in store.items) item.category,
                  },
                  onKind:
                      (value) => setState(() {
                        _kind = value;
                        _category = null;
                      }),
                  onCategory:
                      (value) => setState(() {
                        _category = value;
                        _kind = null;
                      }),
                  onAll:
                      () => setState(() {
                        _kind = null;
                        _category = null;
                      }),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: V16Space.sm)),
            if (subscriptions.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _LibraryEmpty(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  V16Space.lg,
                  0,
                  V16Space.lg,
                  V16Space.xxl,
                ),
                sliver: SliverList.separated(
                  itemCount: subscriptions.length,
                  separatorBuilder:
                      (_, __) => const SizedBox(height: V16Space.sm),
                  itemBuilder:
                      (context, index) => _SubscriptionRow(
                        subscription: subscriptions[index],
                        duplicateGroup:
                            duplicateGroupsBySubscriptionId[subscriptions[index]
                                .id],
                      ),
                ),
              ),
          ],
        );
      },
    );
  }

  List<Subscription> _filtered(SubscriptionStore store) {
    final query = _search.text.trim().toLowerCase();
    final output =
        store.items.where((item) {
          final matchesName =
              query.isEmpty || item.name.toLowerCase().contains(query);
          final matchesKind = _kind == null || item.kind == _kind;
          final matchesCategory =
              _category == null || item.category == _category;
          return matchesName && matchesKind && matchesCategory;
        }).toList();
    switch (_sort) {
      case _SortOrder.renewal:
        output.sort(
          (a, b) => a.daysUntilRenewal().compareTo(b.daysUntilRenewal()),
        );
      case _SortOrder.cost:
        output.sort((a, b) => b.monthlyCost.compareTo(a.monthlyCost));
      case _SortOrder.name:
        output.sort((a, b) => a.name.compareTo(b.name));
    }
    return output;
  }
}

class _LibraryHeader extends StatelessWidget {
  final int total;
  final VoidCallback onAdd;
  final VoidCallback onImport;

  const _LibraryHeader({
    required this.total,
    required this.onAdd,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    return AppPageIntro(
      title: tr('ui_17cbe710ffe6'),
      description: tr('ui_82171abee2e6', {'value0': total}),
      trailing: Wrap(
        spacing: V16Space.xs,
        children: [
          CupertinoButton(
            padding: const EdgeInsets.all(V16Space.sm),
            color: context.palette.surface,
            borderRadius: BorderRadius.circular(V16Radius.standard),
            onPressed: onImport,
            child: const Icon(CupertinoIcons.doc_text_viewfinder, size: 23),
          ),
          CupertinoButton(
            padding: const EdgeInsets.all(V16Space.sm),
            color: context.palette.accentStrong,
            borderRadius: BorderRadius.circular(V16Radius.standard),
            onPressed: onAdd,
            child: const Icon(
              CupertinoIcons.add,
              color: V16Colors.white,
              size: 27,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchLine extends StatelessWidget {
  final TextEditingController controller;
  final _SortOrder sort;
  final VoidCallback onChanged;
  final ValueChanged<_SortOrder> onSort;

  const _SearchLine({
    required this.controller,
    required this.sort,
    required this.onChanged,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        Expanded(
          child: CupertinoSearchTextField(
            controller: controller,
            placeholder: tr('ui_de80c5ac5eac'),
            onChanged: (_) => onChanged(),
            style: TextStyle(color: p.text, fontSize: V16Type.bodySmall),
            backgroundColor: p.surface,
          ),
        ),
        const SizedBox(width: V16Space.xs),
        CupertinoButton(
          padding: const EdgeInsets.symmetric(
            horizontal: V16Space.sm,
            vertical: V16Space.xs,
          ),
          color: p.surface,
          borderRadius: BorderRadius.circular(V16Radius.compact),
          onPressed: () async {
            final selected = await showIosPicker<_SortOrder>(
              context: context,
              title: tr('ui_b5841e813df3'),
              selected: sort,
              values: _SortOrder.values,
              label: _sortLabel,
            );
            if (selected != null) onSort(selected);
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.arrow_up_arrow_down,
                color: p.accent,
                size: 18,
              ),
              const SizedBox(width: V16Space.xxs),
              Text(
                _sortLabel(sort),
                style: TextStyle(color: p.text, fontSize: V16Type.caption),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _sortLabel(_SortOrder value) => switch (value) {
    _SortOrder.renewal => tr('ui_0c3117b358fd'),
    _SortOrder.cost => tr('ui_c0924d94939b'),
    _SortOrder.name => tr('ui_52ab09847cf8'),
  };
}

class _FilterRail extends StatelessWidget {
  final PaymentKind? selectedKind;
  final String? selectedCategory;
  final Set<String> usedCategories;
  final ValueChanged<PaymentKind?> onKind;
  final ValueChanged<String?> onCategory;
  final VoidCallback onAll;

  const _FilterRail({
    required this.selectedKind,
    required this.selectedCategory,
    required this.usedCategories,
    required this.onKind,
    required this.onCategory,
    required this.onAll,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: V16Space.lg),
          child: Text(
            tr('ui_448543036e9c'),
            style: TextStyle(
              color: context.palette.textMuted,
              fontSize: V16Type.caption,
              fontWeight: V16Type.semibold,
            ),
          ),
        ),
        const SizedBox(height: V16Space.xs),
        SizedBox(
          height: 37,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: V16Space.lg),
            children: [
              _FilterChip(
                label: tr('ui_65f276da33cf'),
                selected: selectedKind == null && selectedCategory == null,
                onTap: onAll,
              ),
              for (final kind in PaymentKind.values) ...[
                const SizedBox(width: V16Space.xs),
                _FilterChip(
                  label: localizedPaymentKind(kind.name),
                  selected: selectedKind == kind,
                  onTap: () => onKind(selectedKind == kind ? null : kind),
                ),
              ],
            ],
          ),
        ),
        if (usedCategories.isNotEmpty) ...[
          const SizedBox(height: V16Space.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: V16Space.lg),
            child: Text(
              tr('ui_3a7c87ed0100'),
              style: TextStyle(
                color: context.palette.textMuted,
                fontSize: V16Type.caption,
                fontWeight: V16Type.semibold,
              ),
            ),
          ),
          const SizedBox(height: V16Space.xs),
          SizedBox(
            height: 37,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: V16Space.lg),
              children: [
                for (final category in kCategories)
                  if (usedCategories.contains(category)) ...[
                    _FilterChip(
                      label: category,
                      selected: selectedCategory == category,
                      onTap:
                          () => onCategory(
                            selectedCategory == category ? null : category,
                          ),
                    ),
                    const SizedBox(width: V16Space.xs),
                  ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return CupertinoButton(
      padding: const EdgeInsetsDirectional.only(end: V16Space.xs),
      minimumSize: Size.zero,
      onPressed: onTap,
      child: AnimatedContainer(
        duration: reduceMotion(context) ? Duration.zero : V16Motion.quick,
        curve: V16Motion.standardCurve,
        padding: const EdgeInsets.symmetric(horizontal: V16Space.md),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? p.accentStrong : p.surface,
          borderRadius: BorderRadius.circular(V16Radius.pill),
          border: Border.all(color: selected ? p.accentStrong : p.stroke),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? CupertinoColors.white : p.text,
            fontSize: V16Type.caption,
            fontWeight: V16Type.semibold,
          ),
        ),
      ),
    );
  }
}

class _SubscriptionRow extends StatelessWidget {
  final Subscription subscription;
  final DuplicateSubscriptionGroup? duplicateGroup;

  const _SubscriptionRow({required this.subscription, this.duplicateGroup});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final store = SubscriptionStore.instance;
    return Dismissible(
      key: ValueKey(subscription.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.only(end: V16Space.lg),
        decoration: BoxDecoration(
          color: p.danger,
          borderRadius: BorderRadius.circular(V16Radius.standard),
        ),
        child: const Icon(CupertinoIcons.delete, color: CupertinoColors.white),
      ),
      confirmDismiss: (_) => _confirmDelete(context, subscription.name),
      onDismissed: (_) => store.remove(subscription.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCard(
            onTap: () => showSubscriptionDetails(context, subscription),
            padding: const EdgeInsets.all(V16Space.md),
            child: Row(
              children: [
                ServiceAvatar(
                  name: subscription.name,
                  emoji: subscription.emoji,
                  manageUrl: subscription.manageUrl,
                  iconUrl: subscription.iconUrl,
                  tint: categoryColor(subscription.category),
                  size: 50,
                ),
                const SizedBox(width: V16Space.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              subscription.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: p.text,
                                fontWeight: V16Type.semibold,
                                fontSize: V16Type.bodySmall,
                              ),
                            ),
                          ),
                          if (subscription.isPaused)
                            _StatePill(
                              text: tr('ui_e858894dedb7'),
                              color: p.warning,
                              background: p.warningSoft,
                            ),
                          if (subscription.isTrialActive())
                            _StatePill(
                              text: tr('ui_87a9108dad6d'),
                              color: p.danger,
                              background: p.dangerSoft,
                            ),
                        ],
                      ),
                      const SizedBox(height: V16Space.xxs),
                      Text(
                        '${localizedCategory(subscription.category)} · '
                        '${localizedBillingCycle(subscription.cycle.name)}',
                        style: TextStyle(
                          color: p.textMuted,
                          fontSize: V16Type.caption,
                        ),
                      ),
                      const SizedBox(height: V16Space.xs),
                      if (!subscription.isPaused)
                        RenewalBadge(days: subscription.daysUntilRenewal())
                      else
                        Text(
                          tr('ui_0494e50b7138'),
                          style: TextStyle(
                            color: p.textMuted,
                            fontSize: V16Type.caption,
                            fontWeight: V16Type.semibold,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: V16Space.xs),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 92),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        fmtMoneyWithCurrency(
                          subscription.price,
                          subscription.currency,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: p.accent,
                          fontWeight: V16Type.semibold,
                          fontSize: V16Type.label,
                        ),
                      ),
                    ],
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
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, String name) async {
    return showIosConfirmation(
      context: context,
      title: tr('ui_8a2f22ef602c'),
      message: tr('ui_408dcf474886', {'value0': name}),
      confirmLabel: tr('ui_59ca629220a6'),
      destructive: true,
    );
  }
}

class _StatePill extends StatelessWidget {
  final String text;
  final Color color;
  final Color background;

  const _StatePill({
    required this.text,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsetsDirectional.only(start: V16Space.xs),
    padding: const EdgeInsets.symmetric(
      horizontal: V16Space.xs,
      vertical: V16Space.xxs,
    ),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(V16Radius.pill),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: V16Type.captionSmall,
        fontWeight: V16Type.semibold,
      ),
    ),
  );
}

class _LibraryEmpty extends StatelessWidget {
  const _LibraryEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(V16Space.lg),
        child: AppEmptyState(
          icon: CupertinoIcons.search,
          title: tr('ui_c19b06bfe3c2'),
          description: tr('ui_de80c5ac5eac'),
        ),
      ),
    );
  }
}

String _renewalText(int days) {
  if (days <= 0) return tr('ui_2422f71e7f4e');
  if (days == 1) return tr('commonTomorrow');
  return tr('ui_68300aba1efe', {'value0': days});
}

Future<void> showSubscriptionDetails(
  BuildContext context,
  Subscription sub,
) async {
  final store = SubscriptionStore.instance;
  await showCupertinoModalPopup<void>(
    context: context,
    builder: (sheetContext) {
      final p = sheetContext.palette;
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: .72,
        minChildSize: .42,
        maxChildSize: .94,
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
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(
                    V16Space.lg,
                    V16Space.sm,
                    V16Space.lg,
                    V16Space.xl,
                  ),
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: p.stroke,
                          borderRadius: BorderRadius.circular(V16Radius.pill),
                        ),
                      ),
                    ),
                    const SizedBox(height: V16Space.ml),
                    Row(
                      children: [
                        ServiceAvatar(
                          name: sub.name,
                          emoji: sub.emoji,
                          manageUrl: sub.manageUrl,
                          iconUrl: sub.iconUrl,
                          tint: categoryColor(sub.category),
                          size: 54,
                        ),
                        const SizedBox(width: V16Space.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sub.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: p.text,
                                  fontSize: V16Type.titleSmall,
                                  fontWeight: V16Type.semibold,
                                ),
                              ),
                              const SizedBox(height: V16Space.xxs),
                              Text(
                                '${localizedCategory(sub.category)} · ${localizedBillingCycle(sub.cycle.name)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: p.textMuted,
                                  fontSize: V16Type.caption,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: V16Space.lg),
                    AnimatedMoney(
                      value: sub.price,
                      currency:
                          isEnglishLocale && sub.currency == 'SAR'
                              ? 'SAR'
                              : currencySymbols[sub.currency] ?? sub.currency,
                      style: TextStyle(
                        color: p.accent,
                        fontWeight: V16Type.semibold,
                        fontSize: V16Type.title,
                      ),
                    ),
                    const SizedBox(height: V16Space.md),
                    _DetailMetric(
                      icon: Icons.event_repeat_rounded,
                      label: tr('ui_b4f5658d61f3'),
                      value: _renewalText(sub.daysUntilRenewal()),
                    ),
                    const SizedBox(height: V16Space.sm),
                    _DetailMetric(
                      icon: Icons.payments_outlined,
                      label: tr('ui_118b84c4c576'),
                      value: fmtMoneyWithCurrency(
                        sub.monthlyCost,
                        sub.currency,
                      ),
                    ),
                    if (sub.notes.trim().isNotEmpty) ...[
                      const SizedBox(height: V16Space.sm),
                      _DetailMetric(
                        icon: Icons.notes_rounded,
                        label: tr('ui_0be7afd7e65f'),
                        value: sub.notes,
                      ),
                    ],
                    const SizedBox(height: V16Space.lg),
                    LayoutBuilder(
                      builder:
                          (context, constraints) =>
                              constraints.maxWidth < 340
                                  ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _actionButtons(
                                        context,
                                        sheetContext,
                                        store,
                                        sub,
                                      ).first,
                                      const SizedBox(height: V16Space.sm),
                                      _actionButtons(
                                        context,
                                        sheetContext,
                                        store,
                                        sub,
                                      ).last,
                                    ],
                                  )
                                  : Row(
                                    children: [
                                      Expanded(
                                        child:
                                            _actionButtons(
                                              context,
                                              sheetContext,
                                              store,
                                              sub,
                                            ).first,
                                      ),
                                      const SizedBox(width: V16Space.sm),
                                      Expanded(
                                        child:
                                            _actionButtons(
                                              context,
                                              sheetContext,
                                              store,
                                              sub,
                                            ).last,
                                      ),
                                    ],
                                  ),
                    ),
                    if (sub.manageUrl.trim().isNotEmpty) ...[
                      const SizedBox(height: V16Space.sm),
                      CupertinoButton(
                        color: p.surfaceAlt,
                        onPressed: () async {
                          final uri = normalizedHttpsUri(sub.manageUrl);
                          if (uri == null) {
                            if (sheetContext.mounted) {
                              await showCupertinoDialog<void>(
                                context: sheetContext,
                                builder:
                                    (dialogContext) => CupertinoAlertDialog(
                                      title: Text(tr('ui_36f5ac81955e')),
                                      content: Text(tr('ui_370a5905d9f7')),
                                      actions: [
                                        CupertinoDialogAction(
                                          onPressed:
                                              () =>
                                                  Navigator.pop(dialogContext),
                                          child: Text(tr('ui_a64b3d93816b')),
                                        ),
                                      ],
                                    ),
                              );
                            }
                            return;
                          }
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        },
                        child: Text(tr('ui_62501bf71e29')),
                      ),
                    ],
                    const SizedBox(height: V16Space.xxs),
                    CupertinoButton(
                      onPressed: () async {
                        await store.recordUsage(sub.id);
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                      },
                      child: Text(tr('ui_0c361266d921')),
                    ),
                  ],
                ),
              ),
            ),
      );
    },
  );
}

List<Widget> _actionButtons(
  BuildContext context,
  BuildContext sheetContext,
  SubscriptionStore store,
  Subscription sub,
) => [
  CupertinoButton(
    color: context.palette.surfaceAlt,
    onPressed: () {
      Navigator.pop(sheetContext);
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) => EditSubscriptionScreen(existing: sub),
        ),
      );
    },
    child: Text(tr('ui_113d570d6555')),
  ),
  CupertinoButton.filled(
    onPressed: () async {
      await store.togglePause(sub.id);
      if (sheetContext.mounted) Navigator.pop(sheetContext);
    },
    child: Text(sub.isPaused ? tr('ui_60d84c243b4d') : tr('ui_cb7f6fd46259')),
  ),
];

class _DetailMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(V16Space.md),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(V16Radius.standard),
        border: Border.all(color: p.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: p.accent, size: 19),
              const SizedBox(width: V16Space.xs),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: p.textMuted,
                    fontSize: V16Type.caption,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: V16Space.xs),
          Text(
            value,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: p.text,
              fontSize: V16Type.labelSmall,
              fontWeight: V16Type.semibold,
            ),
          ),
        ],
      ),
    );
  }
}
