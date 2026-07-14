import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../models/subscription.dart';
import '../services/subscription_store.dart';
import '../theme.dart';
import '../widgets/ios_controls.dart';
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
  BillingCycle _cycle = BillingCycle.monthly;
  String? _validationMessage;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final price = double.tryParse(
      _price.text.trim().replaceAll(tr('ui_bc4d631526af'), '.').replaceAll(',', '.'),
    );
    if (name.isEmpty || price == null || price <= 0) {
      setState(() => _validationMessage =
          name.isEmpty ? tr('ui_8836a5db4038') : tr('ui_881dedd25de1'));
      return;
    }
    setState(() => _saving = true);
    final now = DateTime.now();
    final renewal = switch (_cycle) {
      BillingCycle.weekly => now.add(const Duration(days: 7)),
      BillingCycle.monthly => Subscription.addMonths(now, 1),
      BillingCycle.quarterly => Subscription.addMonths(now, 3),
      BillingCycle.yearly => Subscription.addMonths(now, 12),
    };
    await SubscriptionStore.instance.upsert(Subscription(
      id: now.microsecondsSinceEpoch.toString(),
      name: name,
      emoji: '🔖',
      price: price,
      currency: SubscriptionStore.instance.defaultCurrency,
      cycle: _cycle,
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
            maxHeight: MediaQuery.sizeOf(context).height - bottom - 20,
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
                 Text(tr('ui_7e7a0c30b825'), style: TextStyle(color: p.text, fontSize: V15Type.title, fontWeight: FontWeight.w800)),
                 const SizedBox(height: 5),
                 Text(tr('ui_a6b46f7b0864'), style: TextStyle(color: p.textMuted, fontSize: V15Type.labelSmall)),
                 const SizedBox(height: 16),
                 IosTextField(
                   controller: _name,
                   label: tr('ui_8999278851b9'),
                   autofocus: true,
                   textInputAction: TextInputAction.next,
                   placeholder: tr('ui_c964408c2817'),
                 ),
                 const SizedBox(height: 12),
                 IosTextField(
                   controller: _price,
                   label: tr('ui_0d049d3998af'),
                   keyboardType: const TextInputType.numberWithOptions(decimal: true),
                   placeholder: '0.00',
                   suffix: Padding(
                     padding: const EdgeInsetsDirectional.only(end: 12),
                     child: Text(
                       currencySymbols[SubscriptionStore.instance.defaultCurrency] ??
                           SubscriptionStore.instance.defaultCurrency,
                       style: TextStyle(color: p.textMuted, fontSize: V15Type.labelSmall),
                     ),
                   ),
                   onSubmitted: (_) => _save(),
                 ),
                 const SizedBox(height: 12),
                 Text(tr('ui_d23a4e4bb3c4'), style: TextStyle(color: p.textMuted, fontSize: V15Type.labelSmall, fontWeight: FontWeight.w600)),
                 const SizedBox(height: 7),
                 SizedBox(
                   width: double.infinity,
                   child: CupertinoSlidingSegmentedControl<BillingCycle>(
                     groupValue: _cycle,
                     children:  {
                       BillingCycle.weekly: Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Text(tr('ui_e16e5870ecd8'))),
                       BillingCycle.monthly: Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Text(tr('ui_9c677bb93912'))),
                       BillingCycle.yearly: Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Text(tr('ui_1beeff0b0fec'))),
                     },
                     onValueChanged: (value) {
                       if (value != null) setState(() => _cycle = value);
                     },
                   ),
                 ),
                 if (_validationMessage != null) ...[
                   const SizedBox(height: 10),
                   IosStatusNotice(message: _validationMessage!, error: true),
                 ],
                 const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? tr('ui_dd81b078c15b') : tr('ui_ddfcaf9d0144')),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    onPressed: _openFullForm,
                    child: Text(tr('ui_afd7ecfe6b0d')),
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
