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
      _price.text
          .trim()
          .replaceAll(tr('ui_bc4d631526af'), '.')
          .replaceAll(',', '.'),
    );
    final comparison =
        value == null || value < 0
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
          padding: const EdgeInsets.all(V16Space.ml),
          children: [
            AppPageIntro(
              title: widget.subscription.name,
              description: tr('ui_09a4a8360dc9', {
                'value0': fmtMoneyWithCurrency(
                  widget.subscription.monthlyCost,
                  widget.subscription.currency,
                ),
              }),
            ),
            const SizedBox(height: V16Space.lg),
            CupertinoTextField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textDirection: TextDirection.ltr,
              placeholder: tr('ui_5bd41e8d6f02'),
              placeholderStyle: TextStyle(
                color: p.textMuted,
                fontSize: V16Type.body,
              ),
              style: TextStyle(
                color: p.text,
                fontSize: V16Type.body,
                fontWeight: V16Type.semibold,
              ),
              padding: const EdgeInsets.all(V16Space.md),
              decoration: BoxDecoration(
                color: p.surface,
                border: Border.all(color: p.stroke),
                borderRadius: BorderRadius.circular(V16Radius.standard),
                boxShadow: p.cardShadow,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: V16Space.md),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: CupertinoSlidingSegmentedControl<BillingCycle>(
                groupValue: _cycle,
                backgroundColor: p.surfaceAlt,
                thumbColor: p.surface,
                children: {
                  for (final cycle in BillingCycle.values)
                    cycle: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: V16Space.sm,
                        vertical: V16Space.xs,
                      ),
                      child: Text(
                        localizedBillingCycle(cycle.name),
                        style: TextStyle(
                          color: p.text,
                          fontSize: V16Type.labelSmall,
                          fontWeight: V16Type.semibold,
                        ),
                      ),
                    ),
                },
                onValueChanged: (value) {
                  if (value != null) setState(() => _cycle = value);
                },
              ),
            ),
            const SizedBox(height: V16Space.xl),
            AnimatedSwitcher(
              duration: reduceMotion(context) ? Duration.zero : V16Motion.quick,
              switchInCurve: V16Motion.standardCurve,
              switchOutCurve: V16Motion.standardCurve,
              child:
                  comparison == null
                      ? AppCard(
                        key: const ValueKey('comparison-empty'),
                        tone: AppCardTone.muted,
                        elevated: false,
                        child: Text(
                          tr('ui_2932ce8e4973'),
                          style: TextStyle(
                            color: p.textMuted,
                            fontSize: V16Type.bodySmall,
                            height: V16Type.bodyHeight,
                          ),
                        ),
                      )
                      : _ComparisonResult(
                        key: ValueKey(
                          '${comparison.alternativeMonthlyCost}-${comparison.annualDifference}',
                        ),
                        comparison: comparison,
                        currency: widget.subscription.currency,
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComparisonResult extends StatelessWidget {
  final PlanComparison comparison;
  final String currency;

  const _ComparisonResult({
    super.key,
    required this.comparison,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final title =
        comparison.alternativeSavesMoney
            ? tr('ui_b7a91942463f')
            : tr('ui_277e297accb2');
    final monthly = fmtMoneyWithCurrency(
      comparison.alternativeMonthlyCost,
      currency,
    );
    final difference = fmtMoneyWithCurrency(
      comparison.annualDifference.abs(),
      currency,
    );
    final differenceLabel =
        comparison.alternativeSavesMoney
            ? tr('ui_5dddf85ce95f')
            : tr('ui_7d0266e9df94');
    return Semantics(
      container: true,
      label:
          '$title. ${tr('ui_62f92392c4f3')}: $monthly. $differenceLabel: $difference',
      child: AppCard(
        borderColor:
            comparison.alternativeSavesMoney
                ? p.accent.withValues(alpha: .35)
                : p.stroke,
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color:
                          comparison.alternativeSavesMoney
                              ? p.accentSoft
                              : p.surfaceAlt,
                      borderRadius: BorderRadius.circular(V16Radius.compact),
                    ),
                    child: Icon(
                      comparison.alternativeSavesMoney
                          ? CupertinoIcons.arrow_down_right
                          : CupertinoIcons.equal,
                      color:
                          comparison.alternativeSavesMoney
                              ? p.accent
                              : p.textMuted,
                    ),
                  ),
                  const SizedBox(width: V16Space.sm),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color:
                            comparison.alternativeSavesMoney
                                ? p.accent
                                : p.text,
                        fontSize: V16Type.titleSmall,
                        fontWeight: V16Type.semibold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: V16Space.lg),
              _ComparisonLine(label: tr('ui_62f92392c4f3'), value: monthly),
              _ComparisonLine(label: differenceLabel, value: difference),
            ],
          ),
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
    padding: const EdgeInsets.only(bottom: V16Space.sm),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.2;
        final labelWidget = Text(
          label,
          style: TextStyle(
            color: context.palette.textMuted,
            fontSize: V16Type.labelSmall,
          ),
        );
        final valueWidget = Text(
          value,
          style: TextStyle(
            color: context.palette.text,
            fontSize: V16Type.label,
            fontWeight: V16Type.semibold,
          ),
        );
        if (largeText || constraints.maxWidth < 300) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              labelWidget,
              const SizedBox(height: V16Space.xxs),
              valueWidget,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: labelWidget),
            const SizedBox(width: V16Space.sm),
            valueWidget,
          ],
        );
      },
    ),
  );
}
