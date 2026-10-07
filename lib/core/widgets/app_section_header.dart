import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';

/// Uppercase grey heading above a group of cards on a scrolling page, with
/// an optional count and a trailing link ("See all >"). Shared by Home,
/// Arena, Challenges and Friends so every section reads the same.
class AppSectionHeader extends StatelessWidget {
  final String title;
  final int? count;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppSectionHeader(
    this.title, {
    super.key,
    this.count,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final label = count == null ? title : '$title ($count)';
    return Padding(
      padding: const EdgeInsets.only(
        bottom: AppDimens.space12,
        left: AppDimens.space4,
        top: AppDimens.space8,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: context.vColors.grayText,
              ),
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.space8,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(actionLabel!),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: AppDimens.iconMd,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
