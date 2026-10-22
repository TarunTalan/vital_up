import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';

/// Circular back button — Figma `button/ ArrowLeft`: 48dp circle, 24dp
/// arrow. Flat by default (glass fill + hairline, the neutral twin of
/// [AppHeaderAction]); [elevated] = translucent white + "shadow black y",
/// only where it floats over media (the camera).
class BackIcon extends StatelessWidget {
  final VoidCallback onClick;
  final IconData icon;
  final bool elevated;

  const BackIcon({
    super.key,
    required this.onClick,
    this.icon = Icons.arrow_back_rounded,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    return Semantics(
      button: true,
      label: MaterialLocalizations.of(context).backButtonTooltip,
      child: Container(
        width: AppDimens.backButtonSize,
        height: AppDimens.backButtonSize,
        decoration: BoxDecoration(
          color: elevated ? v.backButtonFill : v.glassFill,
          shape: BoxShape.circle,
          border: elevated ? null : Border.all(color: v.glassBorder!),
          boxShadow: elevated ? AppShadows.shadowY : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              FocusManager.instance.primaryFocus?.unfocus();
              onClick();
            },
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
