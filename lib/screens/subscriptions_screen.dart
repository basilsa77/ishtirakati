/// مكتبة الاشتراكات للإصدار 8.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../data/presets.dart';
import '../models/subscription.dart';
import '../services/subscription_store.dart';
import '../services/safe_url.dart';
import '../theme.dart';
import '../widgets/ios_controls.dart';
import 'edit_subscription_screen.dart';
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
          return CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: _LibraryHeader(
                    total: store.active.length,
                    onAdd: () => showQuickAddSheet(context),
                    onImport: () => Navigator.of(context).push(
                      CupertinoPageRoute(builder: (_) => const ImportScreen()),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
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
                  padding: const EdgeInsets.only(top: 14),
                  child: _FilterRail(
                    selectedKind: _kind,
                    selectedCategory: _category,
                    usedCategories: {for (final item in store.items) item.category},
                    onKind: (value) => setState(() {
                      _kind = value;
                      _category = null;
                    }),
                    onCategory: (value) => setState(() {
                      _category = value;
                      _kind = null;
                    }),
                    onAll: () => setState(() {
                      _kind = null;
                      _category = null;
                    }),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              if (subscriptions.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _LibraryEmpty(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 44),
                  sliver: SliverList.separated(
                    itemCount: subscriptions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _SubscriptionRow(
                      subscription: subscriptions[index],
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
    final output = store.items.where((item) {
      final matchesName = query.isEmpty || item.name.toLowerCase().contains(query);
      final matchesKind = _kind == null || item.kind == _kind;
      final matchesCategory = _category == null || item.category == _category;
      return matchesName && matchesKind && matchesCategory;
    }).toList();
    switch (_sort) {
      case _SortOrder.renewal:
        output.sort((a, b) => a.daysUntilRenewal().compareTo(b.daysUntilRenewal()));
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
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('ui_17cbe710ffe6'), style: TextStyle(color: p.text, fontSize: V15Type.headline, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(tr('ui_82171abee2e6', {'value0': total}), style: TextStyle(color: p.textMuted, fontSize: V15Type.labelSmall)),
              ],
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.all(10),
            onPressed: onImport,
            child: const Icon(CupertinoIcons.doc_text_viewfinder, size: 23),
          ),
          CupertinoButton(
            padding: const EdgeInsets.all(10),
            onPressed: onAdd,
            child: const Icon(CupertinoIcons.add_circled_solid, size: 27),
          ),
        ]),
      ],
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
            style: TextStyle(color: p.text, fontSize: V15Type.bodySmall),
            backgroundColor: p.surface,
          ),
        ),
        const SizedBox(width: 9),
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          color: p.surface,
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
              Icon(CupertinoIcons.arrow_up_arrow_down, color: p.accent, size: 18),
              const SizedBox(width: 5),
              Text(_sortLabel(sort), style: TextStyle(color: p.text, fontSize: V15Type.caption)),
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
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(tr('ui_448543036e9c'), style: TextStyle(color: context.palette.textMuted, fontSize: V15Type.caption, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 7),
        SizedBox(height: 37, child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
          _FilterChip(label: tr('ui_65f276da33cf'), selected: selectedKind == null && selectedCategory == null, onTap: onAll),
          for (final kind in PaymentKind.values) ...[
            const SizedBox(width: 8),
            _FilterChip(
              label: localizedPaymentKind(kind.name),
              selected: selectedKind == kind,
              onTap: () => onKind(selectedKind == kind ? null : kind),
            ),
          ],
          ],
        )),
        if (usedCategories.isNotEmpty) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(tr('ui_3a7c87ed0100'), style: TextStyle(color: context.palette.textMuted, fontSize: V15Type.caption, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 7),
          SizedBox(height: 37, child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
          for (final category in kCategories)
            if (usedCategories.contains(category)) ...[
              _FilterChip(
                label: category,
                selected: selectedCategory == category,
                onTap: () => onCategory(selectedCategory == category ? null : category),
              ),
              const SizedBox(width: 8),
            ],
            ],
          )),
        ],
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return CupertinoButton(
      padding: const EdgeInsetsDirectional.only(end: 8),
      minimumSize: Size.zero,
      onPressed: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? p.accent : p.surface,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: selected ? p.accent : p.stroke),
        ),
        child: Text(
          label,
          style: TextStyle(color: selected ? CupertinoColors.white : p.text, fontSize: V15Type.caption, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _SubscriptionRow extends StatelessWidget {
  final Subscription subscription;

  const _SubscriptionRow({required this.subscription});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final store = SubscriptionStore.instance;
    return Dismissible(
      key: ValueKey(subscription.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.only(end: 22),
        decoration: BoxDecoration(color: p.danger, borderRadius: BorderRadius.circular(22)),
        child: const Icon(CupertinoIcons.delete, color: CupertinoColors.white),
      ),
      confirmDismiss: (_) => _confirmDelete(context, subscription.name),
      onDismissed: (_) => store.remove(subscription.id),
      child: CupertinoButton(
        onPressed: () => showSubscriptionDetails(context, subscription),
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: p.stroke),
          ),
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
              const SizedBox(width: 12),
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
                            style: TextStyle(color: p.text, fontWeight: FontWeight.w900, fontSize: V15Type.bodySmall),
                          ),
                        ),
                        if (subscription.isPaused) _StatePill(text: tr('ui_e858894dedb7'), color: p.warning, background: p.warningSoft),
                        if (subscription.isTrialActive()) _StatePill(text: tr('ui_87a9108dad6d'), color: p.danger, background: p.dangerSoft),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${localizedCategory(subscription.category)} · ${localizedBillingCycle(subscription.cycle.name)}',
                      style: TextStyle(color: p.textMuted, fontSize: V15Type.caption),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 92),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                  Text(
                    fmtMoneyWithCurrency(subscription.price, subscription.currency),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.accent, fontWeight: FontWeight.w900, fontSize: V15Type.label),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subscription.isPaused ? tr('ui_0494e50b7138') : _renewalText(subscription.daysUntilRenewal()),
                    style: TextStyle(color: p.textMuted, fontSize: V15Type.caption, fontWeight: FontWeight.w700),
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

  const _StatePill({required this.text, required this.color, required this.background});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsetsDirectional.only(start: 6),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(99)),
        child: Text(text, style: TextStyle(color: color, fontSize: V15Type.captionSmall, fontWeight: FontWeight.w900)),
      );
}

