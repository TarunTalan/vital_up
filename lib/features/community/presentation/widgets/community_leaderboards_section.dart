import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/features/community/domain/entities/community.dart';
import 'package:vital_up/features/community/presentation/cubit/community_cubit.dart';
import 'package:vital_up/features/community/presentation/widgets/community_widgets.dart';

/// Preserves and organizes all Community features — Global, City, Joined,
/// and Discover leaderboards + Leaderboard settings — in the Gamification Arena hub.
class CommunityLeaderboardsSection extends StatelessWidget {
  const CommunityLeaderboardsSection({super.key});

  Future<void> _openLeaderboard(
    BuildContext context,
    Community community,
  ) async {
    final cubit = context.read<CommunityCubit>();
    await context.pushNamed(
      'leaderboard',
      pathParameters: {'id': community.id},
      extra: community,
    );
    cubit.load();
  }

  Future<void> _editCity(BuildContext context) async {
    final cubit = context.read<CommunityCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final settings = cubit.state.settings;
    final result = await showAppBottomSheet<(String, String)>(
      context: context,
      builder: (_) =>
          CitySheet(city: settings.city, countryCode: settings.countryCode),
    );
    if (result == null) return;
    final ok = await cubit.setCity(result.$1, result.$2);
    if (!ok && context.mounted) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't save your city. Try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;

    return BlocBuilder<CommunityCubit, CommunityState>(
      builder: (context, state) {
        final cubit = context.read<CommunityCubit>();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Title
            Text(
              'Leaderboards & Communities',
              style: context.text.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppDimens.space12),

            // Global Leaderboard Tile
            if (state.global case final global?) ...[
              CommunityTile(
                community: global,
                onTap: () => _openLeaderboard(context, global),
              ),
              const SizedBox(height: AppDimens.cardGap),
            ],

            // Local / Near You Tile
            if (state.local case final local?) ...[
              CommunityTile(
                community: local,
                onTap: () => _openLeaderboard(context, local),
              ),
              const SizedBox(height: AppDimens.cardGap),
            ] else ...[
              AppCard(
                width: double.infinity,
                padding: AppDimens.cardPaddingCompact,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        AppIconBadge(
                          color: context.colors.primary,
                          icon: Icon(
                            Icons.location_city_rounded,
                            size: AppDimens.iconSm,
                            color: context.colors.primary,
                          ),
                        ),
                        const SizedBox(width: AppDimens.space12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Local City Leaderboard',
                                style: context.text.titleSmall?.copyWith(
                                  color: context.colors.onSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Compete with people in your city.',
                                style: context.text.bodySmall?.copyWith(
                                  color: v.grayText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimens.space12),
                    AppSecondaryButton(
                      label: 'Set your city',
                      onTap: () => _editCity(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimens.cardGap),
            ],

            // Joined Communities
            if (state.joined.isNotEmpty) ...[
              const SizedBox(height: AppDimens.space8),
              Text(
                'Your Communities',
                style: context.text.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppDimens.space8),
              for (final c in state.joined) ...[
                CommunityTile(
                  community: c,
                  onTap: () => _openLeaderboard(context, c),
                ),
                const SizedBox(height: AppDimens.cardGap),
              ],
            ],

            // Discover Communities
            if (state.discover.isNotEmpty) ...[
              const SizedBox(height: AppDimens.space8),
              Text(
                'Discover Communities',
                style: context.text.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppDimens.space8),
              for (final c in state.discover) ...[
                CommunityTile(
                  community: c,
                  onTap: () => _openLeaderboard(context, c),
                  trailing: AppPrimaryButton(
                    label: 'Join',
                    expand: false,
                    isLoading: state.busy.contains(c.id),
                    onTap: () => cubit.toggleMembership(c),
                  ),
                ),
                const SizedBox(height: AppDimens.cardGap),
              ],
            ],

            // Community Settings Card
            const SizedBox(height: AppDimens.space8),
            Text(
              'Leaderboard Settings',
              style: context.text.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppDimens.space8),
            AppCard(
              width: double.infinity,
              padding: AppDimens.cardPaddingCompact,
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Show me on leaderboards',
                      style: context.text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Public boards show your username, avatar and points. Friends always see you.',
                      style: context.text.bodySmall?.copyWith(
                        color: v.grayText,
                      ),
                    ),
                    value: state.settings.leaderboardVisible,
                    onChanged: cubit.setLeaderboardVisible,
                  ),
                  const Divider(height: AppDimens.space16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'City',
                      style: context.text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      state.settings.city ?? 'Not set',
                      style: context.text.bodySmall?.copyWith(
                        color: v.grayText,
                      ),
                    ),
                    trailing: SvgPicture.asset(
                      'assets/icons/edit.svg',
                      width: AppDimens.iconSm,
                      height: AppDimens.iconSm,
                      colorFilter: ColorFilter.mode(
                        v.grayText!,
                        BlendMode.srcIn,
                      ),
                    ),
                    onTap: () => _editCity(context),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
