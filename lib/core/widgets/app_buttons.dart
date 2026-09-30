import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vital_up/core/theme/app_theme.dart';

/// Primary CTA — Figma `button/ pri`:
/// 48h, radius 14, #19C3E0 fill, #0C0C0C "body 16 med" label, 16/12 padding.
/// Full width by default (fills the 16dp page gutter).
///
/// Loading keeps the fill and shows a spinner; disabled drops to 50% opacity.
class AppPrimaryButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final bool enabled;
  final VoidCallback onTap;
  final Color? containerColor;
  final Color? contentColor;
  final Color? borderColor;
  final bool showRightArrow;
  final Widget? leadingIcon;
  final bool expand;

  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.isLoading = false,
    this.enabled = true,
    this.containerColor,
    this.contentColor,
    this.borderColor,
    this.showRightArrow = false,
    this.leadingIcon,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = containerColor ?? context.colors.primary;
    final fgColor = contentColor ?? context.vColors.buttonText!;
    final bdColor = borderColor ?? bgColor;

    return _ButtonShell(
      enabled: enabled,
      isLoading: isLoading,
      expand: expand,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          disabledBackgroundColor: bgColor,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: AppDimens.buttonPadding,
          minimumSize: const Size(0, AppDimens.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusButton),
            side: BorderSide(color: bdColor, width: AppDimens.borderThin),
          ),
        ),
        child: _ButtonContent(
          label: label,
          color: fgColor,
          isLoading: isLoading,
          leadingIcon: leadingIcon,
          showRightArrow: showRightArrow,
        ),
      ),
    );
  }
}

/// Secondary / ghost button — Figma `button/ sec`:
/// 48h, radius 14, transparent fill, #B9B9B9 1px border, #0F7586 label.
class AppSecondaryButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final bool enabled;
  final VoidCallback onTap;
  final Color? disabledTextColor;
  final Color? containerColor;
  final Color? contentColor;
  final Color? borderColor;
  final Widget? leadingIcon;
  final bool showRightArrow;
  final bool expand;

  const AppSecondaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.isLoading = false,
    this.enabled = true,
    this.disabledTextColor,
    this.containerColor,
    this.contentColor,
    this.borderColor,
    this.leadingIcon,
    this.showRightArrow = false,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final bgColor = containerColor ?? v.secondaryButtonBg!;
    final fgColor = contentColor ?? v.secondaryButtonText!;
    final bdColor = borderColor ?? v.secondaryButtonBorder!;
    final canTap = enabled && !isLoading;

    return _ButtonShell(
      enabled: enabled,
      isLoading: isLoading,
      expand: expand,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          elevation: 0,
          padding: AppDimens.buttonPadding,
          minimumSize: const Size(0, AppDimens.buttonHeight),
          side: BorderSide(color: bdColor, width: AppDimens.borderThin),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusButton),
          ),
        ),
        child: _ButtonContent(
          label: label,
          color: disabledTextColor != null && !canTap
              ? disabledTextColor!
              : fgColor,
          isLoading: isLoading,
          leadingIcon: leadingIcon,
          showRightArrow: showRightArrow,
        ),
      ),
    );
  }
}

/// Shared sizing + disabled/loading behaviour for both button variants.
class _ButtonShell extends StatelessWidget {
  final bool enabled;
  final bool isLoading;
  final bool expand;
  final Widget child;

  const _ButtonShell({
    required this.enabled,
    required this.isLoading,
    required this.expand,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final canTap = enabled && !isLoading;
    return AnimatedOpacity(
      duration: AppDurations.fast,
      opacity: canTap || isLoading ? 1.0 : 0.5,
      child: AbsorbPointer(
        absorbing: !canTap,
        child: SizedBox(
          width: expand ? double.infinity : null,
          height: AppDimens.buttonHeight,
          child: child,
        ),
      ),
    );
  }
}

class _ButtonContent extends StatelessWidget {
  final String label;
  final Color color;
  final bool isLoading;
  final Widget? leadingIcon;
  final bool showRightArrow;

  const _ButtonContent({
    required this.label,
    required this.color,
    required this.isLoading,
    required this.leadingIcon,
    required this.showRightArrow,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return SizedBox.square(
        dimension: AppDimens.iconMd,
        child: CircularProgressIndicator(
          strokeWidth: AppDimens.borderThick,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      );
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leadingIcon != null) ...[
            IconTheme(
              data: IconThemeData(color: color, size: AppDimens.iconMd),
              child: leadingIcon!,
            ),
            const SizedBox(width: AppDimens.buttonGap),
          ],
          Text(
            label,
            maxLines: 1,
            style: context.text.labelLarge?.copyWith(color: color),
          ),
          if (showRightArrow) ...[
            const SizedBox(width: AppDimens.buttonGap),
            SvgPicture.asset(
              'assets/icons/right_arrow.svg',
              width: AppDimens.iconXs,
              height: AppDimens.iconXs,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            ),
          ],
        ],
      ),
    );
  }
}
