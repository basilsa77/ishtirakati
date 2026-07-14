import 'package:flutter/cupertino.dart';

import '../l10n/app_localizations.dart';
import '../models/subscription.dart';
import '../services/financial_assistant.dart';
import '../theme.dart';

class PlanComparisonScreen extends StatefulWidget {
  final Subscription subscription;

  const PlanComparisonScreen({super.key, required this.subscription});

  @override
  State<PlanComparisonScreen> createState() => _PlanComparisonScreenState();
}

class _PlanComparisonScreenState extends State<PlanComparisonScreen> {
  late final TextEditingController _price;
  BillingCycle _cycle = BillingCycle.monthly;

  @override
  void initState() {
    super.initState();
    _price = TextEditingController();
  }

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final value = double.tryParse(
      _price.text.trim().replaceAll(tr('ui_bc4d631526af'), '.').replaceAll(',', '.'),
    );
    final comparison = value == null || value < 0
        ? null
        : FinancialAssistant.comparePlans(
            widget.subscription,
            alternativePrice: value,
            alternativeCycle: _cycle,
          );
    return CupertinoPageScaffold(
      backgroundColor: p.canvas,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: p.canvas.withValues(alpha: .92),
        border: Border(bottom: BorderSide(color: p.stroke)),
        middle: Text(tr('ui_0cfaa1166988')),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              widget.subscription.name,
              style: TextStyle(
                color: p.text,
                fontSize: V15Type.headline,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              tr('ui_09a4a8360dc9', {'value0': fmtMoney(widget.subscription.monthlyCost, widget.subscription.currency)}),
              style: TextStyle(color: p.textMuted),
            ),
            const SizedBox(height: 24),
            CupertinoTextField(
              controller: _price,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textDirection: TextDirection.ltr,
              placeholder: tr('ui_5bd41e8d6f02'),
              padding: const EdgeInsets.all(14),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: CupertinoSlidingSegmentedControl<BillingCycle>(
                groupValue: _cycle,
                children: {
                  for (final cycle in BillingCycle.values)
                    cycle: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Text(localizedBillingCycle(cycle.name)),
                    ),
                },
                onValueChanged: (value) {
                  if (value != null) setState(() => _cycle = value);
                },
              ),
            ),
            const SizedBox(height: 28),
            if (comparison == null)
              Text(
                tr('ui_2932ce8e4973'),
                style: TextStyle(color: p.textMuted, height: 1.6),
              )
            else
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: p.surface,
                  border: Border.all(color: p.stroke),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comparison.alternativeSavesMoney
                          ? tr('ui_b7a91942463f')
                          : tr('ui_277e297accb2'),
                      style: TextStyle(
                        color: comparison.alternativeSavesMoney
                            ? p.accent
                            : p.text,
                        fontSize: V15Type.titleSmall,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _ComparisonLine(
                      label: tr('ui_62f92392c4f3'),
                      value: fmtMoney(
                        comparison.alternativeMonthlyCost,
                        widget.subscription.currency,
                      ),
                    ),
                    _ComparisonLine(
                      label: comparison.alternativeSavesMoney
                          ? tr('ui_5dddf85ce95f')
                          : tr('ui_7d0266e9df94'),
                      value: fmtMoney(
                        comparison.annualDifference.abs(),
                        widget.subscription.currency,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ComparisonLine extends StatelessWidget {
  final String label;
  final String value;

  const _ComparisonLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Text(label, style: TextStyle(color: context.palette.textMuted)),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                color: context.palette.text,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
}
