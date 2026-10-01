import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';

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
    barrierColor: barrierColor ?? AppColors.black.withValues(alpha: 0.54),
    barrierLabel: barrierLabel ?? 'Dismiss',
    pageBuilder: (context, animation, secondaryAnimation) {
      return builder(context);
    },
    transitionDuration: AppDurations.slow,
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
  SnackBarAction? action,
}) {
  if (!context.mounted) return;
  
  ScaffoldMessenger.of(context).clearSnackBars();
  final controller = ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      dismissDirection: DismissDirection.horizontal,
      duration: duration,
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimens.gutter,
        vertical: AppDimens.space16,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.space16,
        vertical: AppDimens.space12,
      ),
      action: action,
      content: Row(
        children: [
          Icon(
            icon,
            color: iconColor,
            size: AppDimens.iconMd,
          ),
          const SizedBox(width: AppDimens.space12),
          Expanded(
            child: Text(message),
          ),
        ],
      ),
    ),
  );

  if (action != null) {
    Future.delayed(duration, () {
      try {
        controller.close();
      } catch (_) {}
    });
  }
}

/// Show a consistent success snackbar with the cyan primary theme color.
void showSuccessSnackBar(BuildContext context, String message, {SnackBarAction? action}) {
  showSmoothSnackBar(
    context,
    message: message,
    iconColor: AppColors.primary,
    icon: Icons.check_circle_outline_rounded,
    action: action,
  );
}

/// Show a consistent error snackbar with the red error theme color.
void showErrorSnackBar(BuildContext context, String message) {
  showSmoothSnackBar(
    context,
    message: message,
    iconColor: AppColors.error,
    icon: Icons.error_outline_rounded,
  );
}

/// Shows a modal bottom sheet with the app-standard look: elevated surface,
/// 24dp top radius, drag handle, keyboard-aware padding, and content capped
/// at 600dp wide on tablets.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool isDismissible = true,
  bool enableDrag = true,
  bool showDragHandle = true,
  bool useSafeArea = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    showDragHandle: showDragHandle,
    useSafeArea: useSafeArea,
    constraints: const BoxConstraints(maxWidth: AppDimens.maxContentWidth),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: builder(sheetContext),
    ),
  );
}
