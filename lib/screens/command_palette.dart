import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme.dart';
import 'edit_subscription_screen.dart';
import 'import_screen.dart';

enum V12Destination { home, subscriptions, insights, calendar, settings }

extension V12DestinationX on V12Destination {
  String label(BuildContext context) => switch (this) {
    V12Destination.home => context.l10n.text('navHome'),
    V12Destination.subscriptions => context.l10n.text(
      'navSubscriptionsLibrary',
    ),
    V12Destination.insights => context.l10n.text('navInsights'),
    V12Destination.calendar => context.l10n.text('navRenewalsSchedule'),
    V12Destination.settings => context.l10n.text('navSettings'),
  };

  String shortLabel(BuildContext context) => switch (this) {
    V12Destination.home => context.l10n.text('navHome'),
    V12Destination.subscriptions => context.l10n.text('navSubscriptions'),
    V12Destination.insights => context.l10n.text('navInsights'),
    V12Destination.calendar => context.l10n.text('navRenewals'),
    V12Destination.settings => context.l10n.text('navSettings'),
  };

  IconData get icon => switch (this) {
    V12Destination.home => CupertinoIcons.house,
    V12Destination.subscriptions => CupertinoIcons.rectangle_stack,
    V12Destination.insights => CupertinoIcons.chart_bar,
    V12Destination.calendar => CupertinoIcons.calendar,
    V12Destination.settings => CupertinoIcons.gear,
  };

  IconData get selectedIcon => switch (this) {
    V12Destination.home => CupertinoIcons.house_fill,
    V12Destination.subscriptions => CupertinoIcons.rectangle_stack_fill,
    V12Destination.insights => CupertinoIcons.chart_bar_fill,
    V12Destination.calendar => CupertinoIcons.calendar_today,
    V12Destination.settings => CupertinoIcons.gear_solid,
  };
}

Future<void> showV12CommandPalette(
  BuildContext context, {
  required ValueChanged<V12Destination> onDestination,
}) async {
  await showCupertinoModalPopup<void>(
    context: context,
    builder:
        (context) => Material(
          color: V16Colors.transparent,
          child: SafeArea(
            top: false,
            child: AnimatedPadding(
              duration: reduceMotion(context) ? Duration.zero : V16Motion.quick,
              curve: V16Motion.standardCurve,
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: _CommandPalette(onDestination: onDestination),
            ),
          ),
        ),
  );
}

class _CommandPalette extends StatefulWidget {
  final ValueChanged<V12Destination> onDestination;

  const _CommandPalette({required this.onDestination});

