import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';

/// Guards against a double tap opening the same sheet or dialog twice: while
/// a modal opened from a [BuildContext] is still showing, another open from
/// that same context within [_reopenGuard] is ignored (returns null).
/// Opening one after the other, or a nested modal from the sheet's own
/// context, works as usual.
const _reopenGuard = Duration(milliseconds: 500);
final Expando<DateTime> _openSince = Expando<DateTime>('modalOpenSince');

bool _shouldIgnoreOpen(BuildContext context) {
  final now = DateTime.now();
  final since = _openSince[context];
  if (since != null && now.difference(since) < _reopenGuard) return true;
  _openSince[context] = now;
  return false;
}

Future<T?> _trackOpen<T>(BuildContext context, Future<T?> modal) {
  final opened = _openSince[context];
  return modal.whenComplete(() {
    if (identical(_openSince[context], opened)) _openSince[context] = null;
  });
}

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
  if (!context.mounted || _shouldIgnoreOpen(context)) {
    return Future<T?>.value();
  }
  return _trackOpen(
    context,
    showGeneralDialog<T>(
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
          CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        );
        final opacity = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
        return FadeTransition(
          opacity: opacity,
          child: ScaleTransition(scale: scale, child: child),
        );
      },
    ),
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
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  // Never show an empty bubble.
  if (message.trim().isEmpty) message = 'Something went wrong. Try again.';

  messenger.clearSnackBars();
  final controller = messenger.showSnackBar(
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
          Icon(icon, color: iconColor, size: AppDimens.iconMd),
          const SizedBox(width: AppDimens.space12),
          Expanded(child: Text(message)),
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
void showSuccessSnackBar(
  BuildContext context,
  String message, {
  SnackBarAction? action,
}) {
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
  if (!context.mounted || _shouldIgnoreOpen(context)) {
    return Future<T?>.value();
  }
  return _trackOpen(
    context,
    showModalBottomSheet<T>(
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
    ),
  );
}
