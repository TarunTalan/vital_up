import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/features/community/domain/entities/community.dart';
import 'package:vital_up/features/community/domain/entities/community_standing.dart';
import 'package:vital_up/features/community/domain/entities/friend.dart';
import 'package:vital_up/features/community/domain/entities/leaderboard_entry.dart';
import 'package:vital_up/features/community/presentation/widgets/friends_quick_row.dart';
import 'package:vital_up/features/community/domain/repositories/community_repository.dart';
import 'package:vital_up/features/community/presentation/cubit/community_cubit.dart';
import 'package:vital_up/features/community/presentation/widgets/community_leaderboards_section.dart';
import 'package:vital_up/features/gamification/domain/entities/player_stats.dart';
import 'package:vital_up/features/gamification/domain/entities/score_category.dart';
import 'package:vital_up/features/gamification/domain/repositories/gamification_repository.dart';
import 'package:vital_up/features/gamification/presentation/cubit/gamification_cubit.dart';
import 'package:vital_up/features/gamification/presentation/widgets/score_streak_card.dart';

class _NoRepo implements GamificationRepository, CommunityRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FixedGamification extends GamificationCubit {
  _FixedGamification(GamificationState s) : super(_NoRepo()) {
    emit(s);
  }
}

class _FixedCommunity extends CommunityCubit {
  _FixedCommunity(CommunityState s) : super(_NoRepo()) {
    emit(s);
  }
}

Community _community(String id, CommunityType type, {bool member = true}) =>
    Community(
      id: id,
      slug: id,
      name: 'Community $id',
      type: type,
      iconKey: id,
      memberCount: 340,
      isMember: member,
    );

Widget _host(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: brightness == Brightness.light
          ? AppTheme.lightTheme
          : AppTheme.darkTheme,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  const stats = PlayerStats(
    totalPoints: 1240,
    categoryPoints: {},
    streak: 5,
    longestStreak: 9,
    streakFreezes: 1,
    level: GameLevel(level: 4, minPoints: 1000, title: 'Achiever'),
    nextLevel: GameLevel(level: 5, minPoints: 1500, title: 'Champion'),
  );

  for (final b in Brightness.values) {
    testWidgets('level card shows level, points and stats (${b.name})', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          BlocProvider<GamificationCubit>(
            create: (_) => _FixedGamification(
              const GamificationState(
                stats: stats,
                today: {ScoreCategory.nutrition: 40},
              ),
            ),
            child: const ScoreStreakCard(),
          ),
          brightness: b,
        ),
      );
      expect(find.text('Level 4'), findsOneWidget);
      expect(find.text('Achiever'), findsOneWidget);
      expect(find.text('1,240 pts · 260 to Level 5'), findsOneWidget);
      expect(find.text('5 days'), findsOneWidget);
      expect(find.text('+40'), findsOneWidget);
      expect(find.text('Rest day'), findsOneWidget);
      for (final s in ['Badges', 'Points', 'Calendar']) {
        expect(find.text(s), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('level card fits a narrow phone with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 900),
          textScaler: TextScaler.linear(1.3),
        ),
        child: _host(
          BlocProvider<GamificationCubit>(
            create: (_) =>
                _FixedGamification(const GamificationState(stats: stats)),
            child: const ScoreStreakCard(),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaderboards list shows ranks and folds discover away', (
    tester,
  ) async {
    final global = _community('g', CommunityType.global);
    final joined = _community('run', CommunityType.interest);
    await tester.pumpWidget(
      _host(
        BlocProvider<CommunityCubit>(
          create: (_) => _FixedCommunity(
            CommunityState(
              loading: false,
              communities: [
                global,
                joined,
                _community('a', CommunityType.interest, member: false),
                _community('b', CommunityType.interest, member: false),
              ],
              standings: const {
                'g': CommunityStanding(
                  communityId: 'g',
                  rank: 12,
                  friendCount: 2,
                ),
              },
            ),
          ),
          child: const CommunityLeaderboardsSection(),
        ),
      ),
    );
    expect(find.text('#12'), findsOneWidget);
    expect(find.text('340 members · 2 friends ranked'), findsOneWidget);
    expect(find.text('Community run'), findsOneWidget);
    expect(find.text('Add your city'), findsOneWidget);
    // Communities to join are behind one row, not listed on the hub.
    expect(find.text('Community a'), findsNothing);
    expect(find.text('2 to join'), findsOneWidget);

    await tester.tap(find.text('Find communities'));
    await tester.pumpAndSettle();
    expect(find.text('Community a'), findsOneWidget);
    expect(find.text('Join'), findsNWidgets(2));
  });

  testWidgets('friend cards show whole names, points and level', (
    tester,
  ) async {
    Friend friend(String id, String name) => Friend(
      userId: id,
      username: name,
      level: 5,
      status: FriendStatus.accepted,
    );
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 900),
          textScaler: TextScaler.linear(1.3),
        ),
        child: _host(
          FriendsQuickRow(
            friends: [friend('a', 'longest_username_20c'), friend('b', 'bo')],
            ranking: const [
              LeaderboardEntry(
                rank: 1,
                userId: 'a',
                username: 'longest_username_20c',
                points: 1240,
                level: 5,
              ),
              LeaderboardEntry(
                rank: 4,
                userId: 'me',
                username: 'me',
                points: 300,
                level: 2,
                isMe: true,
              ),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('longest_username_20c'), findsOneWidget);
    expect(find.text('1,240 pts'), findsOneWidget);
    expect(find.text('Level 5'), findsNWidgets(2));
    expect(find.text('You'), findsOneWidget);
    // Rank 4 sits on the avatar as a number; 1 to 3 use the medal.
    expect(find.text('4'), findsOneWidget);
    expect(find.text('1'), findsNothing);
  });
}