class _LibraryEmpty extends StatelessWidget {
  const _LibraryEmpty();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.search, color: p.textMuted, size: 32),
          const SizedBox(height: 10),
          Text(tr('ui_c19b06bfe3c2'), style: TextStyle(color: p.text, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

String _renewalText(int days) {
  if (days <= 0) return tr('ui_2422f71e7f4e');
  if (days == 1) return tr('commonTomorrow');
  return tr('ui_68300aba1efe', {'value0': days});
}

Future<void> showSubscriptionDetails(BuildContext context, Subscription sub) async {
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
        builder: (context, controller) => SafeArea(
          top: false,
          child: Container(
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(color: p.stroke, borderRadius: BorderRadius.circular(99)),
                  ),
                ),
                const SizedBox(height: 20),
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(sub.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.text, fontSize: V15Type.titleSmall, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 4),
                          Text('${localizedCategory(sub.category)} · ${localizedBillingCycle(sub.cycle.name)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.textMuted, fontSize: V15Type.caption)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(fmtMoneyWithCurrency(sub.price, sub.currency), style: TextStyle(color: p.accent, fontWeight: FontWeight.w900, fontSize: V15Type.title)),
                const SizedBox(height: 16),
                _DetailMetric(icon: Icons.event_repeat_rounded, label: tr('ui_b4f5658d61f3'), value: _renewalText(sub.daysUntilRenewal())),
                const SizedBox(height: 10),
                _DetailMetric(icon: Icons.payments_outlined, label: tr('ui_118b84c4c576'), value: fmtMoneyWithCurrency(sub.monthlyCost, sub.currency)),
                if (sub.notes.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _DetailMetric(icon: Icons.notes_rounded, label: tr('ui_0be7afd7e65f'), value: sub.notes),
                ],
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) => constraints.maxWidth < 340
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _actionButtons(context, sheetContext, store, sub).first,
                            const SizedBox(height: 10),
                            _actionButtons(context, sheetContext, store, sub).last,
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: _actionButtons(context, sheetContext, store, sub).first),
                            const SizedBox(width: 10),
                            Expanded(child: _actionButtons(context, sheetContext, store, sub).last),
                          ],
                        ),
                ),
                if (sub.manageUrl.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  CupertinoButton(
                    color: p.surfaceAlt,
                    onPressed: () async {
                      final uri = normalizedHttpsUri(sub.manageUrl);
                      if (uri == null) {
                        if (sheetContext.mounted) {
                          await showCupertinoDialog<void>(
                            context: sheetContext,
                            builder: (dialogContext) => CupertinoAlertDialog(
                              title: Text(tr('ui_36f5ac81955e')),
                              content: Text(tr('ui_370a5905d9f7')),
                              actions: [CupertinoDialogAction(onPressed: () => Navigator.pop(dialogContext), child: Text(tr('ui_a64b3d93816b')))],
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
                const SizedBox(height: 4),
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
          Navigator.of(context).push(CupertinoPageRoute(builder: (_) => EditSubscriptionScreen(existing: sub)));
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

  const _DetailMetric({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: p.accent, size: 19),
              const SizedBox(width: 9),
              Expanded(child: Text(label, style: TextStyle(color: p.textMuted, fontSize: V15Type.caption))),
            ],
          ),
          const SizedBox(height: 7),
          Text(value, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.text, fontSize: V15Type.labelSmall, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
