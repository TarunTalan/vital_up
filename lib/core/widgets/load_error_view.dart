import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/load_timeout.dart';

/// Centred "couldn't load" message with a Retry button, shown when a load
/// fails or hits [kLoadTimeout].
class LoadErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  final String message;

  const LoadErrorView({
    super.key,
    required this.onRetry,
    this.message = kLoadErrorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: AppDimens.iconXl,
            color: context.vColors.grayText,
          ),
          const SizedBox(height: AppDimens.space8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: context.text.bodyMedium
                ?.copyWith(color: context.vColors.grayText),
          ),
          const SizedBox(height: AppDimens.space8),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