  @override
  State<_CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<_CommandPalette> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final commands = <_Command>[
      for (final destination in V12Destination.values)
        _Command(
          label: destination.label(context),
          detail: tr('ui_f7424fc7a0ff'),
          icon: destination.icon,
          onTap: () {
            Navigator.pop(context);
            widget.onDestination(destination);
          },
        ),
      _Command(
        label: tr('ui_009aab16265a'),
        detail: tr('ui_8b2c85333b99'),
        icon: Icons.add_circle_outline_rounded,
        onTap: () {
          Navigator.pop(context);
          Navigator.of(context).push(
            CupertinoPageRoute(builder: (_) => const EditSubscriptionScreen()),
          );
        },
      ),
      _Command(
        label: tr('ui_501a5a8897a1'),
        detail: tr('ui_8b2c85333b99'),
        icon: Icons.file_download_outlined,
        onTap: () {
          Navigator.pop(context);
          Navigator.of(
            context,
          ).push(CupertinoPageRoute(builder: (_) => const ImportScreen()));
        },
      ),
    ];
    final normalized = _query.trim().toLowerCase();
    final visible =
        normalized.isEmpty
            ? commands
            : commands
                .where((item) => item.label.toLowerCase().contains(normalized))
                .toList();
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return FractionallySizedBox(
      heightFactor: 0.78,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(V16Radius.signature),
          ),
          border: Border(top: BorderSide(color: palette.stroke)),
          boxShadow: palette.cardShadow,
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            V16Space.md,
            V16Space.md,
            V16Space.md,
            V16Space.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.stroke,
                    borderRadius: BorderRadius.circular(V16Radius.pill),
                  ),
                ),
              ),
              const SizedBox(height: V16Space.lg),
              Text(
                tr('ui_5b053ac2ac48'),
                style: TextStyle(
                  color: palette.text,
                  fontFamily: V16Type.displayFamily,
                  fontFamilyFallback: V16Type.fallbacks,
                  fontSize: V16Type.headlineSmall,
                  height: V16Type.headlineHeight,
                  fontWeight: V16Type.semibold,
                ),
              ),
              const SizedBox(height: V16Space.sm),
              CupertinoSearchTextField(
                key: const Key('command-palette-search'),
                controller: _controller,
                autofocus: true,
                onChanged: (value) => setState(() => _query = value),
                placeholder: tr('ui_53b5e1ce2c0d'),
                backgroundColor: palette.surfaceAlt,
                borderRadius: BorderRadius.circular(V16Radius.standard),
                style: TextStyle(
                  color: palette.text,
                  fontFamily: V16Type.bodyFamily,
                  fontFamilyFallback: V16Type.fallbacks,
                  fontSize: V16Type.body,
                  height: V16Type.bodyHeight,
                ),
                placeholderStyle: TextStyle(
                  color: palette.textMuted,
                  fontFamily: V16Type.bodyFamily,
                  fontFamilyFallback: V16Type.fallbacks,
                  fontSize: V16Type.body,
                  height: V16Type.bodyHeight,
                ),
              ),
              const SizedBox(height: V16Space.md),
              Expanded(
                key: const Key('command-palette-content'),
                child:
                    visible.isEmpty
                        ? Semantics(
                          liveRegion: true,
                          child: Center(
                            child: AppCard(
                              tone: AppCardTone.muted,
                              elevated: false,
                              padding: const EdgeInsets.all(V16Space.lg),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    CupertinoIcons.search,
                                    color: palette.accent,
                                    size: V16Space.xl,
                                  ),
                                  const SizedBox(height: V16Space.sm),
                                  Text(
                                    tr('ui_1d1f8d8d0502'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: palette.textMuted,
                                      fontSize: V16Type.body,
                                      height: V16Type.bodyHeight,
                                      fontWeight: V16Type.semibold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                        : ListView.separated(
                          key: const Key('command-palette-results'),
                          padding: EdgeInsets.zero,
                          primary: false,
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          itemCount: visible.length,
                          separatorBuilder:
                              (_, _) => const SizedBox(height: V16Space.xs),
                          itemBuilder: (context, index) {
                            final item = visible[index];
                            return AppCard(
                              key: ValueKey(item.label),
                              onTap: item.onTap,
                              semanticsLabel: '${item.label}, ${item.detail}',
                              elevated: false,
                              padding: const EdgeInsetsDirectional.fromSTEB(
                                V16Space.sm,
                                V16Space.sm,
                                V16Space.md,
                                V16Space.sm,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    width: V16Space.xxl,
                                    height: V16Space.xxl,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: palette.accentSoft,
                                      borderRadius: BorderRadius.circular(
                                        V16Radius.standard,
                                      ),
                                    ),
                                    child: Icon(
                                      item.icon,
                                      color: palette.accent,
                                      size: V16Space.lg,
                                    ),
                                  ),
                                  const SizedBox(width: V16Space.sm),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.label,
                                          style: TextStyle(
                                            color: palette.text,
                                            fontSize: V16Type.body,
                                            height: V16Type.bodyHeight,
                                            fontWeight: V16Type.semibold,
                                          ),
                                        ),
                                        const SizedBox(height: V16Space.xxs),
                                        Text(
                                          item.detail,
                                          style: TextStyle(
                                            color: palette.textMuted,
                                            fontSize: V16Type.caption,
                                            height: V16Type.captionHeight,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: V16Space.xs),
                                  Icon(
                                    isRtl
                                        ? CupertinoIcons.chevron_left
                                        : CupertinoIcons.chevron_right,
                                    color: palette.textMuted,
                                    size: V16Type.titleSmall,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Command {
  final String label;
  final String detail;
  final IconData icon;
  final VoidCallback onTap;

  const _Command({
    required this.label,
    required this.detail,
    required this.icon,
    required this.onTap,
  });
}
