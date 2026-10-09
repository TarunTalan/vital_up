import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_dimens.dart';

/// Calm stand-in for a widget that failed to build (release builds use it as
/// [ErrorWidget.builder]) and for an app that couldn't start. Never shows
/// the error itself: details go to crash reporting.
///
/// Built defensively: it may render outside the app theme, in tiny or
/// unbounded boxes, so it only reads the base [Theme] and clips itself.
class AppErrorFallback extends StatelessWidget {
  final String message;

  /// Optional action below the message (e.g. "Try again").
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppErrorFallback({
    super.key,
    this.message = "Something went wrong here.",
    this.actionLabel,
    this.onAction,
  });

  /// [ErrorWidget.builder] for release builds.
  static Widget errorWidgetBuilder(FlutterErrorDetails details) =>
      const AppErrorFallback();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Directionality(
      textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
      child: ClipRect(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.space16),
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: AppDimens.iconXl,
                    color: muted,
                  ),
                  const SizedBox(height: AppDimens.space8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: (theme.textTheme.bodyMedium ?? const TextStyle())
                        .copyWith(color: muted, decoration: TextDecoration.none),
                  ),
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(height: AppDimens.space8),
                    TextButton(onPressed: onAction, child: Text(actionLabel!)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
