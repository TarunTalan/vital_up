import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';

class AccuracyInfoDialog extends StatelessWidget {
  const AccuracyInfoDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = context.colors.primary;
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;
    final bottomPadding = mediaQuery.padding.bottom;

    return Dialog(
      insetPadding: EdgeInsets.fromLTRB(
        AppDimens.gutter,
        topPadding > 0 ? topPadding + AppDimens.space24 : AppDimens.space24,
        AppDimens.gutter,
        bottomPadding > 0 ? bottomPadding + AppDimens.space24 : AppDimens.space24,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusDialog),
        side: BorderSide(color: context.vColors.hairline!),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppDimens.maxContentWidth),
        child: Padding(
          padding: AppDimens.cardPaddingLarge,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  AppIconBadge(
                    icon: Icon(Icons.verified_rounded, color: primary),
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
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildInfoRow(
                        context,
                        Icons.smart_toy_rounded,
                        'Dual AI Verification',
                        'Recognized using dual vision engines (Google Gemini + Groq Qwen) to prevent identification errors.',
                        svgAsset: 'assets/icons/nav/vita.svg',
                      ),
                      const SizedBox(height: AppDimens.space12),
                      _buildInfoRow(
                        context,
                        Icons.menu_book_rounded,
                        'Laboratory Mapped',
                        'Calories and macros are pulled directly from USDA & Indian Food Composition Tables (IFCT) laboratory composition records—never guessed or hallucinated by AI.',
                      ),
                      const SizedBox(height: AppDimens.space12),
                      _buildInfoRow(
                        context,
                        Icons.travel_explore_rounded,
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
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppDimens.space20),
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
    String desc, {
    String? svgAsset,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (svgAsset != null)
          SvgPicture.asset(
            svgAsset,
            width: AppDimens.iconMd,
            height: AppDimens.iconMd,
            colorFilter: ColorFilter.mode(
              context.colors.primary,
              BlendMode.srcIn,
            ),
          )
        else
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
