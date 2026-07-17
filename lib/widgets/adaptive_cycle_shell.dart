import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
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
              Padding(
                padding: const EdgeInsets.all(V16Space.md),
                child: SafeArea(
                  right: false,
                  child: _CycleRail(
                    destination: destination,
                    onDestination: _select,
                    onCommands:
                        () => showV12CommandPalette(
                          context,
                          onDestination: _select,
                        ),
                  ),
                ),
              ),
              Expanded(child: page),
            ],
          );
        }
        return Column(
          children: [
            Expanded(child: RepaintBoundary(child: page)),
            _IOSBottomBar(destination: destination, onDestination: _select),
          ],
        );
      },
    );
  }
}

const _primaryDestinations = V12Destination.values;

class _IOSBottomBar extends StatelessWidget {
  final V12Destination destination;
  final ValueChanged<V12Destination> onDestination;

  const _IOSBottomBar({required this.destination, required this.onDestination});

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    minimum: const EdgeInsets.fromLTRB(
      V16Space.sm,
      V16Space.xxs,
      V16Space.sm,
      V16Space.xs,
    ),
    child: RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(V16Radius.signature),
          boxShadow: context.palette.cardShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(V16Radius.signature),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: CupertinoTabBar(
              key: const ValueKey('ios-tab-bar'),
              currentIndex: destination.index,
              onTap: (index) => onDestination(_primaryDestinations[index]),
              activeColor: context.palette.accent,
              inactiveColor: context.palette.textMuted,
              backgroundColor: context.palette.surface.withValues(alpha: .92),
              border: Border.all(color: context.palette.stroke),
              items: [
                for (final item in _primaryDestinations)
                  BottomNavigationBarItem(
                    icon: Icon(
                      item.icon,
                      key: ValueKey('v12-dock-${item.name}'),
                    ),
                    activeIcon: Icon(item.selectedIcon),
                    label: item.shortLabel(context),
                  ),
              ],
            ),
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
  Widget build(BuildContext context) => Container(
    width: 244,
    padding: const EdgeInsets.all(V16Space.md),
    decoration: BoxDecoration(
      color: context.palette.surface,
      borderRadius: BorderRadius.circular(V16Radius.signature),
      border: Border.all(color: context.palette.stroke),
      boxShadow: context.palette.cardShadow,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(V16Space.xs),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: context.palette.heroGradient,
                  borderRadius: BorderRadius.circular(V16Radius.compact),
                ),
                child: const Icon(
                  CupertinoIcons.waveform_path_ecg,
                  color: V16Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: V16Space.sm),
              Expanded(
                child: Text(
                  context.l10n.text('appTitle'),
                  style: TextStyle(
                    color: context.palette.text,
                    fontFamily: V16Type.displayFamily,
                    fontFamilyFallback: V16Type.fallbacks,
                    fontSize: V16Type.title,
                    fontWeight: V16Type.semibold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: V16Space.lg),
        for (final item in V12Destination.values)
          _SidebarButton(
            destination: item,
            selected: destination == item,
            onTap: () => onDestination(item),
          ),
        const Spacer(),
        CupertinoButton(
          onPressed: onCommands,
          padding: const EdgeInsets.symmetric(vertical: V16Space.sm),
          borderRadius: BorderRadius.circular(V16Radius.standard),
          color: context.palette.surfaceAlt,
          child: Row(
            children: [
              const Icon(CupertinoIcons.search, size: 20),
              const SizedBox(width: V16Space.sm),
              Expanded(
                child: Text(
                  context.l10n.text('searchAndCommands'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SidebarButton extends StatelessWidget {
  final V12Destination destination;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarButton({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: V16Space.xs),
    child: CupertinoButton(
      onPressed: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: V16Space.sm,
        vertical: V16Space.sm,
      ),
      color: selected ? context.palette.accentSoft : null,
      borderRadius: BorderRadius.circular(V16Radius.standard),
      child: Row(
        children: [
          Icon(
            selected ? destination.selectedIcon : destination.icon,
            color:
                selected ? context.palette.accent : context.palette.textMuted,
          ),
          const SizedBox(width: V16Space.sm),
          Expanded(
            child: Text(
              destination.label(context),
              style: TextStyle(
                color: selected ? context.palette.accent : context.palette.text,
                fontWeight: selected ? V16Type.semibold : V16Type.regular,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
