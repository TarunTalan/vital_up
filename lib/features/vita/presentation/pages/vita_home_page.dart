import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/features/vita/presentation/utils/vita_icons.dart';
import 'package:vital_up/features/vita/presentation/widgets/vita_avatar.dart';

/// Vita tab — Figma `health coach/default` (1893:14545): "Meet Vita" intro,
/// four feature tiles and the AI disclaimer, centred on the page.
class VitaHomePage extends StatelessWidget {
  final VoidCallback? onBack;

  const VitaHomePage({super.key, this.onBack});

  @override
  Widget build(BuildContext context) {
    // The dashboard uses Scaffold.extendBody, so the floating nav bar height
    // arrives as bottom padding.
    final bottom = context.safePadding.bottom + AppDimens.sectionGap;

    return AppScaffold(
      header: AppTitleBar(onBack: onBack),
      scrollable: false,
      padBody: false,
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            context.gutter,
            0,
            context.gutter,
            bottom,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - bottom).clamp(0, double.infinity),
            ),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MeetVitaCard(),
                  SizedBox(height: VitaDimens.homeGap),
                  _FeatureGrid(),
                  SizedBox(height: VitaDimens.homeGap),
                  AppInfoNote(
                    message: "VitalUp's health coach is AI-powered and for "
                        'informational purposes only. Always consult a '
                        'qualified healthcare professional for medical '
                        'decisions.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MeetVitaCard extends StatelessWidget {
  const _MeetVitaCard();

  @override
  Widget build(BuildContext context) {
    final onSurface = context.colors.onSurface;
    return AppCard(
      blur: true,
      width: double.infinity,
      padding: AppDimens.cardPaddingLarge,
      child: Column(
        children: [
          const VitaAvatar.large(),
          const SizedBox(height: AppDimens.space24),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Meet '),
                TextSpan(
                  text: 'Vita',
                  style: TextStyle(color: VitaColors.accent),
                ),
              ],
            ),
            textAlign: TextAlign.center,
            style: context.text.headlineMedium?.copyWith(color: onSurface),
          ),
          const SizedBox(height: AppDimens.space24),
          Text(
            'Your AI health companion, the soul of VitalUp. '
            'I live in every corner of the app.',
            textAlign: TextAlign.center,
            style: context.text.bodyLarge?.copyWith(color: onSurface),
          ),
        ],
      ),
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _FeatureTile(
                label: 'Diet Plan',
                icon: VitaIcons.dietPlan,
                onTap: () => context.pushNamed('vita-diet-plan'),
              ),
            ),
            const SizedBox(width: VitaDimens.tileGapX),
            Expanded(
              child: _FeatureTile(
                label: 'Health Analysis',
                icon: VitaIcons.healthAnalysis,
                onTap: () => context.pushNamed('vita-analysis'),
              ),
            ),
          ],
        ),
        const SizedBox(height: VitaDimens.tileGapY),
        Row(
          children: [
            Expanded(
              child: _FeatureTile(
                label: 'Stress Guide',
                icon: VitaIcons.stressGuide,
                onTap: () => context.pushNamed('vita-stress'),
              ),
            ),
            const SizedBox(width: VitaDimens.tileGapX),
            Expanded(
              child: _FeatureTile(
                label: 'Vita Chat',
                icon: VitaIcons.chat,
                onTap: () => context.pushNamed('vita-chat'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Figma `Container` tile: cyan glass (primaryFill + primaryBorder),
/// 24dp icon + body-16 accent label.
class _FeatureTile extends StatelessWidget {
  final String label;
  final String icon;
  final VoidCallback onTap;

  const _FeatureTile({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final radius = BorderRadius.circular(AppDimens.radiusCard);

    return Material(
      color: v.primaryFill,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: v.primaryBorder!),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: VitaDimens.tileHeight),
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.space12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  icon,
                  width: AppDimens.iconLg,
                  height: AppDimens.iconLg,
                ),
                const SizedBox(width: AppDimens.space16),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodyLarge?.copyWith(
                      color: VitaColors.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
