import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_list_group.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/features/subscription/data/services/ai_quota_service.dart';
import 'package:vital_up/features/subscription/presentation/cubit/subscription_cubit.dart';
import 'package:vital_up/features/subscription/presentation/widgets/ai_quota_line.dart';
import 'package:vital_up/features/vita/presentation/utils/vita_icons.dart';
import 'package:vital_up/features/vita/presentation/widgets/vita_avatar.dart';

/// Vita tab: what Vita is with the way into the chat, then Vita's other
/// pages as a list, then the AI note. Same header as Arena and Profile.
class VitaHomePage extends StatelessWidget {
  const VitaHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      header: AppPageHeader(
        title: 'Vita',
        showBack: false,
        action: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _ProAction(),
            AppHeaderAction(
              tooltip: 'AI coach data',
              icon: const Icon(Icons.shield_outlined),
              onTap: () => context.pushNamed('ai-coach-data'),
            ),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _MeetVitaCard(),
          const SizedBox(height: AppDimens.sectionGap),
          AppListGroup(
            title: 'More from Vita',
            children: [
              AppListTile(
                svgAsset: VitaIcons.dietPlan,
                iconColor: VitaColors.accent,
                title: 'Diet plan',
                subtitle: "Today's meals, with Vita's notes",
                onTap: () => context.pushNamed('vita-diet-plan'),
              ),
              AppListTile(
                svgAsset: VitaIcons.healthAnalysis,
                iconColor: VitaColors.accent,
                title: 'Health analysis',
                subtitle: 'What your logs say about your health',
                onTap: () => context.pushNamed('vita-analysis'),
              ),
              AppListTile(
                svgAsset: VitaIcons.stressGuide,
                iconColor: VitaColors.accent,
                title: 'Stress guide',
                subtitle: 'Your stress estimate and a tip for today',
                onTap: () => context.pushNamed('vita-stress'),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.sectionGap),
          const AppInfoNote(
            message:
                'Vita gives general wellness tips, not medical advice. For '
                'medical decisions, talk to a healthcare professional.',
          ),
          // The dashboard extends under its floating nav bar, whose height
          // arrives as bottom padding (as on Profile).
          SizedBox(height: context.safePadding.bottom + AppDimens.space16),
        ],
      ),
    );
  }
}

class _MeetVitaCard extends StatelessWidget {
  const _MeetVitaCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      highlighted: true,
      padding: AppDimens.cardPaddingLarge,
      child: Column(
        children: [
          const VitaAvatar.large(),
          const SizedBox(height: AppDimens.space16),
          Text(
            'Meet Vita',
            textAlign: TextAlign.center,
            style: context.text.headlineSmall?.copyWith(
              color: context.colors.onSurface,
            ),
          ),
          const SizedBox(height: AppDimens.space8),
          Text(
            'Your AI health coach. Ask about food, sleep, stress, activity '
            'or how to use VitalUp.',
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(
              color: context.vColors.grayText,
            ),
          ),
          const SizedBox(height: AppDimens.space16),
          AppPrimaryButton(
            label: 'Chat with Vita',
            onTap: () => context.pushNamed('vita-chat'),
          ),
          const SizedBox(height: AppDimens.space8),
          const AiQuotaLine(quota: AiQuota.vitaChat),
        ],
      ),
    );
  }
}

/// VitalUp Pro in the header: free users see what Pro adds, Pro users
/// their plan. Hidden where Pro can't be bought and the user isn't Pro.
class _ProAction extends StatelessWidget {
  const _ProAction();

  @override
  Widget build(BuildContext context) {
    final plan = context.watch<SubscriptionCubit?>()?.state;
    if (plan == null || !(plan.isPro || plan.canPurchase)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: AppDimens.space8),
      child: AppHeaderAction(
        tooltip: plan.isPro ? 'Your Pro plan' : 'Get VitalUp Pro',
        icon: const Icon(Icons.workspace_premium_outlined),
        onTap: () => context.pushNamed('vitalup-pro'),
      ),
    );
  }
}
