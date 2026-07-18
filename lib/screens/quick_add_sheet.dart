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
      _price.text
          .trim()
          .replaceAll(tr('ui_bc4d631526af'), '.')
          .replaceAll(',', '.'),
    );
    if (name.isEmpty || price == null || price <= 0) {
      setState(
        () =>
            _validationMessage =
                name.isEmpty ? tr('ui_8836a5db4038') : tr('ui_881dedd25de1'),
      );
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
    await SubscriptionStore.instance.upsert(
      Subscription(
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
      ),
    );
    await HapticFeedback.mediumImpact();
    if (mounted) Navigator.pop(context);
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
                          controller: _name,
                          label: tr('ui_8999278851b9'),
                          autofocus: true,
                          textInputAction: TextInputAction.next,
                          placeholder: tr('ui_c964408c2817'),
                        ),
                        const SizedBox(height: V16Space.sm),
                        IosTextField(
                          controller: _price,
                          label: tr('ui_0d049d3998af'),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          placeholder: '0.00',
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
                          child: CupertinoSlidingSegmentedControl<BillingCycle>(
                            groupValue: _cycle,
                            backgroundColor: p.surface,
                            thumbColor: p.accentStrong,
                            children: {
                              BillingCycle.weekly: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: V16Space.xs,
                                ),
                                child: Text(
                                  tr('ui_e16e5870ecd8'),
                                  style: TextStyle(
                                    color:
                                        _cycle == BillingCycle.weekly
                                            ? V16Colors.white
                                            : p.text,
                                    fontSize: V16Type.labelSmall,
                                    fontWeight: V16Type.semibold,
                                  ),
                                ),
                              ),
                              BillingCycle.monthly: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: V16Space.xs,
                                ),
                                child: Text(
                                  tr('ui_9c677bb93912'),
                                  style: TextStyle(
                                    color:
                                        _cycle == BillingCycle.monthly
                                            ? V16Colors.white
                                            : p.text,
                                    fontSize: V16Type.labelSmall,
                                    fontWeight: V16Type.semibold,
                                  ),
                                ),
                              ),
                              BillingCycle.quarterly: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: V16Space.xs,
                                ),
                                child: Text(
                                  localizedBillingCycle(
                                    BillingCycle.quarterly.name,
                                  ),
                                  style: TextStyle(
                                    color:
                                        _cycle == BillingCycle.quarterly
                                            ? V16Colors.white
                                            : p.text,
                                    fontSize: V16Type.labelSmall,
                                    fontWeight: V16Type.semibold,
                                  ),
                                ),
                              ),
                              BillingCycle.yearly: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: V16Space.xs,
                                ),
                                child: Text(
                                  tr('ui_1beeff0b0fec'),
                                  style: TextStyle(
                                    color:
                                        _cycle == BillingCycle.yearly
                                            ? V16Colors.white
                                            : p.text,
                                    fontSize: V16Type.labelSmall,
                                    fontWeight: V16Type.semibold,
                                  ),
                                ),
                              ),
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
                  if (_validationMessage != null) ...[
                    const SizedBox(height: V16Space.sm),
                    IosStatusNotice(
                      message: _validationMessage!,
                      tone: IosStatusTone.error,
                    ),
                  ],
                  const SizedBox(height: V16Space.md),
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton.filled(
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
