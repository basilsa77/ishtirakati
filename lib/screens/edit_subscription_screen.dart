/// إضافة أو تعديل اشتراك، مع مُلقِّم سريع من الخدمات الشائعة خليجيًا.
library;

import 'package:flutter/material.dart';

import '../data/presets.dart';
import '../models/subscription.dart';
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

  late String _emoji;
  late String _currency;
  late BillingCycle _cycle;
  late DateTime _anchor;
  late String _category;
  late bool _paused;

  bool get isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _price = TextEditingController(
      text: e == null ? '' : e.price.toString(),
    );
    _notes = TextEditingController(text: e?.notes ?? '');
    _emoji = e?.emoji ?? '🔖';
    _currency = e?.currency ?? SubscriptionStore.instance.defaultCurrency;
    _cycle = e?.cycle ?? BillingCycle.monthly;
    _anchor = e?.anchorDate ?? DateTime.now();
    _category = e?.category ?? 'أخرى';
    _paused = e?.isPaused ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _applyPreset(ServicePreset p) {
    setState(() {
      _name.text = p.name;
      _emoji = p.emoji;
      _category = p.category;
    });
  }

  Future<void> _openPresetPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bg,
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
                      for (final p in kPresets)
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
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border:
                                  Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              '${p.emoji} ${p.name}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
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

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              if (!isEditing)
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
                      decoration: const InputDecoration(
                        labelText: 'اسم الاشتراك *',
                        hintText: 'مثال: شاهد VIP',
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
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        color: _cycle == c ? Colors.white : AppColors.ink,
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
                    '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}',
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
                    style: TextStyle(fontWeight: FontWeight.w800),
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
