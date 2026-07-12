import 'package:flutter/material.dart';

import '../design/design_tokens.dart';
import '../models/subscription.dart';
import '../services/financial_leakage.dart';
import '../services/subscription_store.dart';
import '../theme.dart';
import '../widgets/renewal_orbit.dart';
import 'edit_subscription_screen.dart';
import 'subscriptions_screen.dart' show showSubscriptionDetails;

class PulseHomeScreen extends StatelessWidget {
  final VoidCallback onOpenCommands;
  final VoidCallback onOpenLibrary;

  const PulseHomeScreen({
    super.key,
    required this.onOpenCommands,
    required this.onOpenLibrary,
  });

  @override
  Widget build(BuildContext context) {
    final store = SubscriptionStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final currency = store.dominantCurrency;
        final leakage = FinancialLeakage.calculate(
          store.items,
          currency: currency,
        );
        final upcoming = store.upcoming(withinDays: 30);
        return CustomScrollView(
          key: const PageStorageKey('v12-pulse-home'),
          slivers: [
            SliverPadding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                V12Space.lg,
                V12Space.md,
                V12Space.lg,
                V12Space.xxl,
              ),
              sliver: SliverList.list(
                children: [
                  _PulseHeader(
                    activeCount: store.active.length,
                    onSearch: onOpenCommands,
                    onAdd: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const EditSubscriptionScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: V12Space.lg),
                  if (store.items.isEmpty)
                    _EmptyPulse(
                      onAdd: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const EditSubscriptionScreen(),
                        ),
                      ),
                    )
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth >= 760) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 6,
                                child: _OrbitSection(
                                  leakage: leakage,
                                  upcoming: upcoming,
                                ),
                              ),
                              const SizedBox(width: V12Space.xl),
                              Expanded(
                                flex: 5,
                                child: _DecisionColumn(
                                  leakage: leakage,
                                  upcoming: upcoming,
                                  onOpenLibrary: onOpenLibrary,
                                ),
                              ),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            _OrbitSection(
                              leakage: leakage,
                              upcoming: upcoming,
                            ),
                            const SizedBox(height: V12Space.xl),
                            _DecisionColumn(
                              leakage: leakage,
                              upcoming: upcoming,
                              onOpenLibrary: onOpenLibrary,
                            ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PulseHeader extends StatelessWidget {
  final int activeCount;
  final VoidCallback onSearch;
  final VoidCallback onAdd;

  const _PulseHeader({
    required this.activeCount,
    required this.onSearch,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'صباح هادئ' : 'مساء واضح';
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: TextStyle(
                  color: context.palette.textMuted,
                  fontSize: V12Type.body,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: V12Space.xxs),
              Text(
                'نبض اشتراكاتك',
                style: TextStyle(
                  color: context.palette.text,
                  fontFamily: V12Type.displayFamily,
                  fontFamilyFallback: V12Type.fallbacks,
                  fontSize: V12Type.headline,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '$activeCount التزامات نشطة',
                style: TextStyle(
                  color: context.palette.textMuted,
                  fontSize: V12Type.caption,
                ),
              ),
            ],
          ),
        ),
        _HeaderAction(
          tooltip: 'بحث وأوامر',
          icon: Icons.search_rounded,
          onTap: onSearch,
        ),
        const SizedBox(width: V12Space.xs),
        _HeaderAction(
          tooltip: 'إضافة اشتراك',
          icon: Icons.add_rounded,
          emphasized: true,
          onTap: onAdd,
        ),
      ],
    );
  }
}

class _HeaderAction extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final bool emphasized;

  const _HeaderAction({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: IconButton.filledTonal(
          onPressed: onTap,
          icon: Icon(icon),
          color: emphasized ? V12Colors.white : context.palette.accent,
          style: IconButton.styleFrom(
            minimumSize: const Size.square(48),
            backgroundColor:
                emphasized ? context.palette.accentStrong : context.palette.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(V12Radius.standard),
              side: BorderSide(color: context.palette.stroke),
            ),
          ),
        ),
      );
}

class _OrbitSection extends StatelessWidget {
  final FinancialLeakageSnapshot leakage;
  final List<Subscription> upcoming;

  const _OrbitSection({required this.leakage, required this.upcoming});

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: context.palette.surface,
          border: Border.all(color: context.palette.stroke),
          borderRadius: BorderRadius.circular(V12Radius.signature),
        ),
        child: Padding(
          padding: const EdgeInsets.all(V12Space.md),
          child: RenewalOrbit(
            subscriptions: upcoming,
            annualCost: leakage.annualCommitment,
            currency: leakage.currency,
          ),
        ),
      );
}

class _DecisionColumn extends StatelessWidget {
  final FinancialLeakageSnapshot leakage;
  final List<Subscription> upcoming;
  final VoidCallback onOpenLibrary;

