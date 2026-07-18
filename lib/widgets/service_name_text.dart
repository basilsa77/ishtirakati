import 'package:flutter/widgets.dart';

final RegExp _latinStrongCharacter = RegExp(r'[A-Za-z\u00C0-\u02AF]');
final RegExp _rtlStrongCharacter = RegExp(
  r'[\u0590-\u08FF\uFB1D-\uFDFF\uFE70-\uFEFC]',
);

/// Resolves only the visual direction of a service name.
///
/// The stored value is never changed. Leading emoji, punctuation, and digits
/// are ignored so an English name inside an Arabic row still truncates at its
/// visual end instead of showing a leading ellipsis.
TextDirection serviceNameTextDirection(
  String name,
  TextDirection ambientDirection,
) {
  final latin = _latinStrongCharacter.firstMatch(name);
  final rtl = _rtlStrongCharacter.firstMatch(name);

  if (latin == null && rtl == null) return ambientDirection;
  if (latin == null) return TextDirection.rtl;
  if (rtl == null) return TextDirection.ltr;
  return latin.start < rtl.start ? TextDirection.ltr : TextDirection.rtl;
}

/// A display-only service-name label with bidi isolation and trailing
/// ellipsis that follows the name's own writing direction.
class ServiceNameText extends StatelessWidget {
  final String name;
  final TextStyle? style;
  final int maxLines;
  final TextAlign? textAlign;
  final String? semanticsLabel;

  const ServiceNameText({
    super.key,
    required this.name,
    this.style,
    this.maxLines = 1,
    this.textAlign,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final ambientDirection = Directionality.of(context);
    final direction = serviceNameTextDirection(name, ambientDirection);
    return Text(
      name,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      textDirection: direction,
      textAlign:
          textAlign ??
          (ambientDirection == TextDirection.rtl
              ? TextAlign.right
              : TextAlign.left),
      semanticsLabel: semanticsLabel,
      style: style,
    );
  }
}
