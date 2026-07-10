/// قائمة كل الاشتراكات: بحث، فلترة، فرز، وورقة تفاصيل كاملة.
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/presets.dart';
import '../models/subscription.dart';
import '../services/remote_catalog.dart';
import '../services/subscription_store.dart';
import '../theme.dart';
import 'edit_subscription_screen.dart';
import 'import_screen.dart';

enum SortMode { renewal, priceDesc, name }

extension SortModeX on SortMode {
  String get labelAr => switch (this) {
        SortMode.renewal => 'الأقرب تجديدًا',
        SortMode.priceDesc => 'الأعلى سعرًا',
        SortMode.name => 'الاسم أبجديًا',
      };

  IconData get icon => switch (this) {
        SortMode.renewal => Icons.schedule_rounded,
        SortMode.priceDesc => Icons.trending_down_rounded,
        SortMode.name => Icons.sort_by_alpha_rounded,
      };
}

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  final TextEditingController _search = TextEditingController();
  String _category = 'الكل';
  PaymentKind? _kindFilter; // null = الكل
  SortMode _sort = SortMode.renewal;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = SubscriptionStore.instance;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const EditSubscriptionScreen()),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'إضافة',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final query = _search.text.trim();
          var list = store.items.where((s) {
            final matchesQuery = query.isEmpty || s.name.contains(query);
            final matchesCat =
                _category == 'الكل' || s.category == _category;
            final matchesKind =
                _kindFilter == null || s.kind == _kindFilter;
            return matchesQuery && matchesCat && matchesKind;
          }).toList();

          switch (_sort) {
            case SortMode.renewal:
              list.sort((a, b) {
                if (a.isPaused != b.isPaused) return a.isPaused ? 1 : -1;
                return a.daysUntilRenewal().compareTo(b.daysUntilRenewal());
              });
            case SortMode.priceDesc:
              list.sort((a, b) => b.monthlyCost.compareTo(a.monthlyCost));
            case SortMode.name:
              list.sort((a, b) => a.name.compareTo(b.name));
          }

          final usedCategories = <String>{
            for (final s in store.items) s.category,
          };
          final unknownCount =
              store.items.where((s) => s.category == 'أخرى').length;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'ابحث باسم الاشتراك...',
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: AppColors.muted,
                          ),
                          suffixIcon: query.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.close_rounded),
                                  color: AppColors.muted,
                                  onPressed: () {
                                    _search.clear();
                                    setState(() {});
                                  },
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: PopupMenuButton<SortMode>(
                        tooltip: 'فرز',
                        color: AppColors.cardAlt,
                        icon: const Icon(
                          Icons.swap_vert_rounded,
                          color: AppColors.primary,
                        ),
                        onSelected: (m) => setState(() => _sort = m),
                        itemBuilder: (ctx) => [
                          for (final m in SortMode.values)
                            PopupMenuItem(
                              value: m,
                              child: Row(
                                children: [
                                  Icon(
                                    m.icon,
                                    size: 19,
                                    color: _sort == m
                                        ? AppColors.primary
                                        : AppColors.muted,
                                  ),
                                  const SizedBox(width: 9),
                                  Text(
                                    m.labelAr,
                                    style: TextStyle(
                                      color: _sort == m
                                          ? AppColors.primary
                                          : AppColors.ink,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: IconButton(
                        tooltip: 'الاستيراد الذكي',
                        icon: const Icon(
                          Icons.auto_awesome_rounded,
                          color: AppColors.gold,
                        ),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ImportScreen(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (unknownCount > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: AppCard(
                    color: AppColors.goldSoft,
                    borderColor: AppColors.goldDeep,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          color: AppColors.gold,
                          size: 20,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            '$unknownCount خدمات تحتاج تصنيفًا أدق',
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            await store.reclassifyUnknowns();
                            if (context.mounted) setState(() {});
                          },
                          child: const Text('تحسين الآن'),
                        ),
                      ],
                    ),
                  ),
                ),
              SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  children: [
                    _CatChip(
                      label: 'الكل',
                      selected: _category == 'الكل' && _kindFilter == null,
                      onTap: () => setState(() {
                        _category = 'الكل';
                        _kindFilter = null;
                      }),
                    ),
                    for (final k in PaymentKind.values)
                      if (store.items.any((s) => s.kind == k) &&
                          store.items.any((s) => s.kind != k))
                        Padding(
                          padding:
                              const EdgeInsetsDirectional.only(start: 8),
                          child: _CatChip(
                            label: switch (k) {
                              PaymentKind.subscription => 'اشتراكات',
                              PaymentKind.installment => 'أقساط',
                              PaymentKind.bill => 'فواتير',
                            },
                            selected: _kindFilter == k,
                            onTap: () => setState(() =>
                                _kindFilter = _kindFilter == k ? null : k),
                          ),
                        ),
                    for (final c in kCategories)
                      if (usedCategories.contains(c))
                        Padding(
                          padding: const EdgeInsetsDirectional.only(start: 8),
                          child: _CatChip(
                            label: '${kCategoryEmoji[c] ?? ''} $c',
                            selected: _category == c,
                            onTap: () => setState(() => _category = c),
                          ),
                        ),
                  ],
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? const Center(
                        child: Text(
                          'لا توجد اشتراكات مطابقة.\nاضغط «إضافة» للبدء.',
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(color: AppColors.muted, height: 1.7),
                        ),
                      )
                    : ListView.separated(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding:
                            const EdgeInsets.fromLTRB(16, 4, 16, 96),
                        itemCount: list.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, i) =>
                            _SubTile(sub: list[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CatChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CatChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF06231A) : AppColors.ink,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _SubTile extends StatelessWidget {
  final Subscription sub;

  const _SubTile({required this.sub});

  @override
  Widget build(BuildContext context) {
    final store = SubscriptionStore.instance;
    final catColor = categoryColor(sub.category);
    return Dismissible(
      key: ValueKey(sub.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.only(end: 22),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(20),
        ),
        child:
            const Icon(Icons.delete_rounded, color: Colors.white, size: 26),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('حذف الاشتراك؟'),
                content: Text('سيتم حذف «${sub.name}» نهائيًا.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('إلغاء'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger,
                    ),
                    child: const Text('حذف'),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) => store.remove(sub.id),
      child: Opacity(
        opacity: sub.isPaused ? 0.55 : 1,
        child: AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: InkWell(
            onTap: () => showSubscriptionDetails(context, sub),
            child: Row(
              children: [
                ServiceAvatar(
                  name: sub.name,
                  emoji: sub.emoji,
                  manageUrl: sub.manageUrl,
                  iconUrl: sub.iconUrl,
                  tint: catColor,
                  size: 48,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              sub.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15.5,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                          if (sub.kind != PaymentKind.subscription) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.cardAlt,
                                borderRadius: BorderRadius.circular(10),
                                border:
                                    Border.all(color: AppColors.border),
                              ),
                              child: Text(
                                sub.isCompleted()
                                    ? '${sub.kind.labelAr} مكتمل'
                                    : sub.kind.labelAr,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.muted,
                                ),
                              ),
                            ),
                          ],
                          if (sub.isTrialActive()) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.dangerSoft,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'تجربة',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.danger,
                                ),
                              ),
                            ),
                          ],
                          if (sub.isFamily) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primarySoft,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'عائلي',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                          if (sub.isPaused) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.goldSoft,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'موقوف',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.gold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${sub.category} • ${sub.cycle.labelAr}',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      fmtMoney(sub.price, sub.currency),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (!sub.isPaused)
                      RenewalBadge(days: sub.daysUntilRenewal()),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ورقة تفاصيل الاشتراك الكاملة.
Future<void> showSubscriptionDetails(
  BuildContext context,
  Subscription sub,
) async {
  final store = SubscriptionStore.instance;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) {
      final catColor = categoryColor(sub.category);
      final next = sub.nextRenewal();
      final payments = sub.paymentsMade();
      final spent = sub.totalSpent();
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  ServiceAvatar(
                    name: sub.name,
                    emoji: sub.emoji,
                    manageUrl: sub.manageUrl,
                    iconUrl: sub.iconUrl,
                    tint: catColor,
                    size: 58,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sub.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 19,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${sub.category} • ${sub.cycle.labelAr}',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    fmtMoney(sub.price, sub.currency),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.cardAlt,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _DetailRow(
                      icon: Icons.event_repeat_rounded,
                      label: 'التجديد القادم',
                      value:
                          '${fmtDate(next)} (بعد ${sub.daysUntilRenewal()} يوم)',
                    ),
                    _DetailRow(
                      icon: Icons.flag_rounded,
                      label: 'تاريخ البداية',
                      value: fmtDate(sub.anchorDate),
                    ),
                    _DetailRow(
                      icon: Icons.receipt_long_rounded,
                      label: 'عدد الدفعات حتى الآن',
                      value: '$payments دفعة',
                    ),
                    _DetailRow(
                      icon: Icons.savings_rounded,
                      label: 'إجمالي ما دفعته',
                      value: fmtMoney(spent, sub.currency),
                      valueColor: AppColors.gold,
                    ),
                    _DetailRow(
                      icon: Icons.payments_rounded,
                      label: 'التكلفة الشهرية',
                      value: fmtMoney(sub.monthlyCost, sub.currency),
                    ),
                    _DetailRow(
                      icon: Icons.insights_rounded,
                      label: 'الاستخدام المسجل',
                      value: sub.usageCount == 0
                          ? 'لم تسجل استخدامًا بعد'
                          : '${sub.usageCount} مرة'
                              '${sub.costPerUse == null ? '' : ' • ${fmtMoney(sub.costPerUse!, sub.currency)} لكل استخدام'}',
                    ),
                    if (sub.kind == PaymentKind.installment &&
                        sub.totalInstallments != null) ...[
                      _DetailRow(
                        icon: Icons.pie_chart_outline_rounded,
                        label: 'الأقساط المدفوعة',
                        value:
                            '${sub.paymentsMade()} من ${sub.totalInstallments}',
                      ),
                      _DetailRow(
                        icon: Icons.flag_circle_rounded,
                        label: 'آخر قسط في',
                        value: sub.lastInstallmentDate == null
                            ? '—'
                            : fmtDate(sub.lastInstallmentDate!),
                        valueColor: sub.isCompleted()
                            ? AppColors.primary
                            : null,
                      ),
                    ],
                    if (sub.isTrialActive())
                      _DetailRow(
                        icon: Icons.hourglass_bottom_rounded,
                        label: 'التجربة المجانية تنتهي في',
                        value: fmtDate(sub.trialEndDate!),
                        valueColor: AppColors.danger,
                      ),
                    if (sub.reminderDays > 0)
                      _DetailRow(
                        icon: Icons.notifications_active_rounded,
                        label: 'التذكير قبل التجديد',
                        value: 'بـ ${sub.reminderDays} '
                            '${sub.reminderDays == 1 ? "يوم" : "أيام"}',
                      ),
                    if (RemoteCatalog.instance.byName(sub.name)?.priceHint
                        case final double hint
                        when (hint - sub.price).abs() > hint * 0.05)
                      _DetailRow(
                        icon: Icons.sell_rounded,
                        label: 'السعر المعتاد حاليًا',
                        value: fmtMoney(hint, 'SAR'),
                        valueColor: sub.price > hint
                            ? AppColors.warn
                            : AppColors.primary,
                      ),
                    if (sub.isFamily)
                      _DetailRow(
                        icon: Icons.group_rounded,
                        label: 'عائلي — نصيبك من ${sub.familyMembers} أفراد',
                        value: fmtMoney(sub.pricePerMember, sub.currency),
                        valueColor: AppColors.primary,
                      ),
                    if (sub.paymentMethod != 'غير محدد')
                      _DetailRow(
                        icon: Icons.credit_card_rounded,
                        label: 'طريقة الدفع',
                        value: sub.paymentMethod,
                      ),
                    if (sub.priceHistory.isNotEmpty) ...[
                      _DetailRow(
                        icon: Icons.trending_up_rounded,
                        label: 'تغيّر السعر منذ البداية',
                        value:
                            '${sub.priceHistory.first.oldPrice == sub.price ? '' : '${fmtMoney(sub.priceHistory.first.oldPrice, sub.currency)} ← ${fmtMoney(sub.price, sub.currency)}'}'
                            '${sub.priceChangePercent == null ? '' : ' (${sub.priceChangePercent! >= 0 ? '+' : ''}${sub.priceChangePercent!.toStringAsFixed(0)}٪)'}',
                        valueColor: (sub.priceChangePercent ?? 0) > 0
                            ? AppColors.warn
                            : AppColors.primary,
                      ),
                    ],
                    if (sub.notes.isNotEmpty)
                      _DetailRow(
                        icon: Icons.sticky_note_2_rounded,
                        label: 'ملاحظات',
                        value: sub.notes,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  await store.recordUsage(sub.id);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text('سجّل استخدامًا الآن'),
              ),
              const SizedBox(height: 8),
              if (sub.manageUrl.isNotEmpty) ...[
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () async {
                    var raw = sub.manageUrl.trim();
                    if (!raw.startsWith('http')) raw = 'https://$raw';
                    final uri = Uri.tryParse(raw);
                    if (uri != null &&
                        uri.scheme == 'https' &&
                        uri.host.isNotEmpty &&
                        uri.userInfo.isEmpty) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('فتح صفحة إدارة الاشتراك'),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                EditSubscriptionScreen(existing: sub),
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit_rounded, size: 20),
                      label: const Text('تعديل'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        foregroundColor: AppColors.gold,
                        side: const BorderSide(color: AppColors.goldDeep),
                      ),
                      onPressed: () async {
                        await store.togglePause(sub.id);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      icon: Icon(
                        sub.isPaused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                        size: 20,
                      ),
                      label: Text(sub.isPaused ? 'استئناف' : 'إيقاف'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: AppColors.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 13.5,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.left,
              style: TextStyle(
                color: valueColor ?? AppColors.ink,
                fontWeight: FontWeight.w800,
                fontSize: 13.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
