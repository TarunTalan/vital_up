import 'package:flutter/material.dart';

/// Shows a dialog with a custom, premium scale and fade transition.
///
/// The dialog scales up slightly from 92% to 100% using [Curves.easeOutBack]
/// for a subtle, organic bouncy effect, while fading in.
Future<T?> showSmoothDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  String? barrierLabel,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.54),
    barrierLabel: barrierLabel ?? 'Dismiss',
    pageBuilder: (context, animation, secondaryAnimation) {
      return builder(context);
    },
    transitionDuration: const Duration(milliseconds: 320),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final scale = Tween<double>(begin: 0.92, end: 1.0).animate(
        CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        ),
      );
      final opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        ),
      );
      return FadeTransition(
        opacity: opacity,
        child: ScaleTransition(
          scale: scale,
          child: child,
        ),
      );
    },
  );
}

/// Helper method to show a beautiful, consistent floating SnackBar.
///
/// Automatically clears existing snackbars and displays the new one with
/// a consistent padding, behavior, rounded corners, and icon indicator.
void showSmoothSnackBar(
  BuildContext context, {
  required String message,
  required Color iconColor,
  IconData icon = Icons.info_outline_rounded,
  Duration duration = const Duration(seconds: 4),
}) {
  if (!context.mounted) return;
  
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      duration: duration,
      margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      content: Row(
        children: [
          Icon(
            icon,
            color: iconColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message),
          ),
        ],
      ),
    ),
  );
}

/// Show a consistent success snackbar with the cyan primary theme color.
void showSuccessSnackBar(BuildContext context, String message) {
  showSmoothSnackBar(
    context,
    message: message,
    iconColor: const Color(0xFF19C3E0),
    icon: Icons.check_circle_outline_rounded,
  );
}

/// Show a consistent error snackbar with the red error theme color.
void showErrorSnackBar(BuildContext context, String message) {
  showSmoothSnackBar(
    context,
    message: message,
    iconColor: const Color(0xFFC33E36),
    icon: Icons.error_outline_rounded,
  );
}
