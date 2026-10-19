import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_list_group.dart';
import 'package:vital_up/features/subscription/presentation/cubit/subscription_cubit.dart';
import 'package:vital_up/features/subscription/presentation/widgets/pro_paywall.dart';

/// Profile section for VitalUp Pro: the current plan, or what Pro adds,
/// followed by a section gap. Hidden where Pro can't be bought and the user
/// doesn't have it.
class ProPlanSection extends StatelessWidget {
  const ProPlanSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SubscriptionCubit, SubscriptionState>(
      buildWhen: (a, b) =>
          a.status != b.status || a.canPurchase != b.canPurchase,
      builder: (context, state) {
        if (!state.isPro && !state.canPurchase) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppListGroup(
              children: [
                AppListTile(
                  icon: Icons.workspace_premium_rounded,
                  iconColor: context.colors.primary,
                  title: 'VitalUp Pro',
                  subtitle: state.isPro
                      ? ProStatusCard.describe(state.status)
                      : 'More food scans and Vita chats',
                  onTap: () => context.pushNamed('vitalup-pro'),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.sectionGap),
          ],
        );
      },
    );
  }
}
