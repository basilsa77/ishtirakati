import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../design/design_tokens.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';
import 'edit_subscription_screen.dart';
import 'import_screen.dart';

enum V12Destination { home, subscriptions, insights, calendar, settings }

extension V12DestinationX on V12Destination {
  String label(BuildContext context) => switch (this) {
        V12Destination.home => context.l10n.text('navHome'),
        V12Destination.subscriptions =>
          context.l10n.text('navSubscriptionsLibrary'),
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
    builder: (context) => Material(
      color: V12Colors.transparent,
      child: SafeArea(
        top: false,
        child: _CommandPalette(onDestination: onDestination),
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
          Navigator.of(context).push(
            CupertinoPageRoute(builder: (_) => const ImportScreen()),
          );
        },
      ),
    ];
    final normalized = _query.trim().toLowerCase();
    final visible = normalized.isEmpty
        ? commands
        : commands
            .where((item) => item.label.toLowerCase().contains(normalized))
            .toList();

    return FractionallySizedBox(
      heightFactor: 0.78,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.palette.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(V12Radius.signature),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: V12Space.md,
            right: V12Space.md,
            top: V12Space.md,
            bottom: MediaQuery.viewInsetsOf(context).bottom + V12Space.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.palette.stroke,
                    borderRadius: BorderRadius.circular(V12Radius.compact),
                  ),
                ),
              ),
              const SizedBox(height: V12Space.lg),
              Text(
                tr('ui_5b053ac2ac48'),
                style: TextStyle(
                  color: context.palette.text,
                  fontSize: V15Type.title,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: V12Space.sm),
              CupertinoSearchTextField(
                controller: _controller,
                autofocus: true,
                onChanged: (value) => setState(() => _query = value),
                placeholder: tr('ui_53b5e1ce2c0d'),
                backgroundColor: context.palette.surfaceAlt,
              ),
              const SizedBox(height: V12Space.md),
              Expanded(
                child: visible.isEmpty
                    ? Center(
                        child: Text(
                          tr('ui_1d1f8d8d0502'),
                          style: TextStyle(color: context.palette.textMuted),
                        ),
                      )
                    : ListView.separated(
                        itemCount: visible.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          color: context.palette.stroke,
                        ),
                        itemBuilder: (context, index) {
                          final item = visible[index];
                          return CupertinoButton(
                            onPressed: item.onTap,
                            padding: const EdgeInsets.symmetric(
                              horizontal: V12Space.xs,
                              vertical: V12Space.sm,
                            ),
                            child: Row(
                              children: [
                                Icon(item.icon, color: context.palette.accent),
                                const SizedBox(width: V12Space.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.label,
                                        style: TextStyle(
                                          color: context.palette.text,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: V12Space.xxs),
                                      Text(
                                        item.detail,
                                        style: TextStyle(
                                          color: context.palette.textMuted,
                                          fontSize: V15Type.caption,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  CupertinoIcons.chevron_left,
                                  color: context.palette.textMuted,
                                  size: 17,
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
