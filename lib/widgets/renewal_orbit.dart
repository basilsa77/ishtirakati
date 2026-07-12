import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/design_tokens.dart';
import '../models/subscription.dart';
import '../theme.dart';

class RenewalOrbit extends StatelessWidget {
  final List<Subscription> subscriptions;
  final double annualCost;
  final String currency;
  final DateTime? now;

  const RenewalOrbit({
    super.key,
    required this.subscriptions,
    required this.annualCost,
    required this.currency,
    this.now,
  });

  @override
  Widget build(BuildContext context) {
    final visible = subscriptions.take(8).toList();
    final label = visible.isEmpty
        ? 'لا توجد تجديدات نشطة'
        : 'مدار التجديد: ${visible.length} خدمات ظاهرة، '
            'والالتزام السنوي ${fmtMoney(annualCost, currency)}';
    final orbit = AspectRatio(
      aspectRatio: 1,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _RenewalOrbitPainter(
                subscriptions: visible,
                stroke: context.palette.stroke,
                pulse: context.palette.accent,
                warning: context.palette.warning,
                danger: context.palette.danger,
                now: now ?? DateTime.now(),
              ),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'التزامك السنوي',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.palette.textMuted,
                    fontSize: V12Type.caption,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: V12Space.xs),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    fmtMoney(annualCost, currency),
                    maxLines: 1,
                    style: TextStyle(
                      color: context.palette.text,
                      fontFamily: V12Type.displayFamily,
                      fontFamilyFallback: V12Type.fallbacks,
                      fontSize: V12Type.headline,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: V12Space.xxs),
                Text(
                  '${visible.length} نبضات قادمة',
                  style: TextStyle(
                    color: context.palette.accent,
                    fontSize: V12Type.caption,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Semantics(
      label: label,
      image: true,
      child: ExcludeSemantics(
        child: reduceMotion(context)
            ? orbit
            : TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.96, end: 1),
                duration: V12Motion.entrance,
                curve: V12Motion.curve,
                builder: (context, value, child) => Transform.scale(
                  scale: value,
                  child: Opacity(
                    opacity: ((value - 0.96) / 0.04).clamp(0, 1),
                    child: child,
                  ),
                ),
                child: orbit,
              ),
      ),
    );
  }
}

class _RenewalOrbitPainter extends CustomPainter {
  final List<Subscription> subscriptions;
  final Color stroke;
  final Color pulse;
  final Color warning;
  final Color danger;
  final DateTime now;

  const _RenewalOrbitPainter({
    required this.subscriptions,
    required this.stroke,
    required this.pulse,
    required this.warning,
    required this.danger,
    required this.now,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final base = math.min(size.width, size.height) / 2;
    final outer = base - 16;
    final ringPaint = Paint()
      ..color = stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, outer, ringPaint);
    canvas.drawCircle(center, outer * 0.72, ringPaint);
    canvas.drawCircle(center, outer * 0.44, ringPaint);

    final yearStart = DateTime(now.year);
    final yearDays = DateTime(now.year + 1).difference(yearStart).inDays;
    final nowProgress = now.difference(yearStart).inDays / yearDays;
    _drawTick(canvas, center, outer, nowProgress, pulse, 3);

    for (var i = 0; i < subscriptions.length; i++) {
      final item = subscriptions[i];
      final renewal = item.nextRenewal(now);
      final targetYear = renewal.year == now.year
          ? renewal
          : DateTime(now.year, renewal.month, renewal.day);
      final progress =
          targetYear.difference(yearStart).inDays.clamp(0, yearDays) / yearDays;
      final angle = progress * math.pi * 2 - math.pi / 2;
      final radius = outer * (0.56 + (i % 3) * 0.14);
      final point = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      final days = item.daysUntilRenewal(now);
      final color = days <= 3 ? danger : (days <= 10 ? warning : pulse);
      final annualScale = math.sqrt(item.yearlyCost.clamp(0, 10000) / 10000);
      final nodeRadius = 5 + annualScale * 7;
      canvas.drawCircle(
        point,
        nodeRadius + 3,
        Paint()..color = color.withValues(alpha: 0.16),
      );
      canvas.drawCircle(point, nodeRadius, Paint()..color = color);
    }
  }

  void _drawTick(
    Canvas canvas,
    Offset center,
    double radius,
    double progress,
    Color color,
    double width,
  ) {
    final angle = progress * math.pi * 2 - math.pi / 2;
    final vector = Offset(math.cos(angle), math.sin(angle));
    canvas.drawLine(
      center + vector * (radius - 8),
      center + vector * (radius + 5),
      Paint()
        ..color = color
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RenewalOrbitPainter oldDelegate) =>
      oldDelegate.subscriptions != subscriptions ||
      oldDelegate.stroke != stroke ||
      oldDelegate.pulse != pulse ||
      oldDelegate.warning != warning ||
      oldDelegate.danger != danger ||
      oldDelegate.now != now;
}
