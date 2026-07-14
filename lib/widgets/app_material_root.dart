import 'package:flutter/material.dart';

/// Establishes the Material text and surface inheritance for every app route.
///
/// [MaterialApp.builder] wraps the Navigator with this widget, so pages opened
/// with either Material or Cupertino routes, as well as overlay entries, inherit
/// the app's body text style instead of Flutter's diagnostic fallback style.
class AppMaterialRoot extends StatelessWidget {
  final Widget child;

  const AppMaterialRoot({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.scaffoldBackgroundColor,
      textStyle: theme.textTheme.bodyMedium,
      child: child,
    );
  }
}
