import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/design_tokens.dart';
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
            Expanded(
              child: RepaintBoundary(child: page),
            ),
            _IOSBottomBar(
              destination: destination,
              onDestination: _select,
            ),
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

  const _IOSBottomBar({
    required this.destination,
    required this.onDestination,
  });

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: CupertinoTabBar(
              key: const ValueKey('ios-tab-bar'),
              currentIndex: destination.index,
              onTap: (index) => onDestination(_primaryDestinations[index]),
              activeColor: context.palette.accent,
              inactiveColor: context.palette.textMuted,
              backgroundColor: context.palette.surface.withValues(alpha: .96),
              border: Border(top: BorderSide(color: context.palette.stroke)),
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
        width: 224,
        child: Padding(
          padding: const EdgeInsets.all(V12Space.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(V12Space.xs),
                child: Text(
                  context.l10n.text('appTitle'),
                  style: TextStyle(
                    color: context.palette.text,
                    fontFamily: V15Type.displayFamily,
                    fontFamilyFallback: V15Type.fallbacks,
                    fontSize: V15Type.title,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: V12Space.lg),
              for (final item in V12Destination.values)
                _SidebarButton(
                  destination: item,
                  selected: destination == item,
                  onTap: () => onDestination(item),
                ),
              const Spacer(),
              CupertinoButton(
                onPressed: onCommands,
                padding: const EdgeInsets.symmetric(vertical: V12Space.sm),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.search, size: 20),
                    const SizedBox(width: V12Space.sm),
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
        padding: const EdgeInsets.only(bottom: V12Space.xs),
        child: CupertinoButton(
          onPressed: onTap,
          padding: const EdgeInsets.symmetric(
            horizontal: V12Space.sm,
            vertical: V12Space.sm,
          ),
          color: selected ? context.palette.accentSoft : null,
          borderRadius: BorderRadius.circular(V12Radius.standard),
          child: Row(
            children: [
              Icon(
                selected ? destination.selectedIcon : destination.icon,
                color: selected
                    ? context.palette.accent
                    : context.palette.textMuted,
              ),
              const SizedBox(width: V12Space.sm),
              Expanded(
                child: Text(
                  destination.label(context),
                  style: TextStyle(
                    color: selected
                        ? context.palette.accent
                        : context.palette.text,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
