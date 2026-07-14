/// مكتبة الاشتراكات للإصدار 8.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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
                Text('الاشتراكات', style: TextStyle(color: p.text, fontSize: 30, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('$total اشتراكًا نشطًا', style: TextStyle(color: p.textMuted, fontSize: 13)),
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
            placeholder: 'ابحث باسم الخدمة',
            onChanged: (_) => onChanged(),
            style: TextStyle(color: p.text, fontSize: 15),
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
              title: 'ترتيب الاشتراكات',
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
              Text(_sortLabel(sort), style: TextStyle(color: p.text, fontSize: 11.5)),
            ],
          ),
        ),
      ],
    );
  }

  String _sortLabel(_SortOrder value) => switch (value) {
        _SortOrder.renewal => 'الأقرب',
        _SortOrder.cost => 'الأعلى',
        _SortOrder.name => 'الاسم',
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
          child: Text('نوع الدفعة', style: TextStyle(color: context.palette.textMuted, fontSize: 11.5, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 7),
        SizedBox(height: 37, child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
          _FilterChip(label: 'الكل', selected: selectedKind == null && selectedCategory == null, onTap: onAll),
          for (final kind in PaymentKind.values) ...[
            const SizedBox(width: 8),
            _FilterChip(
              label: kind.labelAr,
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
            child: Text('التصنيف', style: TextStyle(color: context.palette.textMuted, fontSize: 11.5, fontWeight: FontWeight.w700)),
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
          style: TextStyle(color: selected ? CupertinoColors.white : p.text, fontSize: 12, fontWeight: FontWeight.w700),
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
                            style: TextStyle(color: p.text, fontWeight: FontWeight.w900, fontSize: 15),
                          ),
                        ),
                        if (subscription.isPaused) _StatePill(text: 'موقوف', color: p.warning, background: p.warningSoft),
                        if (subscription.isTrialActive()) _StatePill(text: 'تجربة', color: p.danger, background: p.dangerSoft),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${subscription.category} · ${subscription.cycle.labelAr}',
                      style: TextStyle(color: p.textMuted, fontSize: 11.5),
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
                    style: TextStyle(color: p.accent, fontWeight: FontWeight.w900, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subscription.isPaused ? 'متوقف' : _renewalText(subscription.daysUntilRenewal()),
                    style: TextStyle(color: p.textMuted, fontSize: 10.5, fontWeight: FontWeight.w700),
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
      title: 'حذف الاشتراك؟',
      message: 'سيُحذف «$name» من قائمتك نهائيًا.',
      confirmLabel: 'حذف',
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
        child: Text(text, style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w900)),
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
          Text('لا توجد نتائج مطابقة.', style: TextStyle(color: p.text, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

String _renewalText(int days) {
  if (days <= 0) return 'اليوم';
  if (days == 1) return 'غدًا';
  return 'بعد $days يوم';
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
                          Text(sub.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.text, fontSize: 19, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 4),
                          Text('${sub.category} · ${sub.cycle.labelAr}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.textMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(fmtMoneyWithCurrency(sub.price, sub.currency), style: TextStyle(color: p.accent, fontWeight: FontWeight.w900, fontSize: 22)),
                const SizedBox(height: 16),
                _DetailMetric(icon: Icons.event_repeat_rounded, label: 'التجديد القادم', value: _renewalText(sub.daysUntilRenewal())),
                const SizedBox(height: 10),
                _DetailMetric(icon: Icons.payments_outlined, label: 'التكلفة الشهرية', value: fmtMoneyWithCurrency(sub.monthlyCost, sub.currency)),
                if (sub.notes.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _DetailMetric(icon: Icons.notes_rounded, label: 'ملاحظة', value: sub.notes),
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
                              title: const Text('تعذر فتح الرابط'),
                              content: const Text('الرابط غير آمن. استخدم رابط HTTPS من شاشة التعديل.'),
                              actions: [CupertinoDialogAction(onPressed: () => Navigator.pop(dialogContext), child: const Text('حسنًا'))],
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
                    child: const Text('فتح صفحة إدارة الاشتراك'),
                  ),
                ],
                const SizedBox(height: 4),
                CupertinoButton(
                  onPressed: () async {
                    await store.recordUsage(sub.id);
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                  },
                  child: const Text('تسجيل استخدام الخدمة'),
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
        child: const Text('تعديل'),
      ),
      CupertinoButton.filled(
        onPressed: () async {
          await store.togglePause(sub.id);
          if (sheetContext.mounted) Navigator.pop(sheetContext);
        },
        child: Text(sub.isPaused ? 'استئناف المتابعة' : 'إيقاف مؤقت'),
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
              Expanded(child: Text(label, style: TextStyle(color: p.textMuted, fontSize: 12))),
            ],
          ),
          const SizedBox(height: 7),
          Text(value, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.text, fontSize: 13, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
