import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/features/community/presentation/widgets/community_widgets.dart';
import 'package:vital_up/features/gamification/presentation/cubit/gamification_cubit.dart';
import 'package:vital_up/features/gamification/presentation/widgets/level_badge_widget.dart';
import 'package:vital_up/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:vital_up/features/profile/presentation/cubit/profile_state.dart';

final _numberFormat = NumberFormat.decimalPattern();

/// An interactive gamer identity widget displayed on the left side of the
/// dashboard top bar, combining the player's avatar, tier frame glow,
/// level badge, username, level pill, and points.
class TopBarPlayerIdentity extends StatelessWidget {
  const TopBarPlayerIdentity({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GamificationCubit, GamificationState>(
      builder: (context, gameState) {
        final stats = gameState.stats;
        final level = stats?.level.level ?? 1;
        final totalPoints = stats?.totalPoints ?? 0;
        final tier = LevelTierConfig.forLevel(level, title: stats?.level.title);

        return BlocBuilder<ProfileCubit, ProfileState>(
          builder: (context, profState) {
            String? avatarUrl;
            String displayName = 'Athlete';
            String avatarInitial = 'A';

            if (profState is ProfileLoaded) {
              avatarUrl = profState.profile.photoUrl;
              final name = profState.profile.fullName.trim();
              if (name.isNotEmpty) {
                displayName = name.split(' ').first;
                avatarInitial = name;
              } else if (profState.profile.username.isNotEmpty) {
                displayName = profState.profile.username;
                avatarInitial = displayName;
              }
            } else if (profState is ProfilePhotoUpdated) {
              avatarUrl = profState.profile.photoUrl;
              displayName = profState.profile.username.isNotEmpty
                  ? profState.profile.username
                  : 'Athlete';
              avatarInitial = displayName;
            }

            return Tooltip(
              message: 'View Profile',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => context.pushNamed('profile'),
                  borderRadius: BorderRadius.circular(AppDimens.radiusCard),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.space4,
                      vertical: AppDimens.space4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 1. Avatar with tier glowing frame & mini level badge
                        Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            Container(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                              ),
                              child: UserAvatar(
                                username: avatarInitial,
                                url: avatarUrl,
                                size: AppDimens.iconBadge,
                                ringColor: tier.borderColor,
                              ),
                            ),
                            Positioned(
                              bottom: -AppDimens.space2,
                              right: -AppDimens.space4,
                              child: LevelBadgeWidget(
                                level: level,
                                size: AppDimens.iconXs,
                                showGlow: false,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: AppDimens.space10),

                        // 2. Name + Level Pill & Points Row
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.text.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: context.colors.onSurface,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppDimens.space6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppDimens.space6,
                                      vertical: AppDimens.space2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: tier.glowColor.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(
                                        AppDimens.radiusPill,
                                      ),
                                      border: Border.all(
                                        color: tier.borderColor.withValues(
                                          alpha: 0.5,
                                        ),
                                        width: AppDimens.borderThin,
                                      ),
                                    ),
                                    child: Text(
                                      'Lv $level',
                                      style: context.text.labelSmall?.copyWith(
                                        color: tier.borderColor,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.1,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppDimens.space2),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.bolt_rounded,
                                    size: AppDimens.iconXs,
                                    color: AppColors.rankGold,
                                  ),
                                  const SizedBox(width: AppDimens.space2),
                                  Text(
                                    '${_numberFormat.format(totalPoints)} pts',
                                    style: context.text.labelSmall?.copyWith(
                                      color: context.colors.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: AppDimens.space4),
                                  Text(
                                    '•',
                                    style: TextStyle(
                                      color: context.vColors.grayText,
                                    ),
                                  ),
                                  const SizedBox(width: AppDimens.space4),
                                  Flexible(
                                    child: Text(
                                      tier.tierName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.text.labelSmall?.copyWith(
                                        color: tier.borderColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
