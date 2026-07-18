import 'package:flutter/cupertino.dart';

import '../l10n/app_localizations.dart';
import '../theme.dart';

class PotentialDuplicateBadge extends StatelessWidget {
  final VoidCallback onTap;

  const PotentialDuplicateBadge({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final label = tr('v17PossibleDuplicate');
    return Semantics(
      button: true,
      label: tr('v17ReviewDuplicate'),
      child: CupertinoButton(
        minimumSize: const Size(44, 44),
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: Container(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: V16Space.xs,
            vertical: V16Space.xxs,
          ),
          decoration: BoxDecoration(
            color: palette.warningSoft,
            borderRadius: BorderRadius.circular(V16Radius.pill),
            border: Border.all(color: palette.warning.withValues(alpha: .42)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.exclamationmark_triangle_fill,
                color: palette.warning,
                size: V16Type.caption,
              ),
              const SizedBox(width: V16Space.xxs),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.warning,
                  fontSize: V16Type.captionSmall,
                  fontWeight: V16Type.semibold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
