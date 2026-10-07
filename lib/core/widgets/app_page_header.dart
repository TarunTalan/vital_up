import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/features/auth/presentation/widgets/back_icon.dart';

/// Glass page header — Figma `Header` on track/detail/* and home:
/// translucent fill + bottom hairline, then one row with an optional back
/// button, a "heading 2" title (+ optional subtitle) and an optional
/// trailing action.
///
/// Includes the top safe-area inset, so place it at the top of a page body.
class AppPageHeader extends StatelessWidget {
  final String? title;
  final Widget? titleWidget;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? action;
  final bool showBack;
  final bool blur;

  const AppPageHeader({
    super.key,
    this.title,
    this.titleWidget,
    this.subtitle,
    this.onBack,
    this.action,
    this.showBack = true,
    this.blur = true,
  }) : assert(
         title != null || titleWidget != null,
         'Either title or titleWidget must be provided',
       );

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final canPop = Navigator.of(context).canPop();
    bool isDashboard = false;
    try {
      isDashboard = GoRouterState.of(context).matchedLocation == '/dashboard';
    } catch (_) {}
    final hasBack = showBack && (onBack != null || canPop || !isDashboard);

    Widget header = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: v.glassFill,
        border: Border(bottom: BorderSide(color: v.glassBorder!)),
      ),
      padding: EdgeInsets.only(
        top: context.safePadding.top + AppDimens.space16,
        bottom: AppDimens.space16,
      ),
      child: ResponsiveCenter(
        child: Padding(
          padding: context.pagePadding,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppDimens.space4),
            child: Row(
              children: [
                if (hasBack) ...[
                  BackIcon(
                    onClick: onBack ?? () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      } else {
                        context.goNamed('dashboard');
                      }
                    },
                  ),
                  const SizedBox(width: AppDimens.space12),
                ],
                Expanded(
                  child: titleWidget ??
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (title != null)
                            Text(
                              title!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.headlineMedium,
                            ),
                          if (subtitle != null) ...[
                            const SizedBox(height: AppDimens.space4),
                            Text(
                              subtitle!,
                              style: context.text.bodyMedium
                                  ?.copyWith(color: v.grayText),
                            ),
                          ],
                        ],
                      ),
                ),
                if (action != null) ...[
                  const SizedBox(width: AppDimens.space12),
                  action!,
                ],
              ],
            ),
          ),
        ),
      ),
    );

    if (blur) {
      header = ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: AppDimens.headerBlur / 2,
            sigmaY: AppDimens.headerBlur / 2,
          ),
          child: header,
        ),
      );
    }
    return header;
  }
}

/// Compact title bar — Figma Vita screens (health coach/*): back button on
/// the left and a centred "heading 3" title in one row, drawn straight on
/// the page background (no glass fill or hairline).
///
/// Includes the top safe-area inset, so place it at the top of a page body.
class AppTitleBar extends StatelessWidget {
  final String? title;
  final VoidCallback? onBack;
  final Widget? action;

  const AppTitleBar({super.key, this.title, this.onBack, this.action});

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    bool isDashboard = false;
    try {
      isDashboard = GoRouterState.of(context).matchedLocation == '/dashboard';
    } catch (_) {}
    final hasBack = onBack != null || canPop || !isDashboard;
    // Mirrors the back button so the title stays optically centred.
    const slot = SizedBox.square(dimension: AppDimens.backButtonSize);

    return Padding(
      padding: EdgeInsets.only(
        top: context.safePadding.top + AppDimens.space20,
        bottom: AppDimens.space16,
      ),
      child: ResponsiveCenter(
        child: Padding(
          padding: context.pagePadding,
          child: Row(
            children: [
              if (hasBack)
                BackIcon(
                  onClick: onBack ?? () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    } else {
                      context.goNamed('dashboard');
                    }
                  },
                )
              else
                slot,
              Expanded(
                child: title == null
                    ? const SizedBox.shrink()
                    : Text(
                        title!,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.headlineSmall?.copyWith(
                          color: context.colors.onSurface,
                        ),
                      ),
              ),
              action ?? slot,
            ],
          ),
        ),
      ),
    );
  }
}

/// Circular cyan-glass action button used in headers — Figma 44dp
/// calendar button (rgba(25,195,224,0.13) fill, 0.27 border).
class AppHeaderAction extends StatelessWidget {
  final Widget icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final double size;
  final bool rounded;

  const AppHeaderAction({
    super.key,
    required this.icon,
    this.onTap,
    this.tooltip,
    this.size = AppDimens.headerActionSize,
    this.rounded = true,
  });

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final shape = rounded
        ? RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusButton),
            side: BorderSide(color: v.primaryBorder!),
          )
        : CircleBorder(side: BorderSide(color: v.primaryBorder!));

    final button = SizedBox.square(
      dimension: size,
      child: Material(
        color: v.primaryFill,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: IconTheme(
            data: IconThemeData(
              color: context.colors.primary,
              size: AppDimens.iconLg,
            ),
            child: Center(child: icon),
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
