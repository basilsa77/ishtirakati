/// إضافة أو تعديل اشتراك، مع مُلقِّم سريع من الخدمات الشائعة خليجيًا.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/presets.dart';
import '../models/subscription.dart';
import '../services/itunes_search.dart';
import '../services/remote_catalog.dart';
import '../services/subscription_store.dart';
import '../services/safe_url.dart';
import '../theme.dart';
import '../widgets/ios_controls.dart';
import 'plan_comparison_screen.dart';

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
  late bool _autoRenews;
  late bool _isEssential;
  late int _famCount;
  late final TextEditingController _planName;
  String _iconUrl = '';
  bool _searching = false;
  String? _formError;
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
    _autoRenews = e?.autoRenews ?? true;
    _isEssential = e?.isEssential ?? false;
    _famCount = (e?.familyMembers ?? 2).clamp(2, 20);
    _planName = TextEditingController(text: e?.planName ?? '');
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
    _planName.dispose();
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
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * .78),
          child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Text(
                'خدمات شائعة',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: ctx.palette.text,
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
                              color: ctx.palette.accentSoft,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: ctx.palette.accentStrong,
                              ),
                            ),
                            child: Text(
                              r.priceHint == null
                                  ? '${r.emoji} ${r.name}'
                                  : '${r.emoji} ${r.name} • ${fmtMoney(r.priceHint!, 'SAR')}',
                               style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                                color: ctx.palette.text,
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
                              color: ctx.palette.surfaceAlt,
                              borderRadius: BorderRadius.circular(14),
                              border:
                                  Border.all(color: ctx.palette.stroke),
                            ),
                            child: Text(
                              '${p.emoji} ${p.name}',
                               style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                                color: ctx.palette.text,
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
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await _showIosDatePicker(_anchor);
    if (picked != null) {
      setState(() => _anchor = picked);
    }
  }

  Future<DateTime?> _showIosDatePicker(DateTime initial) {
    var selected = initial;
    return showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (sheetContext) => Container(
        height: 330,
        color: sheetContext.palette.surface,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Row(
                children: [
                  CupertinoButton(onPressed: () => Navigator.pop(sheetContext), child: const Text('إلغاء')),
                  const Spacer(),
                  CupertinoButton(
                    onPressed: () => Navigator.pop(sheetContext, selected),
                    child: const Text('تم', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: initial,
                  minimumDate: DateTime(2015),
                  maximumDate: DateTime(2100),
                  onDateTimeChanged: (value) => selected = value,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _smartSearch() async {
    final term = _name.text.trim();
    if (term.isEmpty) {
      setState(() => _formError = 'اكتب اسم الخدمة أولًا، ثم ابدأ البحث.');
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
      setState(() => _formError = 'لم نجد خدمة مطابقة. تحقق من الاسم والاتصال بالإنترنت.');
      return;
    }
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * .78),
          child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Text(
                'اختر التطبيق الصحيح',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: ctx.palette.text,
                ),
              ),
              const SizedBox(height: 12),
              for (final r in results.take(5))
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  onPressed: () {
                    setState(() {
                      _name.text = r.name;
                      _iconUrl = r.iconUrl;
                    });
                    Navigator.pop(ctx);
                  },
                  child: Row(
                    children: [
                      ClipRRect(
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
                      const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.name, style: TextStyle(color: ctx.palette.text, fontWeight: FontWeight.w800, fontSize: 14.5)),
                        if (r.seller.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(r.seller, style: TextStyle(color: ctx.palette.textMuted, fontSize: 12)),
                        ],
                      ],
                    ),
                  ),
                  Icon(CupertinoIcons.chevron_left, color: ctx.palette.textMuted, size: 17),
                    ],
                  ),
                ),
            ],
          ),
          ),
        ),
      ),
    );
  }

  String? _normalizedManageUrl(String raw) {
    if (raw.isEmpty) return '';
    return normalizedHttpsUri(raw)?.toString();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final price = double.tryParse(
      _price.text.trim().replaceAll('،', '.').replaceAll(',', '.'),
    );
    if (name.isEmpty || price == null || price <= 0) {
      setState(() => _formError = name.isEmpty
          ? 'أدخل اسم الاشتراك.'
          : 'أدخل سعرًا صحيحًا أكبر من صفر.');
      return;
    }
    final manageUrl = _normalizedManageUrl(_url.text.trim());
    if (manageUrl == null) {
      setState(() => _formError = 'استخدم رابط HTTPS صالحًا، أو اترك الرابط فارغًا.');
      return;
    }
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
      autoRenews: _autoRenews,
      isEssential: _isEssential,
      planName: _planName.text.trim(),
      lastReviewedAt: widget.existing?.lastReviewedAt,
      iconUrl: _iconUrl,
      kind: _kind,
      totalInstallments: _kind == PaymentKind.installment
          ? int.tryParse(_installments.text.trim())
          : null,
    );
    await SubscriptionStore.instance.upsert(sub);
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await showIosConfirmation(
      context: context,
      title: 'حذف الاشتراك؟',
      message: 'سيتم حذف «${widget.existing!.name}» نهائيًا.',
      confirmLabel: 'حذف',
      destructive: true,
    );
    if (ok) {
      await SubscriptionStore.instance.remove(widget.existing!.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  String _paymentLabel(String value) => switch (value) {
        'غير محدد' => 'لم أحدد وسيلة الدفع',
        'بطاقة مدى' => 'بطاقة مدى',
        'بطاقة ائتمانية' => 'بطاقة ائتمانية',
        'Apple Pay' => 'Apple Pay',
        'STC Pay' => 'stc pay',
        'PayPal' => 'PayPal',
        'رصيد المتجر' => 'رصيد متجر التطبيقات',
        _ => value,
      };

  @override
  Widget build(BuildContext context) {
    final d = _anchor;
    final p = context.palette;
    return CupertinoPageScaffold(
      backgroundColor: p.canvas,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: p.canvas.withValues(alpha: .92),
        border: Border(bottom: BorderSide(color: p.stroke)),
        middle: Text(isEditing ? 'تعديل الاشتراك' : 'اشتراك جديد'),
      ),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
            children: [
              CupertinoSlidingSegmentedControl<PaymentKind>(
                groupValue: _kind,
                backgroundColor: p.surface,
                thumbColor: p.accent,
                children: {
                  for (final kind in PaymentKind.values)
                    kind: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        kind.labelAr,
                        style: TextStyle(
                          color: _kind == kind ? Colors.white : p.textMuted,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                },
                onValueChanged: (value) {
                  if (value != null) setState(() => _kind = value);
                },
              ),
              const SizedBox(height: 14),
              if (!isEditing && _kind == PaymentKind.subscription)
                CupertinoButton(
                  color: p.accentSoft,
                  onPressed: _openPresetPicker,
                  child: const Text('اختيار خدمة معروفة'),
                ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 21),
                    child: ServiceAvatar(
                      name: _name.text,
                      emoji: _emoji,
                      iconUrl: _iconUrl,
                      manageUrl: _url.text,
                      tint: categoryColor(_category),
                      size: 52,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: IosTextField(
                      controller: _name,
                      label: 'اسم الاشتراك',
                      textInputAction: TextInputAction.next,
                      placeholder: 'مثال: شاهد VIP',
                      suffix: CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          onPressed: _searching ? null : _smartSearch,
                          child: _searching
                              ? const CupertinoActivityIndicator()
                              : const Icon(CupertinoIcons.search, size: 20),
                        ),
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
                    child: IosTextField(
                      controller: _price,
                      label: 'مبلغ التجديد',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textDirection: TextDirection.ltr,
                      placeholder: '19.99',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: IosPickerRow(
                      label: 'العملة',
                      value: '${currencySymbols[_currency]}  $_currency',
                      onPressed: () async {
                        final selected = await showIosPicker<String>(
                          context: context,
                          title: 'اختر العملة',
                          selected: _currency,
                          values: currencySymbols.keys.toList(),
                          label: (value) => '${currencySymbols[value]}  $value',
                        );
                        if (selected != null) setState(() => _currency = selected);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'دورة التجديد',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: p.text,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: CupertinoSlidingSegmentedControl<BillingCycle>(
                  groupValue: _cycle,
                  thumbColor: p.surface,
                  children: {
                    for (final c in BillingCycle.values)
                      c: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                        child: Text(c.labelAr, style: TextStyle(color: p.text, fontWeight: FontWeight.w700)),
                      ),
                  },
                  onValueChanged: (value) {
                    if (value != null) setState(() => _cycle = value);
                  },
                ),
              ),
              if (_kind == PaymentKind.installment) ...[
                const SizedBox(height: 14),
                IosTextField(
                  controller: _installments,
                  label: 'إجمالي عدد الأقساط',
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  placeholder: 'مثال: 12، أو اتركه فارغًا',
                ),
              ],
              const SizedBox(height: 16),
              IosPickerRow(
                label: 'تاريخ آخر دفعة أو بداية الاشتراك',
                value: fmtDate(d),
                icon: CupertinoIcons.calendar,
                onPressed: _pickDate,
              ),
              const SizedBox(height: 14),
              IosPickerRow(
                label: 'التصنيف',
                value: _category,
                icon: CupertinoIcons.square_grid_2x2,
                onPressed: () async {
                  final selected = await showIosPicker<String>(
                    context: context,
                    title: 'اختر التصنيف',
                    selected: _category,
                    values: kCategories,
                    label: (value) => value,
                  );
                  if (selected != null) setState(() => _category = selected);
                },
              ),
              const SizedBox(height: 14),
              IosPickerRow(
                label: 'وسيلة الدفع',
                value: _paymentLabel(_payMethod),
                icon: CupertinoIcons.creditcard,
                onPressed: () async {
                  final selected = await showIosPicker<String>(
                    context: context,
                    title: 'اختر وسيلة الدفع',
                    selected: _payMethod,
                    values: kPaymentMethods,
                    label: _paymentLabel,
                  );
                  if (selected != null) setState(() => _payMethod = selected);
                },
              ),
              const SizedBox(height: 14),
              IosPickerRow(
                label: 'موعد تنبيه التجديد',
                value: kReminderOptions[_reminderDays]!,
                icon: CupertinoIcons.bell,
                onPressed: () async {
                  final selected = await showIosPicker<int>(
                    context: context,
                    title: 'موعد تنبيه التجديد',
                    selected: _reminderDays,
                    values: kReminderOptions.keys.toList(),
                    label: (value) => kReminderOptions[value]!,
                  );
                  if (selected != null) setState(() => _reminderDays = selected);
                },
              ),
              const SizedBox(height: 8),
              if (_kind == PaymentKind.subscription)
              _CupertinoSwitchRow(
                value: _trialOn,
                onChanged: (v) => setState(() => _trialOn = v),
                title: 'تجربة مجانية',
                detail: 'سنحذرك قبل تحولها لاشتراك مدفوع بيومين',
              ),
              if (_trialOn) ...[
                IosPickerRow(
                  label: 'تاريخ انتهاء التجربة المجانية',
                  value: fmtDate(_trialEnd),
                  icon: CupertinoIcons.time,
                  onPressed: () async {
                    final picked = await _showIosDatePicker(_trialEnd);
                    if (picked != null) {
                      setState(() => _trialEnd = picked);
                    }
                  },
                ),
                const SizedBox(height: 6),
              ],
              _CupertinoSwitchRow(
                value: _isFamily,
                onChanged: (v) => setState(() => _isFamily = v),
                title: 'اشتراك عائلي / مشترك',
                detail: 'يقسم التكلفة على المشاركين ويعرض نصيبك',
              ),
              if (_isFamily)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'عدد المشاركين (أنت منهم)',
                        style: TextStyle(
                          color: p.textMuted,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    CupertinoButton(
                      padding: const EdgeInsets.all(8),
                      onPressed: _famCount <= 2
                          ? null
                          : () => setState(() => _famCount--),
                      child: Icon(
                        CupertinoIcons.minus_circle,
                        color: p.accent,
                      ),
                    ),
                    Text(
                      '$_famCount',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        color: p.text,
                      ),
                    ),
                    CupertinoButton(
                      padding: const EdgeInsets.all(8),
                      onPressed: _famCount >= 20
                          ? null
                          : () => setState(() => _famCount++),
                      child: Icon(
                        CupertinoIcons.plus_circle,
                        color: p.accent,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              CupertinoFormSection.insetGrouped(
                backgroundColor: Colors.transparent,
                header: Text(
                  'المتابعة المالية',
                  style: TextStyle(color: p.textMuted),
                ),
                children: [
                  CupertinoFormRow(
                    prefix: const Text('يتجدد تلقائيًا'),
                    helper: const Text('يظهر ضمن القرارات والتنبيهات قبل الخصم'),
                    child: CupertinoSwitch(
                      value: _autoRenews,
                      activeTrackColor: p.accent,
                      onChanged: (value) =>
                          setState(() => _autoRenews = value),
                    ),
                  ),
                  CupertinoFormRow(
                    prefix: const Text('خدمة أساسية'),
                    helper: const Text('لا يقترح التطبيق إلغاءها بسبب انخفاض الاستخدام'),
                    child: CupertinoSwitch(
                      value: _isEssential,
                      activeTrackColor: p.accent,
                      onChanged: (value) =>
                          setState(() => _isEssential = value),
                    ),
                  ),
                  CupertinoTextFormFieldRow(
                    controller: _planName,
                    placeholder: 'اسم الخطة (اختياري)',
                    textAlign: TextAlign.end,
                  ),
                ],
              ),
              if (isEditing)
                CupertinoButton(
                  onPressed: () => Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (_) => PlanComparisonScreen(
                        subscription: widget.existing!,
                      ),
                    ),
                  ),
                  child: const Text('مقارنة خطة بديلة'),
                ),
              const SizedBox(height: 8),
              IosTextField(
                controller: _url,
                label: 'رابط إدارة الاشتراك (اختياري)',
                keyboardType: TextInputType.url,
                textDirection: TextDirection.ltr,
                placeholder: 'https://example.com/account',
              ),
              const SizedBox(height: 14),
              IosTextField(
                controller: _notes,
                label: 'ملاحظات (اختياري)',
                minLines: 2,
                maxLines: 2,
                placeholder: 'مثال: مشترك مع العائلة',
              ),
              if (isEditing) ...[
                const SizedBox(height: 8),
                _CupertinoSwitchRow(
                  value: _paused,
                  onChanged: (v) => setState(() => _paused = v),
                  title: 'إيقاف مؤقت',
                  detail: 'لن يُحتسب في المصروف ولا في التجديدات',
                ),
              ],
              if (_formError != null) ...[
                const SizedBox(height: 12),
                IosStatusNotice(message: _formError!, error: true),
              ],
              const SizedBox(height: 18),
              CupertinoButton.filled(
                onPressed: _save,
                child: Text(isEditing ? 'حفظ التعديلات' : 'إضافة الاشتراك'),
              ),
              if (isEditing) ...[
                const SizedBox(height: 8),
                CupertinoButton(
                  onPressed: _delete,
                  child: Text('حذف هذا الاشتراك', style: TextStyle(color: p.danger)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CupertinoSwitchRow extends StatelessWidget {
  final String title;
  final String detail;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _CupertinoSwitchRow({
    required this.title,
    required this.detail,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: p.text, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(detail, style: TextStyle(color: p.textMuted, fontSize: 12.5)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          CupertinoSwitch(
            value: value,
            activeTrackColor: p.accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
