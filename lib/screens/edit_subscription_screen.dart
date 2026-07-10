/// إضافة أو تعديل اشتراك، مع مُلقِّم سريع من الخدمات الشائعة خليجيًا.
library;

import 'package:flutter/material.dart';

import '../data/presets.dart';
import '../models/subscription.dart';
import '../services/itunes_search.dart';
import '../services/remote_catalog.dart';
import '../services/subscription_store.dart';
import '../theme.dart';

class EditSubscriptionScreen extends StatefulWidget {
  final Subscription? existing;

  const EditSubscriptionScreen({super.key, this.existing});

  @override
  State<EditSubscriptionScreen> createState() =>
      _EditSubscriptionScreenState();
}

class _EditSubscriptionScreenState extends State<EditSubscriptionScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _notes;
  late final TextEditingController _url;

  late String _emoji;
  late String _currency;
  late BillingCycle _cycle;
  late DateTime _anchor;
  late String _category;
  late bool _paused;
  late String _payMethod;
  late int _reminderDays;
  late bool _trialOn;
  late DateTime _trialEnd;
  late bool _isFamily;
  late int _famCount;
  String _iconUrl = '';
  bool _searching = false;
  PaymentKind _kind = PaymentKind.subscription;
  late final TextEditingController _installments;

  bool get isEditing => widget.existing != null;

  static const Map<int, String> kReminderOptions = {
    0: 'بدون تذكير',
    1: 'قبل يوم',
    3: 'قبل ٣ أيام',
    7: 'قبل أسبوع',
  };

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _price = TextEditingController(
      text: e == null ? '' : e.price.toString(),
    );
    _notes = TextEditingController(text: e?.notes ?? '');
    _url = TextEditingController(text: e?.manageUrl ?? '');
    _emoji = e?.emoji ?? '🔖';
    _currency = e?.currency ?? SubscriptionStore.instance.defaultCurrency;
    _cycle = e?.cycle ?? BillingCycle.monthly;
    _anchor = e?.anchorDate ?? DateTime.now();
    _category = e?.category ?? 'أخرى';
    _paused = e?.isPaused ?? false;
    _payMethod = e?.paymentMethod ?? 'غير محدد';
    if (!kPaymentMethods.contains(_payMethod)) {
      _payMethod = 'أخرى';
    }
    _reminderDays = e?.reminderDays ?? 3;
    if (!kReminderOptions.containsKey(_reminderDays)) {
      _reminderDays = 3;
    }
    _trialOn = e?.trialEndDate != null;
    _trialEnd =
        e?.trialEndDate ?? DateTime.now().add(const Duration(days: 7));
    _isFamily = e?.isFamily ?? false;
    _famCount = (e?.familyMembers ?? 2).clamp(2, 20);
    _iconUrl = e?.iconUrl ?? '';
    _kind = e?.kind ?? PaymentKind.subscription;
    _installments = TextEditingController(
      text: e?.totalInstallments?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _notes.dispose();
    _url.dispose();
    _installments.dispose();
    super.dispose();
  }

  void _applyPreset(ServicePreset p) {
    setState(() {
      _name.text = p.name;
      _emoji = p.emoji;
      _category = p.category;
      final remote = RemoteCatalog.instance.byName(p.name);
      if (remote != null) {
        if (_url.text.trim().isEmpty) _url.text = remote.manageUrl;
        if (_price.text.trim().isEmpty && remote.priceHint != null) {
          _price.text = remote.priceHint.toString();
        }
      }
    });
  }

  void _applyRemote(RemoteService r) {
    setState(() {
      _name.text = r.name;
      _emoji = r.emoji;
      _category =
          kCategories.contains(r.category) ? r.category : 'أخرى';
      if (_url.text.trim().isEmpty) _url.text = r.manageUrl;
      if (_price.text.trim().isEmpty && r.priceHint != null) {
        _price.text = r.priceHint.toString();
      }
    });
  }

  Future<void> _openPresetPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'خدمات شائعة',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // خدمات القاعدة المحدّثة عن بُعد (بأسعار تقريبية).
                      for (final r in RemoteCatalog.instance.services)
                        InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            _applyRemote(r);
                            Navigator.pop(ctx);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppColors.primaryDeep,
                              ),
                            ),
                            child: Text(
                              r.priceHint == null
                                  ? '${r.emoji} ${r.name}'
                                  : '${r.emoji} ${r.name} • ${fmtMoney(r.priceHint!, 'SAR')}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                        ),
                      for (final p in kPresets)
                        if (RemoteCatalog.instance.byName(p.name) == null)
                        InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            _applyPreset(p);
                            Navigator.pop(ctx);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.cardAlt,
                              borderRadius: BorderRadius.circular(14),
                              border:
                                  Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              '${p.emoji} ${p.name}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _anchor,
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
      helpText: 'تاريخ بداية الاشتراك أو آخر تجديد',
    );
    if (picked != null) {
      setState(() => _anchor = picked);
    }
  }

  Future<void> _smartSearch() async {
    final term = _name.text.trim();
    if (term.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتب اسم الخدمة أولًا ثم اضغط البحث')),
      );
      return;
    }
    setState(() => _searching = true);
    List<AppSearchResult> results = const [];
    try {
      results = await ItunesSearch.search(term);
    } catch (_) {}
    if (!mounted) return;
    setState(() => _searching = false);
    if (results.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لم نجد نتائج — تأكد من الاسم أو الإنترنت'),
        ),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'اختر التطبيق الصحيح',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 12),
              for (final r in results.take(5))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: r.iconUrl.isEmpty
                        ? const SizedBox(width: 44, height: 44)
                        : Image.network(
                            r.iconUrl,
                            width: 44,
                            height: 44,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox(width: 44, height: 44),
                          ),
                  ),
                  title: Text(
                    r.name,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                    ),
                  ),
                  subtitle: r.seller.isEmpty
                      ? null
                      : Text(
                          r.seller,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                  onTap: () {
                    setState(() {
                      _name.text = r.name;
                      _iconUrl = r.iconUrl;
                    });
                    Navigator.pop(ctx);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  String? _normalizedManageUrl(String raw) {
    if (raw.isEmpty) return '';
    final candidate = raw.startsWith('https://') ? raw : 'https://$raw';
    final uri = Uri.tryParse(candidate);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    return uri.toString();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final manageUrl = _normalizedManageUrl(_url.text.trim());
    if (manageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('استخدم رابط HTTPS صالحًا أو اتركه فارغًا.')),
      );
      return;
    }
    final price =
        double.parse(_price.text.trim().replaceAll('،', '.').replaceAll(',', '.'));
    final sub = Subscription(
      id: widget.existing?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: _name.text.trim(),
      emoji: _emoji.trim().isEmpty ? '🔖' : _emoji.trim(),
      price: price,
      currency: _currency,
      cycle: _cycle,
      anchorDate: _anchor,
      category: _category,
      notes: _notes.text.trim(),
      isPaused: _paused,
      paymentMethod: _payMethod,
      manageUrl: manageUrl,
      reminderDays: _reminderDays,
      trialEndDate:
          (_kind == PaymentKind.subscription && _trialOn) ? _trialEnd : null,
      isFamily: _isFamily,
      familyMembers: _famCount,
      iconUrl: _iconUrl,
      kind: _kind,
      totalInstallments: _kind == PaymentKind.installment
          ? int.tryParse(_installments.text.trim())
          : null,
    );
    await SubscriptionStore.instance.upsert(sub);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(isEditing ? 'تم حفظ التعديلات' : 'تمت إضافة «${sub.name}»')),
    );
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الاشتراك؟'),
        content: Text('سيتم حذف «${widget.existing!.name}» نهائيًا.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await SubscriptionStore.instance.remove(widget.existing!.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _anchor;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'تعديل الاشتراك' : 'اشتراك جديد'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              SegmentedButton<PaymentKind>(
                segments: [
                  for (final k in PaymentKind.values)
                    ButtonSegment(value: k, label: Text(k.labelAr)),
                ],
                selected: {_kind},
                onSelectionChanged: (v) =>
                    setState(() => _kind = v.first),
                style: SegmentedButton.styleFrom(
                  backgroundColor: AppColors.card,
                  foregroundColor: AppColors.muted,
                  selectedBackgroundColor: AppColors.primary,
                  selectedForegroundColor: const Color(0xFF06231A),
                  side: const BorderSide(color: AppColors.border),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (!isEditing && _kind == PaymentKind.subscription)
                OutlinedButton.icon(
                  onPressed: _openPresetPicker,
                  icon: const Icon(Icons.flash_on_rounded),
                  label: const Text('اختر من الخدمات الشائعة'),
                ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 74,
                    child: TextFormField(
                      initialValue: _emoji,
                      textAlign: TextAlign.center,
                      maxLength: 2,
                      style: const TextStyle(fontSize: 24),
                      decoration: const InputDecoration(
                        counterText: '',
                        labelText: 'رمز',
                      ),
                      onChanged: (v) => _emoji = v,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _name,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'اسم الاشتراك *',
                        hintText: 'مثال: شاهد VIP',
                        suffixIcon: IconButton(
                          tooltip: 'بحث ذكي عن التطبيق وشعاره',
                          onPressed: _searching ? null : _smartSearch,
                          icon: _searching
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: AppColors.primary,
                                  ),
                                )
                              : const Icon(
                                  Icons.travel_explore_rounded,
                                  color: AppColors.primary,
                                ),
                        ),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'أدخل اسم الاشتراك'
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _price,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textDirection: TextDirection.ltr,
                      decoration: const InputDecoration(
                        labelText: 'السعر *',
                        hintText: '19.99',
                      ),
                      validator: (v) {
                        final parsed = double.tryParse(
                          (v ?? '')
                              .trim()
                              .replaceAll('،', '.')
                              .replaceAll(',', '.'),
                        );
                        if (parsed == null || parsed <= 0) {
                          return 'أدخل سعرًا صحيحًا';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: _currency,
                      dropdownColor: AppColors.cardAlt,
                      decoration:
                          const InputDecoration(labelText: 'العملة'),
                      items: [
                        for (final c in currencySymbols.keys)
                          DropdownMenuItem(
                            value: c,
                            child: Text('${currencySymbols[c]} ($c)'),
                          ),
                      ],
                      onChanged: (v) =>
                          setState(() => _currency = v ?? _currency),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'دورة التجديد',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final c in BillingCycle.values)
                    ChoiceChip(
                      label: Text(c.labelAr),
                      selected: _cycle == c,
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.card,
                      labelStyle: TextStyle(
                        color: _cycle == c
                            ? const Color(0xFF06231A)
                            : AppColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                      side: BorderSide(
                        color: _cycle == c
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                      onSelected: (_) => setState(() => _cycle = c),
                    ),
                ],
              ),
              if (_kind == PaymentKind.installment) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _installments,
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'عدد الأقساط الكلي',
                    hintText: 'مثال: 12 — اتركه فارغًا إن كان مفتوحًا',
                  ),
                ),
              ],
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(14),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'تاريخ البداية / آخر تجديد',
                    suffixIcon: Icon(
                      Icons.calendar_month_rounded,
                      color: AppColors.muted,
                    ),
                  ),
                  child: Text(
                    fmtDate(d),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _category,
                dropdownColor: AppColors.cardAlt,
                decoration: const InputDecoration(labelText: 'التصنيف'),
                items: [
                  for (final c in kCategories)
                    DropdownMenuItem(
                      value: c,
                      child: Text('${kCategoryEmoji[c] ?? ''} $c'),
                    ),
                ],
                onChanged: (v) => setState(() => _category = v ?? _category),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _payMethod,
                dropdownColor: AppColors.cardAlt,
                decoration:
                    const InputDecoration(labelText: 'طريقة الدفع'),
                items: [
                  for (final m in kPaymentMethods)
                    DropdownMenuItem(value: m, child: Text(m)),
                ],
                onChanged: (v) =>
                    setState(() => _payMethod = v ?? _payMethod),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                value: _reminderDays,
                dropdownColor: AppColors.cardAlt,
                decoration: const InputDecoration(
                  labelText: 'إشعار التذكير قبل التجديد',
                ),
                items: [
                  for (final e in kReminderOptions.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) =>
                    setState(() => _reminderDays = v ?? _reminderDays),
              ),
              const SizedBox(height: 8),
              if (_kind == PaymentKind.subscription)
              SwitchListTile(
                value: _trialOn,
                onChanged: (v) => setState(() => _trialOn = v),
                title: const Text(
                  'تجربة مجانية',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                subtitle: const Text(
                  'سنحذرك قبل تحولها لاشتراك مدفوع بيومين',
                  style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                ),
                activeColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
              ),
              if (_trialOn) ...[
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _trialEnd,
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2100),
                      helpText: 'متى تنتهي التجربة المجانية؟',
                    );
                    if (picked != null) {
                      setState(() => _trialEnd = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'تاريخ انتهاء التجربة',
                      suffixIcon: Icon(
                        Icons.hourglass_bottom_rounded,
                        color: AppColors.muted,
                      ),
                    ),
                    child: Text(
                      fmtDate(_trialEnd),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],
              SwitchListTile(
                value: _isFamily,
                onChanged: (v) => setState(() => _isFamily = v),
                title: const Text(
                  'اشتراك عائلي / مشترك',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                subtitle: const Text(
                  'يقسم التكلفة على المشاركين ويعرض نصيبك',
                  style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                ),
                activeColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
              ),
              if (_isFamily)
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'عدد المشاركين (أنت منهم)',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _famCount <= 2
                          ? null
                          : () => setState(() => _famCount--),
                      icon: const Icon(
                        Icons.remove_circle_outline_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      '$_famCount',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        color: AppColors.ink,
                      ),
                    ),
                    IconButton(
                      onPressed: _famCount >= 20
                          ? null
                          : () => setState(() => _famCount++),
                      icon: const Icon(
                        Icons.add_circle_outline_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _url,
                keyboardType: TextInputType.url,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'رابط إدارة الاشتراك (اختياري)',
                  hintText: 'netflix.com/account',
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _notes,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات (اختياري)',
                  hintText: 'مثال: مشترك مع العائلة / يُلغى قبل رمضان',
                ),
              ),
              if (isEditing) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  value: _paused,
                  onChanged: (v) => setState(() => _paused = v),
                  title: const Text(
                    'إيقاف مؤقت',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  subtitle: const Text(
                    'لن يُحتسب في المصروف ولا في التجديدات',
                    style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                  ),
                  activeColor: AppColors.primary,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check_rounded),
                label: Text(isEditing ? 'حفظ التعديلات' : 'إضافة الاشتراك'),
              ),
              if (isEditing) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _delete,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                  ),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('حذف هذا الاشتراك'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
