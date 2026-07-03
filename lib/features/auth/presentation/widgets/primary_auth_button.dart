import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';

/// Primary CTA button — cyan background, dark text (Figma: #19C3E0 bg, #0C0C0C text).
/// Loading state: keeps the same background, shows spinner, blocks interaction.
/// Disabled state (enabled=false): keeps background but reduces opacity to 0.5.
class PrimaryAuthButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final bool enabled;
  final VoidCallback onTap;
  final Color? containerColor;
  final Color? contentColor;
  final Color? borderColor;

  const PrimaryAuthButton({
    super.key,
    required this.label,
    required this.isLoading,
    this.enabled = true,
    required this.onTap,
    this.containerColor,
    this.contentColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final vColors = Theme.of(context).extension<VitalUpColors>();

    final bgColor = containerColor ?? colors.primary;
    final fgColor =
        contentColor ?? vColors?.buttonText ?? AppTheme.lightCustomColors.buttonText!;
    final bdColor = borderColor ?? bgColor;

    // Button is always "active" visually — we block interaction via AbsorbPointer.
    // Disabled state (enabled=false, not loading) gets 0.5 opacity.
    final canTap = enabled && !isLoading;
    final opacity = (!enabled && !isLoading) ? 0.5 : 1.0;

    return Opacity(
      opacity: opacity,
      child: AbsorbPointer(
        absorbing: !canTap,
        child: SizedBox(
          width: double.infinity,
          height: AppTheme.buttonHeight,
          child: ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: bgColor,
              foregroundColor: fgColor,
              disabledBackgroundColor: bgColor, // never triggered but kept as safety
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                side: BorderSide(
                  color: bdColor,
                  width: AppTheme.borderWidthDefault,
                ),
              ),
            ),
            child: isLoading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(fgColor),
                    ),
                  )
                : Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: fgColor,
                        ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Secondary / ghost button — white background, teal text/border.
/// Used for "Resend OTP", "Back to Login" alternative actions.
/// Loading/disabled state: keeps same background & border, reduces opacity.
class SecondaryAuthButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final bool enabled;
  final VoidCallback onTap;
  final Color? disabledTextColor;

  const SecondaryAuthButton({
    super.key,
    required this.label,
    required this.onTap,
    this.isLoading = false,
    this.enabled = true,
    this.disabledTextColor,
  });

  @override
  Widget build(BuildContext context) {
    final vColors = Theme.of(context).extension<VitalUpColors>();

    final bgColor =
        vColors?.secondaryButtonBg ?? AppTheme.lightCustomColors.secondaryButtonBg!;
    final fgColor =
        vColors?.secondaryButtonText ?? AppTheme.lightCustomColors.secondaryButtonText!;

    final canTap = enabled && !isLoading;
    // Disabled during countdown or loading: show at 0.5 opacity
    final opacity = canTap ? 1.0 : 0.5;

    return Opacity(
      opacity: opacity,
      child: AbsorbPointer(
        absorbing: !canTap,
        child: SizedBox(
          width: double.infinity,
          height: AppTheme.buttonHeight,
          child: OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              backgroundColor: bgColor,
              foregroundColor: fgColor,
              elevation: 0,
              side: BorderSide(
                color: fgColor.withValues(alpha: 0.5),
                width: AppTheme.borderWidthDefault,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
              ),
            ),
            child: isLoading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(fgColor),
                    ),
                  )
                : Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: disabledTextColor != null && !canTap
                              ? disabledTextColor
                              : fgColor,
                        ),
                  ),
          ),
        ),
      ),
    );
  }
}
