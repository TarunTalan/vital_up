import 'package:flutter/material.dart';

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
    
    final finalContainerColor = containerColor ?? colors.primary;
    final finalContentColor = contentColor ?? const Color(0xFF1C1C1C);
    final finalBorderColor = borderColor ?? finalContainerColor;
    final isButtonEnabled = enabled && !isLoading;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: isButtonEnabled ? onTap : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: finalContainerColor,
          foregroundColor: finalContentColor,
          disabledBackgroundColor: colors.outline.withValues(alpha: 0.5),
          disabledForegroundColor: colors.onSurface.withValues(alpha: 0.5),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: isButtonEnabled ? finalBorderColor : colors.outline,
              width: 1.0,
            ),
          ),
        ),
        child: isLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(finalContentColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              )
            : Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: isButtonEnabled ? finalContentColor : colors.onSurface.withValues(alpha: 0.5),
                      fontSize: 15.0,
                      fontWeight: FontWeight.w600,
                    ),
              ),
      ),
    );
  }
}
