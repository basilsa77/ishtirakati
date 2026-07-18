import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../models/subscription.dart';
import '../services/amount_input_parser.dart';
import '../services/subscription_store.dart';
import '../theme.dart';
import '../widgets/ios_controls.dart';
import 'edit_subscription_screen.dart';

Future<void> showQuickAddSheet(
  BuildContext context, {
  SubscriptionSaver? saveSubscription,
}) => showCupertinoModalPopup<void>(
  context: context,
  builder: (_) => _QuickAddSheet(saveSubscription: saveSubscription),
);

class _QuickAddSheet extends StatefulWidget {
  const _QuickAddSheet({this.saveSubscription});

  final SubscriptionSaver? saveSubscription;

  @override
  State<_QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<_QuickAddSheet> {
  final _name = TextEditingController();
  final _price = TextEditingController();
  bool _saving = false;
  BillingCycle _cycle = BillingCycle.monthly;
  String? _nameError;
  String? _amountError;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _name.text.trim();
    final amount = validateAmountInput(_price.text);
    final nameError = name.isEmpty ? tr('ui_8836a5db4038') : null;
    final amountError =
        amount.issue == null ? null : tr(amount.issue!.localizationKey);
    if (nameError != null || amountError != null) {
      setState(() {
        _nameError = nameError;
        _amountError = amountError;
      });
      return;
    }
    setState(() {
      _nameError = null;
      _amountError = null;
      _saving = true;
    });
    final now = DateTime.now();
    final renewal = switch (_cycle) {
      BillingCycle.weekly => now.add(const Duration(days: 7)),
      BillingCycle.monthly => Subscription.addMonths(now, 1),
      BillingCycle.quarterly => Subscription.addMonths(now, 3),
      BillingCycle.yearly => Subscription.addMonths(now, 12),
    };
    final subscription = Subscription(
      id: now.microsecondsSinceEpoch.toString(),
      name: name,
      emoji: '🔖',
      price: amount.value!,
      currency: SubscriptionStore.instance.defaultCurrency,
      cycle: _cycle,
      anchorDate: renewal,
      category: 'أخرى',
      reminderDays: 3,
      autoRenews: true,
    );
    try {
      await (widget.saveSubscription ?? SubscriptionStore.instance.upsert)(
        subscription,
      );
      try {
        await HapticFeedback.mediumImpact();
      } catch (_) {
        // Saving is authoritative; unavailable haptics must not invite a
        // second submission of an already-persisted subscription.
      }
      if (!mounted) return;
      setState(() => _saving = false);
      Navigator.pop(context);
    } finally {
      if (mounted && _saving) setState(() => _saving = false);
    }
  }

  void _openFullForm() {
    final navigator = Navigator.of(context);
    Navigator.pop(context);
    navigator.push(
      CupertinoPageRoute(builder: (_) => const EditSubscriptionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: reduceMotion(context) ? Duration.zero : V16Motion.quick,
      curve: V16Motion.standardCurve,
      padding: EdgeInsets.only(bottom: bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxWidth: 620,
            maxHeight: MediaQuery.sizeOf(context).height - bottom - V16Space.ml,
          ),
          padding: const EdgeInsetsDirectional.fromSTEB(
            V16Space.ml,
            V16Space.xs,
            V16Space.ml,
            V16Space.ml,
          ),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(V16Radius.signature),
            ),
            boxShadow: p.isDark ? V16Elevation.darkLow : V16Elevation.medium,
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
                      decoration: BoxDecoration(
                        color: p.stroke,
                        borderRadius: BorderRadius.circular(V16Radius.pill),
                      ),
                    ),
                  ),
                  const SizedBox(height: V16Space.md),
                  AppPageIntro(
                    title: tr('ui_7e7a0c30b825'),
                    description: tr('ui_a6b46f7b0864'),
                  ),
                  const SizedBox(height: V16Space.md),
                  AppCard(
                    tone: AppCardTone.muted,
                    elevated: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IosTextField(
                          key: const Key('quick-service-name-field'),
                          controller: _name,
                          label: tr('ui_8999278851b9'),
                          autofocus: true,
                          textInputAction: TextInputAction.next,
                          placeholder: tr('ui_c964408c2817'),
                          errorText: _nameError,
                          onChanged: (_) {
                            if (_nameError != null) {
                              setState(() => _nameError = null);
                            }
                          },
                        ),
                        const SizedBox(height: V16Space.sm),
                        IosTextField(
                          key: const Key('quick-amount-field'),
                          controller: _price,
                          label: tr('ui_0d049d3998af'),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          placeholder: '0.00',
                          errorText: _amountError,
                          onChanged: (_) {
                            if (_amountError != null) {
                              setState(() => _amountError = null);
                            }
                          },
                          suffix: Padding(
                            padding: const EdgeInsetsDirectional.only(
                              end: V16Space.sm,
                            ),
                            child: Text(
                              currencySymbols[SubscriptionStore
                                      .instance
                                      .defaultCurrency] ??
                                  SubscriptionStore.instance.defaultCurrency,
                              style: TextStyle(
                                color: p.textMuted,
                                fontSize: V16Type.labelSmall,
                              ),
                            ),
                          ),
                          onSubmitted: (_) => _save(),
                        ),
                        const SizedBox(height: V16Space.sm),
                        Text(
                          tr('ui_d23a4e4bb3c4'),
                          style: TextStyle(
                            color: p.textMuted,
                            fontSize: V16Type.labelSmall,
                            fontWeight: V16Type.semibold,
                          ),
                        ),
                        const SizedBox(height: V16Space.xs),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: AppSegmentedControl<BillingCycle>(
                            key: const Key('quick-add-cycle-segments'),
                            groupValue: _cycle,
                            labels: {
                              BillingCycle.weekly: tr('ui_e16e5870ecd8'),
                              BillingCycle.monthly: tr('ui_9c677bb93912'),
                              BillingCycle.quarterly: localizedBillingCycle(
                                BillingCycle.quarterly.name,
                              ),
                              BillingCycle.yearly: tr('ui_1beeff0b0fec'),
                            },
                            onValueChanged: (value) {
                              if (value != null) {
                                setState(() => _cycle = value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: V16Space.md),
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton.filled(
                      key: const Key('quick-save-button'),
                      onPressed: _saving ? null : _save,
                      borderRadius: BorderRadius.circular(V16Radius.standard),
                      child: Text(
                        _saving ? tr('ui_dd81b078c15b') : tr('ui_ddfcaf9d0144'),
                      ),
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
