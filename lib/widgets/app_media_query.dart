import 'package:flutter/widgets.dart';

/// Keeps dense financial screens usable with iOS accessibility text enabled.
/// Body text still grows up to 140%; VoiceOver semantics remain unchanged.
class AppMediaQuery extends StatelessWidget {
  final Widget child;

  const AppMediaQuery({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        textScaler: media.textScaler.clamp(
          minScaleFactor: 1,
          maxScaleFactor: 1.4,
        ),
      ),
      child: child,
    );
  }
}
