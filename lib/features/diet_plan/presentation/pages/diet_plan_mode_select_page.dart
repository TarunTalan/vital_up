import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';

class DietPlanModeSelectPage extends StatelessWidget {
  final Map<String, dynamic> preferences;

  const DietPlanModeSelectPage({super.key, required this.preferences});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      header: const AppPageHeader(title: 'Choose Mode'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How would you like to set your targets?',
            style: context.text.headlineSmall,
          ),
          const SizedBox(height: AppDimens.sectionGap),
          _ModeCard(
            title: 'Smart Mode',
            subtitle: 'Uses your health profile to calculate the perfect maintenance plan.',
            icon: Icons.auto_awesome,
            onTap: () {
              context.pushNamed(
                'diet-plan-result',
                extra: {
                  'mode': 'smart',
                  'preferences': preferences,
                },
              );
            },
          ),
          const SizedBox(height: AppDimens.cardGap),
          _ModeCard(
            title: 'Goal Mode',
            subtitle: 'Set a weight goal and timeframe. We calculate the optimal deficit/surplus.',
            icon: Icons.track_changes,
            onTap: () {
              context.pushNamed(
                'diet-plan-goal',
                extra: preferences,
              );
            },
          ),
          const SizedBox(height: AppDimens.cardGap),
          _ModeCard(
            title: 'Manual Mode',
            subtitle: 'I know exactly what I want. Let me enter my macros directly.',
            icon: Icons.edit_note,
            onTap: () {
              context.pushNamed(
                'diet-plan-manual',
                extra: preferences,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final grey = context.vColors.grayText;
    return AppCard(
      onTap: onTap,
      padding: AppDimens.cardPaddingCompact,
      child: Row(
        children: [
          AppIconBadge(icon: Icon(icon), size: AppDimens.iconBadgeLarge),
          const SizedBox(width: AppDimens.space16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleSmall),
                const SizedBox(height: AppDimens.space4),
                Text(
                  subtitle,
                  style: context.text.bodyMedium?.copyWith(color: grey),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimens.space8),
          Icon(Icons.chevron_right_rounded, color: grey, size: AppDimens.iconLg),
        ],
      ),
    );
  }
}
