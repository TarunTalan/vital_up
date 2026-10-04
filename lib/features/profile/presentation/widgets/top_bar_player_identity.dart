import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/theme/app_theme.dart';
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
                        // 1. Avatar with tier colored frame
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: tier.borderColor,
                              width: AppDimens.borderThin,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: tier.glowColor.withValues(alpha: 0.15),
                                blurRadius: 4,
                                spreadRadius: 0.5,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child: avatarUrl != null
                                ? Image.network(
                                    avatarUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => _FallbackAvatar(avatarInitial),
                                  )
                                : _FallbackAvatar(avatarInitial),
                          ),
                        ),
                        const SizedBox(width: AppDimens.space10),
                        
                        // 2. Name + Level Pill
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
                                      color: tier.glowColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                                      border: Border.all(
                                        color: tier.borderColor.withValues(alpha: 0.5),
                                        width: AppDimens.borderThin,
                                      ),
                                    ),
                                    child: Text(
                                      'Lv $level',
                                      style: context.text.labelSmall?.copyWith(
                                        color: tier.borderColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
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

class _FallbackAvatar extends StatelessWidget {
  final String initial;
  const _FallbackAvatar(this.initial);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.colors.primary.withValues(alpha: 0.15),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: context.text.titleSmall?.copyWith(
          color: context.colors.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
