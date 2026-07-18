import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../theme.dart';

/// The shared high-contrast segmented control used by compact iOS forms.
class AppSegmentedControl<T extends Object> extends StatelessWidget {
  final T groupValue;
  final Map<T, String> labels;
  final ValueChanged<T?> onValueChanged;

  const AppSegmentedControl({
    super.key,
    required this.groupValue,
    required this.labels,
    required this.onValueChanged,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return CupertinoSlidingSegmentedControl<T>(
      groupValue: groupValue,
      backgroundColor: p.surfaceAlt,
      thumbColor: p.accentStrong,
      padding: const EdgeInsets.all(V16Space.xxs),
      children: {
        for (final entry in labels.entries)
          entry.key: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: V16Space.sm,
              vertical: V16Space.xs,
            ),
            child: Text(
              entry.value,
              key: ValueKey<String>('app-segment-${entry.key}'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: groupValue == entry.key ? V16Colors.white : p.text,
                fontSize: V16Type.labelSmall,
                fontWeight: V16Type.semibold,
              ),
            ),
          ),
      },
      onValueChanged: onValueChanged,
    );
  }
}

Future<T?> showIosModalSheet<T>({
  required BuildContext context,
  required String title,
  required WidgetBuilder builder,
}) {
  final barrierColor = context.palette.shadow.withValues(alpha: .5);
  HapticFeedback.selectionClick();
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    backgroundColor: V16Colors.transparent,
    barrierColor: barrierColor,
    builder:
        (sheetContext) =>
            _IosModalSheet(title: title, child: builder(sheetContext)),
  );
}

class _IosModalSheet extends StatelessWidget {
  final String title;
  final Widget child;

  const _IosModalSheet({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final palette = context.palette;
    final availableHeight =
        media.size.height - media.viewInsets.bottom - media.padding.top;
    return AnimatedPadding(
      duration: reduceMotion(context) ? Duration.zero : V16Motion.quick,
      curve: V16Motion.standardCurve,
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Material(
          key: const Key('ios-modal-sheet-surface'),
          color: palette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(V16Radius.signature),
            ),
            side: BorderSide(color: palette.stroke),
          ),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: availableHeight * .78),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    V16Space.md,
                    V16Space.sm,
                    V16Space.md,
                    V16Space.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: V16Space.xxs,
                          decoration: BoxDecoration(
                            color: palette.stroke,
                            borderRadius: BorderRadius.circular(V16Radius.pill),
                          ),
                        ),
                      ),
                      const SizedBox(height: V16Space.md),
                      Text(
                        title,
                        style: TextStyle(
                          color: palette.text,
                          fontSize: V16Type.titleSmall,
                          fontWeight: V16Type.semibold,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: palette.stroke),
                Flexible(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
    builder:
        (sheetContext) => CupertinoActionSheet(
          title: Text(title),
          actions: [
            for (final value in values)
              CupertinoActionSheetAction(
                onPressed: () => Navigator.pop(sheetContext, value),
                child: Row(
                  children: [
                    SizedBox(
                      width: V16Space.lg,
                      child:
                          value == selected
                              ? const Icon(CupertinoIcons.check_mark, size: 18)
                              : null,
                    ),
                    const SizedBox(width: V16Space.xs),
                    Expanded(
                      child: Text(label(value), textAlign: TextAlign.start),
                    ),
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
    builder:
        (dialogContext) => CupertinoAlertDialog(
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
          padding: const EdgeInsetsDirectional.fromSTEB(
            V16Space.md,
            V16Space.xs,
            V16Space.sm,
            V16Space.xs,
          ),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(V16Radius.standard),
            border: Border.all(color: p.stroke),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: p.accent, size: 20),
                const SizedBox(width: V16Space.sm),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: p.textMuted,
                        fontSize: V16Type.caption,
                      ),
                    ),
                    const SizedBox(height: V16Space.xxs),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: p.text,
                        fontSize: V16Type.bodySmall,
                        fontWeight: V16Type.semibold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: V16Space.xs),
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
          padding: const EdgeInsetsDirectional.only(
            start: V16Space.xxs,
            bottom: V16Space.xs,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: p.textMuted,
              fontSize: V16Type.labelSmall,
              fontWeight: V16Type.semibold,
            ),
          ),
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
          padding: const EdgeInsets.symmetric(
            horizontal: V16Space.md,
            vertical: V16Space.sm,
          ),
          style: TextStyle(color: p.text, fontSize: V16Type.body),
          placeholderStyle: TextStyle(
            color: p.textMuted,
            fontSize: V16Type.body,
          ),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(V16Radius.standard),
            border: Border.all(color: p.stroke),
          ),
        ),
      ],
    );
  }
}

enum IosStatusTone { info, success, queued, error }

class IosStatusNotice extends StatelessWidget {
  final String message;
  final bool error;
  final IosStatusTone tone;
  final VoidCallback? onRetry;

  const IosStatusNotice({
    super.key,
    required this.message,
    this.error = false,
    this.tone = IosStatusTone.success,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final effectiveTone = error ? IosStatusTone.error : tone;
    final (color, background, icon) = switch (effectiveTone) {
      IosStatusTone.info => (
        p.isDark ? V16Colors.blueNight : V16Colors.blueDeep,
        (p.isDark ? V16Colors.blueNight : V16Colors.blueDeep).withValues(
          alpha: .12,
        ),
        CupertinoIcons.info_circle,
      ),
      IosStatusTone.success => (
        p.accent,
        p.accentSoft,
        CupertinoIcons.check_mark_circled,
      ),
      IosStatusTone.queued => (p.warning, p.warningSoft, CupertinoIcons.clock),
      IosStatusTone.error => (
        p.danger,
        p.dangerSoft,
        CupertinoIcons.exclamationmark_circle,
      ),
    };
    return Semantics(
      liveRegion: true,
      label: message,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsetsDirectional.fromSTEB(
          V16Space.sm,
          V16Space.xs,
          V16Space.xs,
          V16Space.xs,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(V16Radius.standard),
          border: Border.all(color: color.withValues(alpha: .2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 19),
            const SizedBox(width: V16Space.xs),
            Expanded(
              child: ExcludeSemantics(
                child: Text(
                  message,
                  style: TextStyle(
                    color: color,
                    fontSize: V16Type.labelSmall,
                    fontWeight: V16Type.semibold,
                  ),
                ),
              ),
            ),
            if (onRetry != null)
              CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: V16Space.xs,
                  vertical: V16Space.xxs,
                ),
                minimumSize: const Size(32, 32),
                onPressed: onRetry,
                child: Text(
                  tr('ui_14d5786f2e64'),
                  style: const TextStyle(fontSize: V16Type.labelSmall),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
