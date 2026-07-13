import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../models/subscription.dart';
import '../services/subscription_store.dart';
import '../theme.dart';
import 'edit_subscription_screen.dart';

Future<void> showQuickAddSheet(BuildContext context) =>
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => const _QuickAddSheet(),
    );

class _QuickAddSheet extends StatefulWidget {
  const _QuickAddSheet();

  @override
  State<_QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<_QuickAddSheet> {
  final _name = TextEditingController();
  final _price = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final price = double.tryParse(
      _price.text.trim().replaceAll('،', '.').replaceAll(',', '.'),
    );
    if (name.isEmpty || price == null || price < 0) return;
    setState(() => _saving = true);
    final now = DateTime.now();
    final renewal = Subscription.addMonths(now, 1);
    await SubscriptionStore.instance.upsert(Subscription(
      id: now.microsecondsSinceEpoch.toString(),
      name: name,
      emoji: '🔖',
      price: price,
      currency: SubscriptionStore.instance.defaultCurrency,
      cycle: BillingCycle.monthly,
      anchorDate: renewal,
      category: 'أخرى',
      reminderDays: 3,
      autoRenews: true,
    ));
    await HapticFeedback.mediumImpact();
    if (mounted) Navigator.pop(context);
  }

  void _openFullForm() {
    final navigator = Navigator.of(context);
    Navigator.pop(context);
    navigator.push(CupertinoPageRoute(
      builder: (_) => const EditSubscriptionScreen(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxWidth: 620,
            maxHeight: MediaQuery.sizeOf(context).height - bottom - 12,
          ),
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 5,
                    decoration: BoxDecoration(color: p.stroke, borderRadius: BorderRadius.circular(3)),
                  ),
                ),
                const SizedBox(height: 18),
                Text('إضافة سريعة', style: TextStyle(color: p.text, fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text('اشتراك شهري، أول تجديد بعد شهر.', style: TextStyle(color: p.textMuted, fontSize: 12.5)),
                const SizedBox(height: 16),
                CupertinoTextField(
                  controller: _name,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  placeholder: 'اسم الخدمة',
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(13), border: Border.all(color: p.stroke)),
                ),
                const SizedBox(height: 10),
                CupertinoTextField(
                  controller: _price,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  placeholder: 'المبلغ الشهري',
                  suffix: Padding(
                    padding: const EdgeInsetsDirectional.only(end: 12),
                    child: Text(SubscriptionStore.instance.defaultCurrency, style: TextStyle(color: p.textMuted, fontSize: 12)),
                  ),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(13), border: Border.all(color: p.stroke)),
                  onSubmitted: (_) => _save(),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ الاشتراك'),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    onPressed: _openFullForm,
                    child: const Text('إدخال كل التفاصيل'),
                  ),
                ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
