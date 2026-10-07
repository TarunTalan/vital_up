import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_section_header.dart';

/// A titled group of [AppListTile]s in one glass card, with hairline
/// dividers between rows. Used by Profile, Account details, Health & body
/// and Settings so every list page reads the same.
class AppListGroup extends StatelessWidget {
  final String? title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final List<Widget> children;

  const AppListGroup({
    super.key,
    this.title,
    this.actionLabel,
    this.onAction,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          AppSectionHeader(
            title!,
            actionLabel: actionLabel,
            onAction: onAction,
          ),
        AppCard(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: AppDimens.space4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Divider(
                    color: context.vColors.divider,
                    height: AppDimens.borderThin,
                    thickness: AppDimens.borderThin,
                    indent: AppDimens.space16 +
                        AppDimens.iconBadge +
                        AppDimens.space12,
                    endIndent: AppDimens.space16,
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One row of an [AppListGroup]: icon badge, title and subtitle, then a
/// [value], a custom [trailing] widget, or a chevron when tappable.
class AppListTile extends StatelessWidget {
  final IconData? icon;
  final String? svgAsset;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  const AppListTile({
    super.key,
    this.icon,
    this.svgAsset,
    this.iconColor,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.destructive = false,
  }) : assert(icon != null || svgAsset != null);

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final error = context.colors.error;
    final accent = destructive ? error : (iconColor ?? context.colors.primary);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.space16,
          vertical: AppDimens.space10,
        ),
        child: Row(
          children: [
            AppIconBadge(
              color: accent,
              icon: svgAsset != null
                  ? SvgPicture.asset(
                      svgAsset!,
                      width: AppDimens.iconMd,
                      height: AppDimens.iconMd,
                      colorFilter: ColorFilter.mode(accent, BlendMode.srcIn),
                    )
                  : Icon(icon),
            ),
            const SizedBox(width: AppDimens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.text.titleSmall?.copyWith(
                      color: destructive ? error : context.colors.onSurface,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppDimens.space2),
                    Text(
                      subtitle!,
                      style: context.text.bodySmall?.copyWith(
                        color: v.grayText,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: AppDimens.space8),
              Text(
                value!,
                style: context.text.bodyMedium?.copyWith(color: v.grayText),
              ),
            ],
            if (trailing != null) ...[
              const SizedBox(width: AppDimens.space8),
              trailing!,
            ] else if (onTap != null) ...[
              const SizedBox(width: AppDimens.space4),
              Icon(
                Icons.chevron_right_rounded,
                color: destructive ? error.withValues(alpha: 0.5) : v.grayText,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
