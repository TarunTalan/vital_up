// The Arena pages (hub, a community leaderboard, challenges) on small and
// large phones, at every text size, light and dark, with nothing cut or
// overflowing. `HOME_SHOTS=1` also writes PNGs to build/arena_shots/.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/features/challenges/data/challenges_repository.dart';
import 'package:vital_up/features/challenges/presentation/challenges_cubit.dart';
import 'package:vital_up/features/challenges/presentation/challenges_page.dart';
import 'package:vital_up/features/community/domain/entities/community.dart';
import 'package:vital_up/features/community/domain/entities/community_award.dart';
import 'package:vital_up/features/community/domain/entities/community_standing.dart';
import 'package:vital_up/features/community/domain/entities/friend.dart';
import 'package:vital_up/features/community/domain/entities/leaderboard_entry.dart';
import 'package:vital_up/features/community/domain/repositories/community_repository.dart';
import 'package:vital_up/features/community/presentation/cubit/community_cubit.dart';
import 'package:vital_up/features/community/presentation/cubit/friends_cubit.dart';
import 'package:vital_up/features/community/presentation/cubit/leaderboard_cubit.dart';
import 'package:vital_up/features/challenges/presentation/widgets/challenge_tile.dart';
import 'package:vital_up/features/community/presentation/pages/friends_page.dart';
import 'package:vital_up/features/gamification/domain/entities/game_badge.dart';
import 'package:vital_up/features/gamification/domain/entities/point_event.dart';
import 'package:vital_up/features/gamification/presentation/pages/badges_page.dart';
import 'package:vital_up/features/gamification/presentation/pages/points_history_page.dart';
import 'package:vital_up/features/community/presentation/pages/community_hub_page.dart';
import 'package:vital_up/features/community/presentation/pages/leaderboard_page.dart';
import 'package:vital_up/features/gamification/domain/entities/player_stats.dart';
import 'package:vital_up/features/gamification/domain/entities/score_category.dart';
import 'package:vital_up/features/gamification/domain/repositories/gamification_repository.dart';
import 'package:vital_up/features/gamification/presentation/cubit/gamification_cubit.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/readme_shots.dart';

final _writeShots = Platform.environment['HOME_SHOTS'] == '1';

