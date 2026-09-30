import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';

/// Circular back button — Figma `button/ ArrowLeft`:
/// 48dp circle, translucent white fill, "shadow black y", 24dp arrow.
class BackIcon extends StatelessWidget {
  final VoidCallback onClick;
  final IconData icon;

  const BackIcon({
    super.key,
    required this.onClick,
    this.icon = Icons.arrow_back_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: MaterialLocalizations.of(context).backButtonTooltip,
      child: Container(
        width: AppDimens.backButtonSize,
        height: AppDimens.backButtonSize,
        decoration: BoxDecoration(
          color: context.vColors.backButtonFill,
          shape: BoxShape.circle,
          boxShadow: AppShadows.shadowY,
        ),
        child: Material(
          type: MaterialType.transparency,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onClick,
            child: Icon(
              icon,
              size: AppDimens.iconLg,
              color: context.colors.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
