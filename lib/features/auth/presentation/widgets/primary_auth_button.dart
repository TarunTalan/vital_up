import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';

/// Primary CTA button — cyan background, dark text (Figma: #19C3E0 bg, #0C0C0C text).
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
    final fgColor = contentColor ?? vColors?.buttonText ?? AppTheme.lightCustomColors.buttonText!;
    final bdColor = borderColor ?? bgColor;
    final isActive = enabled && !isLoading;

    return SizedBox(
      width: double.infinity,
      height: AppTheme.buttonHeight,
      child: ElevatedButton(
        onPressed: isActive ? onTap : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          disabledBackgroundColor: colors.outline.withValues(alpha: 0.5),
          disabledForegroundColor: colors.onSurface.withValues(alpha: 0.5),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
            side: BorderSide(
              color: isActive ? bdColor : colors.outline,
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
                      color: isActive
                          ? fgColor
                          : colors.onSurface.withValues(alpha: 0.5),
                    ),
              ),
      ),
    );
  }
}

/// Secondary / ghost button — white background, teal text/border.
/// Used for "Resend OTP", "Back to Login" alternative actions.
class SecondaryAuthButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final bool enabled;
  final VoidCallback onTap;

  const SecondaryAuthButton({
    super.key,
    required this.label,
    required this.onTap,
    this.isLoading = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final vColors = Theme.of(context).extension<VitalUpColors>();

    final bgColor = vColors?.secondaryButtonBg ?? AppTheme.lightCustomColors.secondaryButtonBg!;
    final fgColor = vColors?.secondaryButtonText ?? AppTheme.lightCustomColors.secondaryButtonText!;
    final isActive = enabled && !isLoading;

    return SizedBox(
      width: double.infinity,
      height: AppTheme.buttonHeight,
      child: OutlinedButton(
        onPressed: isActive ? onTap : null,
        style: OutlinedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          disabledForegroundColor: colors.onSurface.withValues(alpha: 0.4),
          elevation: 0,
          side: BorderSide(
            color: isActive
                ? fgColor.withValues(alpha: 0.5)
                : colors.outline,
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
                      color: isActive
                          ? fgColor
                          : colors.onSurface.withValues(alpha: 0.4),
                    ),
              ),
      ),
    );
  }
}