Future<void> _capture(WidgetTester tester, String path) async {
  await tester.runAsync(() async {
    final view = tester.binding.renderViews.first;
    final layer = view.debugLayer! as OffsetLayer;
    final image = await layer.toImage(Offset.zero & view.size, pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

typedef _Case = ({double width, double scale, bool dark});

const List<_Case> _cases = [
  (width: 360, scale: 1.0, dark: false),
  (width: 360, scale: kMaxTextScale, dark: false),
  (width: 412, scale: 1.0, dark: false),
  (width: 412, scale: 1.0, dark: true),
];

const _stats = PlayerStats(
  totalPoints: 1240,
  categoryPoints: {},
  streak: 5,
  longestStreak: 9,
  streakFreezes: 1,
  level: GameLevel(level: 4, minPoints: 1000, title: 'Achiever'),
  nextLevel: GameLevel(level: 5, minPoints: 1500, title: 'Champion'),
);

const _global = Community(
  id: 'g',
  slug: 'global',
  name: 'Global',
  type: CommunityType.global,
  iconKey: 'global',
  memberCount: 23,
  isMember: true,
);

const _city = Community(
  id: 'c',
  slug: 'pune',
  name: 'Pune',
  type: CommunityType.local,
  iconKey: 'city',
  city: 'Pune',
  memberCount: 6,
  isMember: true,
);

const _runners = Community(
  id: 'run',
  slug: 'runners',
  name: 'Runners',
  type: CommunityType.interest,
  iconKey: 'runners',
  description: 'People who run',
  scoreCategories: [ScoreCategory.fitness],
  memberCount: 340,
  isMember: true,
);

const _strength = Community(
  id: 'str',
  slug: 'strength',
  name: 'Strength',
  type: CommunityType.interest,
  iconKey: 'strength',
  memberCount: 120,
);

LeaderboardEntry _entry(int rank, String name, {bool isMe = false}) =>
    LeaderboardEntry(
      rank: rank,
      userId: isMe ? 'me' : name,
      username: name,
      points: 1400 - rank * 90,
      level: 3,
      isMe: isMe,
    );

final _board = [
  _entry(1, 'asha_runs'),
  _entry(2, 'mike'),
  // README shots show a plain name where the layout check needs a long one.
  _entry(3, readmeShots ? 'kavya_fit' : 'longest_username_20c'),
  _entry(4, kDemoUsername, isMe: true),
  _entry(5, 'priya'),
  _entry(6, 'deepak'),
  _entry(7, 'nina'),
  _entry(8, 'omar'),
];

Friend _friend(String name) => Friend(
  userId: name,
  username: name,
  level: 3,
  status: FriendStatus.accepted,
);

Challenge _challenge(
  String id, {
  ParticipantStatus status = ParticipantStatus.joined,
  int endsInDays = 4,
  int length = 7,
  ChallengeMetric metric = ChallengeMetric.activeMinutes,
  int? rank = 2,
}) {
  final now = DateTime.now();
  final ends = now.add(Duration(days: endsInDays, hours: 3));
  return Challenge(
    id: id,
    metric: metric,
    startsAt: ends.subtract(Duration(days: length)),
    endsAt: ends,
    creatorUsername: 'asha_runs',
    myStatus: status,
    participants: 4,
    myScore: 185,
    myRank: rank,
  );
}

final _challenges = [
  _challenge('invite', status: ParticipantStatus.invited, rank: null),
  _challenge('run', metric: ChallengeMetric.distanceKm, endsInDays: 1),
  _challenge('won', endsInDays: -2, rank: 1),
  _challenge('lost', endsInDays: -9, rank: 3, metric: ChallengeMetric.workouts),
  _challenge('left', status: ParticipantStatus.left, endsInDays: -20),
];

class _Repo implements CommunityRepository, GamificationRepository {
  @override
  Future<(List<Community>, CommunitySettings)?> savedHub() async => null;

  @override
  Future<List<LeaderboardEntry>> getLeaderboard(
    Community community, {
    required LeaderboardPeriod period,
    ScoreCategory? category,
    int limit = 50,
    int offset = 0,
  }) async => offset > 0 ? const [] : _board;

  @override
  Future<LeaderboardEntry?> getMyRank(
    Community community, {
    required LeaderboardPeriod period,
    ScoreCategory? category,
  }) async => _board[3];

  @override
  Future<List<LeaderboardEntry>> getFriendRanks(
    Community community, {
    required LeaderboardPeriod period,
    ScoreCategory? category,
  }) async => [_board[1], _board[3]];

  @override
  Future<List<AwardWinner>> getCommunityWinners(
    Community community,
    AwardPeriod period,
  ) async => const [];

  @override
  Future<List<CommunityAward>> getPlayerAwards([String? userId]) async =>
      const [];

  @override
  Future<PlayerStats> getStats() async => _stats;

  @override
  Future<List<PointEvent>> getHistory({int days = 30}) async => [
    for (var d = 0; d < 4; d++) ...[
      PointEvent(
        day: DateTime.now().subtract(Duration(days: d)),
        source: 'water_goal',
        category: ScoreCategory.lifestyle,
        points: 20,
      ),
      PointEvent(
        day: DateTime.now().subtract(Duration(days: d)),
        source: 'meal_logged',
        category: ScoreCategory.nutrition,
        points: 15,
      ),
    ],
  ];

  @override
  Future<List<PointRule>> getRules() async => const [
    PointRule(
      source: 'water_goal',
      category: ScoreCategory.lifestyle,
      name: 'Reach your daily water goal',
      points: 20,
      unit: 'per day',
    ),
    PointRule(
      source: 'meal_logged',
      category: ScoreCategory.nutrition,
      name: 'Log a meal with its nutrition details',
      points: 5,
      unit: 'per meal',
      dailyCap: 15,
    ),
  ];

  @override
  Future<List<GameBadge>> getBadges() async => [
    GameBadge(
      code: 'streak_7',
      name: 'Week Warrior',
      description: 'Keep a 7 day streak',
      iconKey: 'streak_7',
      bonusPoints: 50,
      threshold: 7,
      progress: 7,
      earnedAt: DateTime(2026, 10, 10),
    ),
    const GameBadge(
      code: 'steps_20k',
      name: 'Marathon Walker',
      description: 'Hit 20,000 steps in a single day',
      iconKey: 'steps_20k',
      bonusPoints: 100,
      threshold: 20000,
      progress: 12500,
    ),
    for (final (code, name, description, day) in [
      ('streak_3', 'Warming Up', 'Keep a 3 day streak', 2),
      ('workouts_1', 'First Workout', 'Finish your first workout', 6),
      ('water_days_7', 'Hydration Hero', 'Meet your water goal 7 days', 8),
      ('steps_10k', '10K Day', 'Walk 10,000 steps in a day', 12),
      ('diet_days_7', 'Mindful Eater', 'Stay on your diet plan 7 days', 15),
    ])
      GameBadge(
        code: code,
        name: name,
        description: description,
        iconKey: code,
        bonusPoints: 50,
        threshold: 1,
        progress: 1,
        earnedAt: DateTime(2026, 10, day),
      ),
    const GameBadge(
      code: 'workouts_200',
      name: 'Two Hundred Club',
      description: 'Finish 200 workouts',
      iconKey: 'workouts_200',
      bonusPoints: 300,
      threshold: 200,
      progress: 0,
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Challenges implements ChallengesRepository {
  @override
  Future<List<Challenge>> getChallenges() async => _challenges;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FixedCommunity extends CommunityCubit {
  _FixedCommunity() : super(_Repo()) {
    emit(
      CommunityState(
        loading: false,
        communities: const [_global, _city, _runners, _strength],
        friends: [_friend('mike'), _friend('priya'), _friend('nina')],
        friendsRanking: [_board[1], _board[3], _board[4], _board[6]],
        standings: const {
          'g': CommunityStanding(
            communityId: 'g',
            rank: 4,
            rankedCount: 8,
            friendCount: 2,
          ),
          'c': CommunityStanding(communityId: 'c', rank: 2, rankedCount: 3),
        },
      ),
    );
  }

  @override
  Future<void> load() async {}
}

class _FixedFriends extends FriendsCubit {
  _FixedFriends() : super(_Repo()) {
    emit(
      FriendsState(
        friends: [
          _friend('mike'),
          _friend('priya'),
          _friend('nina'),
          const Friend(
            userId: 'r',
            username: 'rahul_k',
            level: 2,
            status: FriendStatus.incoming,
          ),
        ],
        rankedMembers: [_board[1], _board[3], _board[4], _board[6]],
      ),
    );
  }

  @override
  Future<void> load() async {}
}

class _FixedGamification extends GamificationCubit {
  _FixedGamification() : super(_Repo()) {
    emit(
      const GamificationState(
        stats: _stats,
        today: {ScoreCategory.nutrition: 40},
      ),
    );
  }

  @override
  Future<void> load() async {}
}

void main() {
  setUp(() {
    if (sl.isRegistered<CommunityRepository>()) {
      sl.unregister<CommunityRepository>();
    }
    if (sl.isRegistered<CommunityCubit>()) sl.unregister<CommunityCubit>();
    if (sl.isRegistered<ChallengesRepository>()) {
      sl.unregister<ChallengesRepository>();
    }
    sl.registerSingleton<CommunityRepository>(_Repo());
    sl.registerFactory<CommunityCubit>(_FixedCommunity.new);
    sl.registerSingleton<ChallengesRepository>(_Challenges());
    if (sl.isRegistered<GamificationRepository>()) {
      sl.unregister<GamificationRepository>();
    }
    if (sl.isRegistered<FriendsCubit>()) sl.unregister<FriendsCubit>();
    sl.registerSingleton<GamificationRepository>(_Repo());
    sl.registerFactory<FriendsCubit>(_FixedFriends.new);
  });

  group('leaderboard member note', () {
    test('says how many members have points when some are missing', () {
      final state = LeaderboardState(
        community: _global,
        entries: _board,
        loading: false,
      );
      expect(state.rankedCount, 8);
      expect(
        state.coverageNote,
        startsWith('8 of 23 members have points this week.'),
      );
      expect(
        state.copyWith(category: () => ScoreCategory.fitness).coverageNote,
        startsWith('8 of 23 members have points in Fitness this week.'),
      );
    });

    test('stays quiet while pages remain or everyone is listed', () {
      expect(
        LeaderboardState(
          community: _global,
          entries: _board,
          hasMore: true,
        ).coverageNote,
        isNull,
      );
      expect(
        LeaderboardState(
          community: _global.copyWith(memberCount: 8),
          entries: _board,
        ).coverageNote,
        isNull,
      );
      expect(
        LeaderboardState(community: _global, entries: const []).coverageNote,
        isNull,
      );
    });
  });

  test('a running challenge counts its days', () {
    final c = _challenge('a', endsInDays: 1);
    final now = DateTime.now();
    expect(challengeDays(c), 7);
    expect(challengeDayLabel(c, now), 'Day 6 of 7');
    expect(challengeElapsed(c, now), closeTo((7 - 1.125) / 7, 0.01));
    expect(
      challengeSubtitle(c, now, withTimeLeft: false),
      'by @asha_runs · 4 people',
    );
  });

  final pages = <String, Widget Function()>{
    'hub': () => BlocProvider<GamificationCubit>(
      create: (_) => _FixedGamification(),
      child: const CommunityHubPage(),
    ),
    'leaderboard': () => const LeaderboardPage(community: _global),
    'challenges': () => BlocProvider(
      create: (_) => ChallengesCubit(_Challenges())..load(),
      child: const ChallengesPage(),
    ),
    'friends': () => const FriendsPage(myUsername: kDemoUsername),
    'badges': () => const BadgesPage(),
    'points': () => const PointsHistoryPage(),
  };

  for (final (name, shot, tab) in [
    ('hub', 'arena', 3),
    ('leaderboard', 'leaderboard', null),
    ('challenges', 'challenges', null),
    ('badges', 'achievements', null),
  ]) {
    testWidgets('readme: $shot', (tester) async {
      final page = pages[name]!();
      await pumpReadmePage(
        tester,
        tab == null
            ? page
            : Scaffold(
                extendBody: true,
                body: page,
                bottomNavigationBar: readmeNavBar(tab),
              ),
      );
      await captureReadmeShot(tester, shot);
    }, skip: !readmeShots);
  }

  for (final MapEntry(key: name, value: build) in pages.entries) {
    for (final c in _cases) {
      final tag =
          '${name}_${c.width.toInt()}_${c.scale}${c.dark ? '_dark' : ''}';
      testWidgets('$tag lays out whole', (tester) async {
        if (_writeShots) await tester.runAsync(loadAllFonts);
        await pumpPage(
          tester,
          build(),
          size: Size(c.width, 1800),
          textScale: c.scale,
          theme: c.dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        );
        await settle(tester);
        expect(takeAllExceptions(tester), isEmpty);
        expect(
          truncatedTexts(tester, previews: {'longest_username_20c'}),
          isEmpty,
        );
        if (_writeShots) {
          await _capture(tester, 'build/arena_shots/$tag.png');
        }
      });
    }
  }
}
