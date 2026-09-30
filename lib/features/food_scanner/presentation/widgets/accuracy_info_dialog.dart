import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';

class AccuracyInfoDialog extends StatelessWidget {
  const AccuracyInfoDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = context.colors.primary;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppDimens.gutter,
        vertical: AppDimens.space24,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusDialog),
        side: BorderSide(color: context.vColors.hairline!),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppDimens.maxContentWidth),
        child: SingleChildScrollView(
          padding: AppDimens.cardPaddingLarge,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  AppIconBadge(
                    icon: Icon(Icons.verified_outlined, color: primary),
                  ),
                  const SizedBox(width: AppDimens.space12),
                  Expanded(
                    child: Text(
                      'How accurate is this?',
                      style: context.text.headlineSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.space16),
              _buildInfoRow(
                context,
                Icons.biotech_outlined,
                'Dual AI Verification',
                'Recognized using dual vision engines (Google Gemini + Groq Qwen) to prevent identification errors.',
              ),
              const SizedBox(height: AppDimens.space12),
              _buildInfoRow(
                context,
                Icons.menu_book_outlined,
                'Laboratory Mapped',
                'Calories and macros are pulled directly from USDA & Indian Food Composition Tables (IFCT) laboratory composition records—never guessed or hallucinated by AI.',
              ),
              const SizedBox(height: AppDimens.space12),
              _buildInfoRow(
                context,
                Icons.travel_explore_outlined,
                'Google Search Grounding',
                'Recipes or regional dishes are double-checked using live web searches to map verified nutritional details.',
              ),
              const SizedBox(height: AppDimens.space12),
              _buildInfoRow(
                context,
                Icons.warning_amber_rounded,
                'Low Confidence Alert',
                'If result confidence is under 70%, a caution alert is surfaced so you can inspect and modify portion sizes or items.',
              ),
              const SizedBox(height: AppDimens.space24),
              AppPrimaryButton(
                label: 'Got it',
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String title,
    String desc,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: AppDimens.iconMd, color: context.colors.primary),
        const SizedBox(width: AppDimens.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.text.titleSmall),
              const SizedBox(height: AppDimens.space2),
              Text(
                desc,
                style: context.text.bodyMedium?.copyWith(
                  color: context.vColors.grayText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
