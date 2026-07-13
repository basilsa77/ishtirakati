import 'package:flutter/cupertino.dart';

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
      _price.text.trim().replaceAll('،', '.').replaceAll(',', '.'),
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
        middle: const Text('مقارنة خطة بديلة'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              widget.subscription.name,
              style: TextStyle(
                color: p.text,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'التكلفة الحالية شهريًا: ${fmtMoney(widget.subscription.monthlyCost, widget.subscription.currency)}',
              style: TextStyle(color: p.textMuted),
            ),
            const SizedBox(height: 24),
            CupertinoTextField(
              controller: _price,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textDirection: TextDirection.ltr,
              placeholder: 'سعر الخطة البديلة',
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
                      child: Text(cycle.labelAr),
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
                'أدخل سعر الخطة البديلة لرؤية الفرق الشهري والسنوي.',
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
                          ? 'الخطة البديلة أوفر'
                          : 'الخطة الحالية أوفر أو مساوية',
                      style: TextStyle(
                        color: comparison.alternativeSavesMoney
                            ? p.accent
                            : p.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _ComparisonLine(
                      label: 'البديلة شهريًا',
                      value: fmtMoney(
                        comparison.alternativeMonthlyCost,
                        widget.subscription.currency,
                      ),
                    ),
                    _ComparisonLine(
                      label: comparison.alternativeSavesMoney
                          ? 'التوفير السنوي'
                          : 'الزيادة السنوية',
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
