import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../theme.dart';

Future<T?> showIosPicker<T>({
  required BuildContext context,
  required String title,
  required T selected,
  required List<T> values,
  required String Function(T value) label,
}) {
  HapticFeedback.selectionClick();
  return showCupertinoModalPopup<T>(
    context: context,
    builder: (sheetContext) => CupertinoActionSheet(
      title: Text(title),
      actions: [
        for (final value in values)
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(sheetContext, value),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: value == selected
                      ? Icon(CupertinoIcons.check_mark, size: 18)
                      : null,
                ),
                SizedBox(width: 8),
                Expanded(child: Text(label(value), textAlign: TextAlign.start)),
              ],
            ),
          ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(sheetContext),
        child: Text(tr('ui_9a30dc2a96b8')),
      ),
    ),
  );
}

Future<bool> showIosConfirmation({
  required BuildContext context,
  required String title,
  required String message,
  String? confirmLabel,
  bool destructive = false,
}) async {
  final result = await showCupertinoDialog<bool>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(tr('ui_9a30dc2a96b8')),
        ),
        CupertinoDialogAction(
          isDestructiveAction: destructive,
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(confirmLabel ?? tr('ui_8f7d74ac0eac')),
        ),
      ],
    ),
  );
  return result ?? false;
}

class IosPickerRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onPressed;
  final IconData? icon;

  const IosPickerRow({
    super.key,
    required this.label,
    required this.value,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      label: tr('ui_1e65e8441737', {'value0': label, 'value1': value}),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsetsDirectional.fromSTEB(14, 9, 12, 9),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: p.stroke),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: p.accent, size: 20),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(label, style: TextStyle(color: p.textMuted, fontSize: V15Type.caption)),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: p.text, fontSize: V15Type.bodySmall, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(CupertinoIcons.chevron_left, color: p.textMuted, size: 17),
            ],
          ),
        ),
      ),
    );
  }
}

class IosTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? placeholder;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextDirection? textDirection;
  final bool obscureText;
  final bool autofocus;
  final int minLines;
  final int maxLines;
  final Widget? prefix;
  final Widget? suffix;
  final ValueChanged<String>? onSubmitted;

  const IosTextField({
    super.key,
    required this.controller,
    required this.label,
    this.placeholder,
    this.keyboardType,
    this.textInputAction,
    this.textDirection,
    this.obscureText = false,
    this.autofocus = false,
    this.minLines = 1,
    this.maxLines = 1,
    this.prefix,
    this.suffix,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 3, bottom: 6),
          child: Text(label, style: TextStyle(color: p.textMuted, fontSize: V15Type.labelSmall, fontWeight: FontWeight.w600)),
        ),
        CupertinoTextField(
          controller: controller,
          placeholder: placeholder,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textDirection: textDirection,
          obscureText: obscureText,
          autofocus: autofocus,
          minLines: minLines,
          maxLines: maxLines,
          prefix: prefix,
          suffix: suffix,
          onSubmitted: onSubmitted,
          clearButtonMode: OverlayVisibilityMode.editing,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          style: TextStyle(color: p.text, fontSize: V15Type.body),
          placeholderStyle: TextStyle(color: p.textMuted, fontSize: V15Type.body),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: p.stroke),
          ),
        ),
      ],
    );
  }
}

class IosStatusNotice extends StatelessWidget {
  final String message;
  final bool error;
  final VoidCallback? onRetry;

  const IosStatusNotice({
    super.key,
    required this.message,
    this.error = false,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = error ? p.danger : p.accent;
    final background = error ? p.dangerSoft : p.accentSoft;
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 10, 10),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(error ? CupertinoIcons.exclamationmark_circle : CupertinoIcons.check_mark_circled, color: color, size: 19),
          SizedBox(width: 9),
          Expanded(child: Text(message, style: TextStyle(color: color, fontSize: V15Type.labelSmall, fontWeight: FontWeight.w600))),
          if (onRetry != null)
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size(32, 32),
              onPressed: onRetry,
              child: Text(tr('ui_14d5786f2e64'), style: TextStyle(fontSize: V15Type.labelSmall)),
            ),
        ],
      ),
    );
  }
}