  const _DecisionColumn({
    required this.leakage,
    required this.upcoming,
    required this.onOpenLibrary,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LeakageBand(snapshot: leakage),
          const SizedBox(height: V12Space.xl),
          _SectionHeading(
            title: 'الخصومات القادمة',
            detail: upcoming.isEmpty
                ? 'لا خصومات خلال 30 يومًا'
                : '${upcoming.length} عمليات خلال 30 يومًا',
            onTap: onOpenLibrary,
          ),
          const SizedBox(height: V12Space.sm),
          if (upcoming.isEmpty)
            const _QuietLine()
          else
            for (final item in upcoming.take(4))
              _RenewalLine(subscription: item),
        ],
      );
}

class _LeakageBand extends StatelessWidget {
  final FinancialLeakageSnapshot snapshot;

  const _LeakageBand({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final ratio = snapshot.leakageRatio;
    return Semantics(
      label: 'التسرّب المحتمل ${fmtMoney(snapshot.unusedAnnualExposure, snapshot.currency)} سنويًا',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.palette.surfaceAlt,
          borderRadius: BorderRadius.circular(V12Radius.standard),
          border: BorderDirectional(
            start: BorderSide(color: context.palette.danger, width: 4),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(V12Space.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.water_drop_outlined,
                      color: context.palette.danger, size: 20),
                  const SizedBox(width: V12Space.xs),
                  Expanded(
                    child: Text(
                      'التسرّب الصامت',
                      style: TextStyle(
                        color: context.palette.text,
                        fontSize: V12Type.emphasized,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${(ratio * 100).round()}٪',
                    style: TextStyle(
                      color: context.palette.danger,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: V12Space.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(V12Radius.compact),
                child: LinearProgressIndicator(
                  minHeight: 7,
                  value: ratio,
                  backgroundColor: context.palette.stroke,
                  valueColor: AlwaysStoppedAnimation(context.palette.danger),
                ),
              ),
              const SizedBox(height: V12Space.sm),
              Text(
                snapshot.unused.isEmpty
                    ? 'كل خدمة نشطة لها استخدام مسجل.'
                    : '${fmtMoney(snapshot.unusedAnnualExposure, snapshot.currency)} سنويًا في ${snapshot.unused.length} خدمات بلا استخدام مسجل.',
                style: TextStyle(
                  color: context.palette.textMuted,
                  fontSize: V12Type.body,
                  height: 1.5,
                ),
              ),
              if (snapshot.mostExpensive case final expensive?) ...[
                const SizedBox(height: V12Space.xs),
                Text(
                  'الأثقل: ${expensive.name} • ${fmtMoney(expensive.yearlyCost, expensive.currency)} سنويًا',
                  style: TextStyle(
                    color: context.palette.text,
                    fontSize: V12Type.caption,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;
  final String detail;
  final VoidCallback onTap;

  const _SectionHeading({
    required this.title,
    required this.detail,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.palette.text,
                    fontSize: V12Type.title,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  detail,
                  style: TextStyle(
                    color: context.palette.textMuted,
                    fontSize: V12Type.caption,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'فتح المكتبة',
            onPressed: onTap,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ],
      );
}

class _RenewalLine extends StatelessWidget {
  final Subscription subscription;

  const _RenewalLine({required this.subscription});

  @override
  Widget build(BuildContext context) {
    final days = subscription.daysUntilRenewal();
    return Semantics(
      button: true,
      label: '${subscription.name} يتجدد بعد $days يوم',
      child: InkWell(
        onTap: () => showSubscriptionDetails(context, subscription),
        borderRadius: BorderRadius.circular(V12Radius.standard),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: V12Space.sm),
          child: Row(
            children: [
              ServiceAvatar(
                name: subscription.name,
                iconUrl: subscription.iconUrl,
                manageUrl: subscription.manageUrl,
                size: 44,
              ),
              const SizedBox(width: V12Space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subscription.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.palette.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      days == 0 ? 'اليوم' : 'بعد $days يوم',
                      style: TextStyle(
                        color: days <= 3
                            ? context.palette.danger
                            : context.palette.textMuted,
                        fontSize: V12Type.caption,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                fmtMoney(subscription.price, subscription.currency),
                style: TextStyle(
                  color: context.palette.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuietLine extends StatelessWidget {
  const _QuietLine();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: V12Space.lg),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline_rounded,
                color: context.palette.accent),
            const SizedBox(width: V12Space.sm),
            Text(
              'الفترة القادمة هادئة',
              style: TextStyle(color: context.palette.textMuted),
            ),
          ],
        ),
      );
}

class _EmptyPulse extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyPulse({required this.onAdd});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: V12Space.xxl),
        child: Column(
          children: [
            Icon(Icons.radar_rounded, size: 72, color: context.palette.accent),
            const SizedBox(height: V12Space.lg),
            Text(
              'مدارك جاهز لأول اشتراك',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.palette.text,
                fontSize: V12Type.title,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: V12Space.xs),
            Text(
              'أضف خدمة واحدة لنرتب موعدها وتكلفتها الحقيقية.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.palette.textMuted),
            ),
            const SizedBox(height: V12Space.lg),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('إضافة اشتراك'),
            ),
          ],
        ),
      );
}

