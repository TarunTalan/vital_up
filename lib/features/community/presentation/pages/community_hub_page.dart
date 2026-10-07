import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/app_section_header.dart';
import 'package:vital_up/core/widgets/load_error_view.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:vital_up/features/challenges/data/challenges_repository.dart';
import 'package:vital_up/features/challenges/presentation/challenges_cubit.dart';
import 'package:vital_up/features/challenges/presentation/widgets/arena_challenges_section.dart';
import 'package:vital_up/features/community/presentation/cubit/community_cubit.dart';
import 'package:vital_up/features/community/presentation/widgets/community_leaderboards_section.dart';
import 'package:vital_up/features/community/presentation/widgets/friends_quick_row.dart';
import 'package:vital_up/features/gamification/presentation/cubit/gamification_cubit.dart';
import 'package:vital_up/features/gamification/presentation/widgets/score_streak_card.dart';

/// The Arena tab: your level and points, challenges, friends, and
/// leaderboards, in that order. Leaderboard settings sit in the header.
class CommunityHubPage extends StatelessWidget {
  const CommunityHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<CommunityCubit>()..load()),
        BlocProvider(
          create: (_) => ChallengesCubit(sl<ChallengesRepository>())..load(),
        ),
      ],
      child: const _ArenaHubView(),
    );
  }
}

/// Alias for CommunityHubPage to reflect the Arena identity.
typedef ArenaHubPage = CommunityHubPage;

class _ArenaHubView extends StatelessWidget {
  const _ArenaHubView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CommunityCubit, CommunityState>(
      listenWhen: (_, s) => s.message != null,
      listener: (context, s) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.message!))),
      builder: (context, state) {
        final cubit = context.read<CommunityCubit>();
        final challengesCubit = context.read<ChallengesCubit>();

        return AppScaffold(
          onRefresh: () async {
            await Future.wait([
              cubit.load(),
              challengesCubit.load(),
              context.read<GamificationCubit>().load(),
            ]);
          },
          header: AppPageHeader(
            title: 'Arena',
            showBack: false,
            action: AppHeaderAction(
              tooltip: 'Leaderboard settings',
              icon: const Icon(Icons.settings_rounded),
              onTap: () => CommunitySettingsSheet.show(context),
            ),
          ),
          body: state.communities == null
              ? Padding(
                  padding: const EdgeInsets.only(top: AppDimens.space48),
                  child: state.failed
                      ? LoadErrorView(onRetry: cubit.load)
                      : const Center(child: VitalUpLoader()),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AppSectionHeader('Your progress'),
                    const ScoreStreakCard(),
                    const SizedBox(height: AppDimens.sectionGap),

                    ArenaChallengesSection(onRefresh: challengesCubit.load),
                    const SizedBox(height: AppDimens.sectionGap),

                    FriendsQuickRow(
                      friends: state.friends,
                      incomingRequests: state.incomingRequests,
                      myUsername: state.settings.username,
                      onRefresh: cubit.load,
                    ),
                    const SizedBox(height: AppDimens.sectionGap),

                    const CommunityLeaderboardsSection(),

                    // Clears the floating bottom navigation bar.
                    SizedBox(
                      height:
                          context.safePadding.bottom +
                          AppDimens.sectionGap * 1.5,
                    ),
                  ],
                ),
        );
      },
    );
  }
}
