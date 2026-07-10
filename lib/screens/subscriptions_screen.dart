/// مكتبة الاشتراكات للإصدار 8.
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/presets.dart';
import '../models/subscription.dart';
import '../services/subscription_store.dart';
import '../theme.dart';
import 'edit_subscription_screen.dart';
import 'import_screen.dart';

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
                    onAdd: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const EditSubscriptionScreen()),
                    ),
                    onImport: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ImportScreen()),
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
                  padding: const EdgeInsets.only(top: 12),
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
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
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
    return Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('اشتراكاتك', style: TextStyle(color: p.text, fontSize: 27, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('مكتبتك الخاصة للدفعات والخدمات.', style: TextStyle(color: p.textMuted, fontSize: 12.5)),
              ],
            ),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 42),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(color: p.accentSoft, borderRadius: BorderRadius.circular(14)),
            child: Text('$total', textAlign: TextAlign.center, style: TextStyle(color: p.accent, fontSize: 13, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: 'استيراد ذكي',
            child: IconButton(
              onPressed: onImport,
              style: IconButton.styleFrom(
                backgroundColor: p.surface,
                foregroundColor: p.accent,
                side: BorderSide(color: p.stroke),
              ),
              icon: const Icon(Icons.document_scanner_outlined),
            ),
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: 'إضافة اشتراك',
            child: IconButton.filled(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
            ),
          ),
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
    return TextField(
            controller: controller,
            onChanged: (_) => onChanged(),
            decoration: InputDecoration(
              hintText: 'ابحث عن خدمة أو دفعة',
              prefixIcon: Icon(Icons.search_rounded, color: p.textMuted),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (controller.text.isNotEmpty)
                    IconButton(
                      tooltip: 'مسح البحث',
                      onPressed: () {
                        controller.clear();
                        onChanged();
                      },
                      icon: Icon(Icons.close_rounded, color: p.textMuted),
                    ),
                  PopupMenuButton<_SortOrder>(
                    tooltip: 'ترتيب القائمة',
                    color: p.surface,
                    onSelected: onSort,
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: _SortOrder.renewal, child: Text('الأقرب تجديدًا')),
                      PopupMenuItem(value: _SortOrder.cost, child: Text('الأعلى تكلفة')),
                      PopupMenuItem(value: _SortOrder.name, child: Text('حسب الاسم')),
                    ],
                    icon: Icon(
                      Icons.tune_rounded,
                      color: sort == _SortOrder.renewal ? p.textMuted : p.accent,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _RoundTool extends StatelessWidget {
  final IconData icon;
  final bool active;

  const _RoundTool({required this.icon, this.active = false});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? p.accentSoft : p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: active ? p.accent.withOpacity(.35) : p.stroke),
      ),
      child: Icon(icon, color: p.accent, size: 21),
    );
  }
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
    return SizedBox(
      height: 39,
      child: ListView(
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
          for (final category in kCategories)
            if (usedCategories.contains(category)) ...[
              const SizedBox(width: 8),
              _FilterChip(
                label: category,
                selected: selectedCategory == category,
                onTap: () => onCategory(selectedCategory == category ? null : category),
              ),
            ],
        ],
      ),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
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
          style: TextStyle(color: selected ? Colors.white : p.text, fontSize: 12, fontWeight: FontWeight.w800),
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
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      confirmDismiss: (_) => _confirmDelete(context, subscription.name),
      onDismissed: (_) => store.remove(subscription.id),
      child: InkWell(
        onTap: () => showSubscriptionDetails(context, subscription),
        borderRadius: BorderRadius.circular(22),
        child: Ink(
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
                    fmtMoney(subscription.price, subscription.currency),
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
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('حذف الاشتراك؟'),
            content: Text('سيُحذف «$name» من قائمتك.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: TextButton.styleFrom(foregroundColor: context.palette.danger),
                child: const Text('حذف'),
              ),
            ],
          ),
        ) ??
        false;
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
          Icon(Icons.search_off_rounded, color: p.textMuted, size: 32),
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
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
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
                Text(fmtMoney(sub.price, sub.currency), style: TextStyle(color: p.accent, fontWeight: FontWeight.w900, fontSize: 22)),
                const SizedBox(height: 16),
                _DetailMetric(icon: Icons.event_repeat_rounded, label: 'التجديد القادم', value: _renewalText(sub.daysUntilRenewal())),
                const SizedBox(height: 10),
                _DetailMetric(icon: Icons.payments_outlined, label: 'التكلفة الشهرية', value: fmtMoney(sub.monthlyCost, sub.currency)),
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
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    onPressed: () async {
                      var raw = sub.manageUrl.trim();
                      if (!raw.startsWith('http')) raw = 'https://$raw';
                      await launchUrl(Uri.parse(raw), mode: LaunchMode.externalApplication);
                    },
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('إدارة الاشتراك'),
                  ),
                ],
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: () async {
                    await store.recordUsage(sub.id);
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                  },
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: const Text('تسجيل استخدام'),
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
      OutlinedButton.icon(
        onPressed: () {
          Navigator.pop(sheetContext);
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => EditSubscriptionScreen(existing: sub)));
        },
        icon: const Icon(Icons.edit_outlined, size: 18),
        label: const Text('تعديل'),
      ),
      FilledButton.icon(
        onPressed: () async {
          await store.togglePause(sub.id);
          if (sheetContext.mounted) Navigator.pop(sheetContext);
        },
        icon: Icon(sub.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, size: 18),
        label: Text(sub.isPaused ? 'استئناف' : 'إيقاف'),
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
