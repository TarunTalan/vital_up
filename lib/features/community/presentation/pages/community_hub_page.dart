import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/load_error_view.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:vital_up/features/challenges/data/challenges_repository.dart';
import 'package:vital_up/features/challenges/presentation/challenges_cubit.dart';
import 'package:vital_up/features/challenges/presentation/widgets/arena_challenges_section.dart';
import 'package:vital_up/features/community/presentation/cubit/community_cubit.dart';
import 'package:vital_up/features/community/presentation/widgets/community_leaderboards_section.dart';
import 'package:vital_up/features/community/presentation/widgets/friends_quick_row.dart';
import 'package:vital_up/features/gamification/presentation/cubit/gamification_cubit.dart';
import 'package:vital_up/features/profile/presentation/widgets/gamer_profile_card.dart';
import 'package:vital_up/features/profile/presentation/widgets/top_bar_profile_avatar_button.dart';

/// The Gamification Arena Hub (Community Tab):
/// 1. Compact Player Card (Level, Badge, Points, XP progress, Rank, Streak)
/// 2. Quick Friends Row (Avatars, Level Badges, Quick Challenge, Invite +200 XP)
/// 3. Activity Heatmap Calendar (Daily achievements, Streak & Weekly progress)
/// 4. Daily Challenges (Incoming invites with Accept/Decline, Active 1v1 duels, Stakes ±50 XP)
/// 5. Communities & Leaderboards (Global, City, Joined & Discover boards + Settings)
class CommunityHubPage extends StatelessWidget {
  const CommunityHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => sl<CommunityCubit>()..load(),
        ),
        BlocProvider(
          create: (_) => ChallengesCubit(sl<ChallengesRepository>())..load(),
        ),
      ],
      child: const _ArenaHubView(),
    );
  }
}

/// Alias for CommunityHubPage to reflect the Arena gamification identity.
typedef ArenaHubPage = CommunityHubPage;

class _ArenaHubView extends StatelessWidget {
  const _ArenaHubView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CommunityCubit, CommunityState>(
      listenWhen: (_, s) => s.message != null,
      listener: (context, s) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.message!)),
      ),
      builder: (context, state) {
        final cubit = context.read<CommunityCubit>();
        final challengesCubit = context.read<ChallengesCubit>();
        final communities = state.communities;

        return AppScaffold(
          onRefresh: () async {
            await Future.wait([
              cubit.load(),
              challengesCubit.load(),
              context.read<GamificationCubit>().load(),
            ]);
          },
          header: const AppPageHeader(
            title: 'Arena',
            subtitle: 'Gamification & Community',
            showBack: false,
            action: TopBarProfileAvatarButton(),
          ),
          body: communities == null
              ? Padding(
                  padding: const EdgeInsets.only(top: AppDimens.space48),
                  child: state.failed
                      ? LoadErrorView(onRetry: cubit.load)
                      : const Center(child: VitalUpLoader()),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Compact Player Profile Card (Level, Badge, Points, Progress, Rank, Streaks)
                    const GamerProfileCard.compact(),
                    const SizedBox(height: AppDimens.space12),

                    // 2. Friends Quick Row (Avatars, Level Badges, Duel action, Invite +200 XP)
                    FriendsQuickRow(
                      friends: state.friends,
                      incomingRequests: state.incomingRequests,
                      myUsername: state.settings.username,
                      onRefresh: () => cubit.load(),
                    ),
                    const SizedBox(height: AppDimens.sectionGap),

                    // 3. Challenges Center (Incoming invites, Active challenges, Win/Loss stakes)
                    ArenaChallengesSection(
                      onRefresh: () => challengesCubit.load(),
                    ),
                    const SizedBox(height: AppDimens.sectionGap),

                    // 4. Communities & Leaderboards (Global, City, Joined, Discover, Settings)
                    const CommunityLeaderboardsSection(),

                    // Bottom safe spacing for floating bottom navigation bar
                    SizedBox(
                      height: context.safePadding.bottom + AppDimens.sectionGap * 1.5,
                    ),
                  ],
                ),
        );
      },
    );
  }
}
