import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_card.dart';

/// A one-time tip where a feature helps ("Going somewhere without
/// signal?"): icon badge, title, one line of why, the feature's button and
/// "Not now" (or only "Got it" without [actionLabel]). The caller shows it
/// once (`FeatureTipsService.isDismissed`) and hides it after a tap.
///
/// [FeatureTipCard.compact] is one row (icon, message, close) for tight
/// places such as a sheet. [overlay]: over a map or camera, an opaque
/// card so the text stays readable.
class FeatureTipCard extends StatelessWidget {
  final IconData icon;
  final String? title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onDismiss;
  final bool overlay;
  final bool _compact;

  const FeatureTipCard({
    super.key,
    required this.icon,
    required String this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    required this.onDismiss,
    this.overlay = false,
  }) : _compact = false;

  const FeatureTipCard.compact({
    super.key,
    required this.icon,
    required this.message,
    required this.onDismiss,
    this.overlay = false,
  }) : title = null,
       actionLabel = null,
       onAction = null,
       _compact = true;

  @override
  Widget build(BuildContext context) {
    final grey = context.vColors.grayText;
    final tint = overlay ? context.vColors.surfaceElevated : null;
    final shadow = overlay ? AppShadows.shadowY : null;
    if (_compact) {
      return AppCard(
        width: double.infinity,
        tint: tint,
        shadow: shadow,
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppDimens.space12,
          AppDimens.space4,
          AppDimens.space4,
          AppDimens.space4,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: AppDimens.iconSm,
              color: context.vColors.accentText,
            ),
            const SizedBox(width: AppDimens.space8),
            Expanded(
              child: Text(
                message,
                style: context.text.bodyMedium?.copyWith(
                  color: context.colors.onSurface,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Got it',
              visualDensity: VisualDensity.compact,
              onPressed: onDismiss,
              icon: Icon(
                Icons.close_rounded,
                size: AppDimens.iconSm,
                color: grey,
              ),
            ),
          ],
        ),
      );
    }
    final actionLabel = this.actionLabel;
    return AppCard(
      width: double.infinity,
      tint: tint,
      shadow: shadow,
      padding: AppDimens.cardPaddingCompact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppIconBadge(icon: Icon(icon)),
              const SizedBox(width: AppDimens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title!,
                      style: context.text.titleSmall?.copyWith(
                        color: context.colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppDimens.space2),
                    Text(
                      message,
                      style: context.text.bodyMedium?.copyWith(color: grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.space8),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: AppDimens.space8,
            children: [
              TextButton(
                onPressed: onDismiss,
                style: TextButton.styleFrom(
                  foregroundColor: actionLabel == null
                      ? context.vColors.accentText
                      : grey,
                ),
                child: Text(actionLabel == null ? 'Got it' : 'Not now'),
              ),
              if (actionLabel != null)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    foregroundColor: context.vColors.accentText,
                  ),
                  child: Text(actionLabel),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
