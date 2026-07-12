import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/design_tokens.dart';
import '../screens/command_palette.dart';
import '../theme.dart';

class AdaptiveCycleShell extends StatelessWidget {
  final V12Destination destination;
  final ValueChanged<V12Destination> onDestination;
  final List<Widget> pages;

  const AdaptiveCycleShell({
    super.key,
    required this.destination,
    required this.onDestination,
    required this.pages,
  });

  void _select(V12Destination value) {
    HapticFeedback.selectionClick();
    onDestination(value);
  }

  @override
  Widget build(BuildContext context) {
    final page = IndexedStack(index: destination.index, children: pages);
    return LayoutBuilder(
      builder: (context, constraints) {
        final tablet = constraints.maxWidth >= 820;
        if (tablet) {
          return Row(
            children: [
              SafeArea(
                right: false,
                child: _CycleRail(
                  destination: destination,
                  onDestination: _select,
                  onCommands: () => showV12CommandPalette(
                    context,
                    onDestination: _select,
                  ),
                ),
              ),
              VerticalDivider(width: 1, color: context.palette.stroke),
              Expanded(child: page),
            ],
          );
        }
        return Column(
          children: [
            Expanded(child: page),
            SafeArea(
              top: false,
              child: _CycleDock(
                destination: destination,
                onDestination: _select,
                onCommands: () => showV12CommandPalette(
                  context,
                  onDestination: _select,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

const _primaryDestinations = [
  V12Destination.home,
  V12Destination.subscriptions,
  V12Destination.insights,
  V12Destination.calendar,
];

class _CycleDock extends StatelessWidget {
  final V12Destination destination;
  final ValueChanged<V12Destination> onDestination;
  final VoidCallback onCommands;

  const _CycleDock({
    required this.destination,
    required this.onDestination,
    required this.onCommands,
  });

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: context.palette.surface,
          border: Border(top: BorderSide(color: context.palette.stroke)),
        ),
        child: SizedBox(
          height: 68,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _DockButton(
                destination: _primaryDestinations[0],
                selected: destination == _primaryDestinations[0],
                onTap: () => onDestination(_primaryDestinations[0]),
              ),
              _DockButton(
                destination: _primaryDestinations[1],
                selected: destination == _primaryDestinations[1],
                onTap: () => onDestination(_primaryDestinations[1]),
              ),
              Tooltip(
                key: const ValueKey('v12-command-button'),
                message: 'بحث وأوامر',
                child: IconButton.filled(
                  onPressed: onCommands,
                  icon: const Icon(Icons.search_rounded),
                  style: IconButton.styleFrom(
                    minimumSize: const Size.square(48),
                    backgroundColor: context.palette.accentStrong,
                    foregroundColor: V12Colors.white,
                    shape: const CircleBorder(),
                  ),
                ),
              ),
              _DockButton(
                destination: _primaryDestinations[2],
                selected: destination == _primaryDestinations[2],
                onTap: () => onDestination(_primaryDestinations[2]),
              ),
              _DockButton(
                destination: _primaryDestinations[3],
                selected: destination == _primaryDestinations[3],
                onTap: () => onDestination(_primaryDestinations[3]),
              ),
            ],
          ),
        ),
      );
}

class _DockButton extends StatelessWidget {
  final V12Destination destination;
  final bool selected;
  final VoidCallback onTap;

  const _DockButton({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: true,
        label: destination.label,
        child: Tooltip(
          key: ValueKey('v12-dock-${destination.name}'),
          message: destination.label,
          child: InkResponse(
            onTap: onTap,
            radius: 28,
            child: SizedBox.square(
              dimension: 52,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    destination.icon,
                    color: selected
                        ? context.palette.accent
                        : context.palette.textMuted,
                  ),
                  const SizedBox(height: V12Space.xxs),
                  AnimatedContainer(
                    duration: V12Motion.quick,
                    width: selected ? 18 : 4,
                    height: 3,
                    decoration: BoxDecoration(
                      color: selected
                          ? context.palette.accent
                          : V12Colors.transparent,
                      borderRadius: BorderRadius.circular(V12Radius.compact),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _CycleRail extends StatelessWidget {
  final V12Destination destination;
  final ValueChanged<V12Destination> onDestination;
  final VoidCallback onCommands;

  const _CycleRail({
    required this.destination,
    required this.onDestination,
    required this.onCommands,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 196,
        child: Padding(
          padding: const EdgeInsets.all(V12Space.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(V12Space.xs),
                child: Text(
                  'اشتراكاتي',
                  style: TextStyle(
                    color: context.palette.text,
                    fontFamily: V12Type.displayFamily,
                    fontFamilyFallback: V12Type.fallbacks,
                    fontSize: V12Type.title,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: V12Space.lg),
              for (final item in V12Destination.values)
                _RailButton(
                  destination: item,
                  selected: destination == item,
                  onTap: () => onDestination(item),
                ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: onCommands,
                icon: const Icon(Icons.search_rounded),
                label: const Text('بحث وأوامر'),
              ),
            ],
          ),
        ),
      );
}

class _RailButton extends StatelessWidget {
  final V12Destination destination;
  final bool selected;
  final VoidCallback onTap;

  const _RailButton({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: V12Space.xs),
        child: ListTile(
          minTileHeight: 48,
          selected: selected,
          selectedColor: context.palette.accent,
          selectedTileColor: context.palette.accentSoft,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(V12Radius.standard),
          ),
          leading: Icon(destination.icon),
          title: Text(destination.label),
          onTap: onTap,
        ),
      );
}
