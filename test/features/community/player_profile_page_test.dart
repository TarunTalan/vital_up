import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/widgets/user_avatar.dart';
import 'package:vital_up/features/community/domain/entities/common_community_rank.dart';
import 'package:vital_up/features/community/domain/entities/community.dart';
import 'package:vital_up/features/community/domain/entities/community_award.dart';
import 'package:vital_up/features/community/domain/entities/community_standing.dart';
import 'package:vital_up/features/community/domain/entities/friend.dart';
import 'package:vital_up/features/community/domain/entities/leaderboard_entry.dart';
import 'package:vital_up/features/community/domain/entities/player_profile.dart';
import 'package:vital_up/features/community/domain/repositories/community_repository.dart';
import 'package:vital_up/features/community/presentation/cubit/friends_cubit.dart';
import 'package:vital_up/features/community/presentation/pages/player_profile_page.dart';
import 'package:vital_up/features/gamification/domain/entities/game_badge.dart';
import 'package:vital_up/features/gamification/domain/entities/score_category.dart';
import 'package:vital_up/features/community/presentation/widgets/award_widgets.dart';

import '../../helpers/pump_app.dart';

Finder _semanticsLabel(String label) => find.byWidgetPredicate(
  (w) => w is Semantics && w.properties.label == label,
);

class _MockRepo implements CommunityRepository {
  @override
  Future<(List<Community>, CommunitySettings)?> savedHub() async => null;

  List<Friend> friendsList = [];
  PlayerProfile? profileToReturn;
  List<CommunityAward> awards = [];
  String? awardsAskedFor;

  @override
  Future<List<Community>> getCommunities() async => const [];
  @override
  Future<void> join(Community community) async {}
  @override
  Future<void> leave(Community community) async {}
  @override
  Future<CommunitySettings> getSettings() async => const CommunitySettings();
  @override
  Future<void> setCity(String city, String countryCode) async {}
  @override
  Future<void> setLeaderboardVisible(bool visible) async {}
  @override
  Future<List<LeaderboardEntry>> getLeaderboard(
    Community community, {
    required LeaderboardPeriod period,
    ScoreCategory? category,
    int limit = 50,
    int offset = 0,
  }) async => const [];
  @override
  Future<List<Friend>> getFriends() async => friendsList;
  @override
  Future<bool> sendFriendRequest(String username) async => false;
  @override
  Future<void> respondToRequest(Friend friend, {required bool accept}) async {}
  @override
  Future<void> removeFriend(Friend friend) async {}
  @override
  Future<PlayerProfile> getPlayerProfile(String userId) async {
    if (profileToReturn != null) return profileToReturn!;
    throw const PlayerProfileException('not_friends');
  }

  @override
  Future<PlayerProfile> getMyProfile() async => throw UnimplementedError();
  @override
  Future<void> sendCheer(String userId) async {}
  @override
  Future<LeaderboardEntry?> getMyRank(
    Community community, {
    required LeaderboardPeriod period,
    ScoreCategory? category,
  }) async => null;
  @override
  Future<List<CommonCommunityRank>> getCommonCommunityRanks(
    String friendUserId,
  ) async => const [];
  @override
  Future<List<LeaderboardEntry>> getFriendRanks(
    Community community, {
    required LeaderboardPeriod period,
    ScoreCategory? category,
  }) async => const [];
  @override
  Future<Map<String, CommunityStanding>> getMyStandings({
    LeaderboardPeriod period = LeaderboardPeriod.week,
  }) async => const {};
  @override
  Future<List<AwardWinner>> getCommunityWinners(
    Community community,
    AwardPeriod period,
  ) async => const [];
  @override
  Future<List<CommunityAward>> getPlayerAwards([String? userId]) async {
    awardsAskedFor = userId;
    return awards;
  }
}

void main() {
  late _MockRepo mockRepo;

  setUp(() {
    mockRepo = _MockRepo();
    if (sl.isRegistered<CommunityRepository>()) {
      sl.unregister<CommunityRepository>();
    }
    sl.registerSingleton<CommunityRepository>(mockRepo);

    if (sl.isRegistered<FriendsCubit>()) {
      sl.unregister<FriendsCubit>();
    }
    sl.registerFactory<FriendsCubit>(() => FriendsCubit(mockRepo));
  });

  tearDown(() {
    if (sl.isRegistered<CommunityRepository>()) {
      sl.unregister<CommunityRepository>();
    }
    if (sl.isRegistered<FriendsCubit>()) {
      sl.unregister<FriendsCubit>();
    }
  });

  Future<void> pumpProfile(
    WidgetTester tester, {
    String userId = 'u42',
    String username = 'alex_fit',
    int level = 5,
    double textScale = 1.0,
  }) async {
    await pumpPage(
      tester,
      BlocProvider<FriendsCubit>(
        create: (_) => FriendsCubit(mockRepo)..load(),
        child: PlayerProfilePage(
          userId: userId,
          username: username,
          level: level,
        ),
      ),
      textScale: textScale,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  PlayerProfile profile({
    bool friend = true,
    bool private = false,
    List<GameBadge> badges = const [],
  }) => PlayerProfile(
    userId: 'u42',
    username: 'alex_fit',
    level: 5,
    totalPoints: 3450,
    currentStreak: 12,
    longestStreak: 20,
    badgeCount: 4,
    categoryPoints: const {ScoreCategory.fitness: 2000},
    cheeredToday: false,
    recentBadges: badges,
    isFriend: friend,
    isPrivate: private,
  );

  const weekWarrior = GameBadge(
    code: 'streak_7',
    name: 'Week Warrior',
    description: 'Keep a 7-day streak',
    iconKey: 'streak_7',
  );

  testWidgets('who they are, then Add friend for a member', (tester) async {
    mockRepo.profileToReturn = profile(friend: false, badges: [weekWarrior]);
    await pumpProfile(tester);

    final avatar = tester.widget<UserAvatar>(find.byType(UserAvatar));
    expect(avatar.username, 'alex_fit');
    expect(find.text('@alex_fit'), findsOneWidget);
    expect(find.text('Level 5 · Committed'), findsOneWidget);
    expect(find.text('Add friend'), findsOneWidget);
    expect(
      find.text('Friends can cheer, compare and challenge each other.'),
      findsOneWidget,
    );
    // One stats card, then their badges; points by area are for friends.
    expect(find.text('3,450'), findsOneWidget);
    expect(find.text('12 days'), findsOneWidget);
    expect(find.text('Streak'), findsOneWidget);
    expect(find.byTooltip('Week Warrior'), findsOneWidget);
    expect(find.text('POINTS BY AREA'), findsNothing);
    expect(find.text('Challenge'), findsNothing);
    expect(find.byTooltip('More'), findsNothing);
  });

  testWidgets('a friend: Challenge, Cheer, Compare; Remove in the menu', (
    tester,
  ) async {
    mockRepo.friendsList = [
      const Friend(
        userId: 'u42',
        username: 'alex_fit',
        level: 5,
        status: FriendStatus.accepted,
      ),
    ];
    mockRepo.profileToReturn = profile();
    await pumpProfile(tester);

    expect(find.text('Challenge'), findsOneWidget);
    expect(find.text('Cheer'), findsOneWidget);
    expect(find.text('Compare'), findsOneWidget);
    expect(find.text('POINTS BY AREA'), findsOneWidget);
    expect(find.text('Add friend'), findsNothing);
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    expect(find.text('Remove friend'), findsOneWidget);
  });

  testWidgets('a hidden member shows only who they are', (tester) async {
    mockRepo.profileToReturn = profile(friend: false, private: true);
    await pumpProfile(tester, username: 'quiet_one', level: 4);

    expect(find.textContaining('keeps their stats private'), findsOneWidget);
    expect(find.text('3,450'), findsNothing);
    expect(find.text('Add friend'), findsOneWidget);
  });

  testWidgets('awards: the best one, the full list a tap away', (tester) async {
    mockRepo.profileToReturn = profile(friend: false);
    mockRepo.awards = [
      CommunityAward(
        id: 1,
        communityId: 'delhi',
        communityName: 'Delhi',
        communityType: CommunityType.local,
        period: AwardPeriod.week,
        periodStart: DateTime(2026, 10, 5),
        place: 1,
        points: 300,
        players: 12,
      ),
      CommunityAward(
        id: 2,
        communityId: 'global',
        communityName: 'Global',
        communityType: CommunityType.global,
        period: AwardPeriod.month,
        periodStart: DateTime(2026, 9),
        place: 2,
        points: 900,
        players: 400,
      ),
    ];
    await pumpProfile(tester);

    expect(mockRepo.awardsAskedFor, 'u42');
    expect(find.text('AWARDS (2)'), findsOneWidget);
    expect(find.text('2nd in Global'), findsOneWidget);
    expect(_semanticsLabel('1 trophy'), findsOneWidget);
    expect(_semanticsLabel('1 gold medal'), findsOneWidget);

    await tester.ensureVisible(find.text('2nd in Global'));
    await tester.tap(find.text('2nd in Global'));
    await tester.pumpAndSettle();
    expect(find.text('Awards'), findsOneWidget);
    expect(find.text('@alex_fit'), findsWidgets);
    // One section per period, newest first.
    final week = tester.getTopLeft(find.text('WEEK OF 5 OCT (1)'));
    final month = tester.getTopLeft(find.text('SEPTEMBER 2026 (1)'));
    expect(month.dy, greaterThan(week.dy));
    expect(find.text('1st in Delhi'), findsOneWidget);
  });

  for (final friend in [false, true]) {
    testWidgets('fits at the largest text (${friend ? 'friend' : 'member'})', (
      tester,
    ) async {
      if (friend) {
        mockRepo.friendsList = [
          const Friend(
            userId: 'u42',
            username: 'alex_fit',
            level: 5,
            status: FriendStatus.accepted,
          ),
        ];
      }
      mockRepo.profileToReturn = profile(friend: friend, badges: [weekWarrior]);
      await pumpProfile(tester, textScale: kMaxTextScale);
      expect(takeAllExceptions(tester), isEmpty);
      expect(truncatedTexts(tester), isEmpty);
    });
  }

  testWidgets('Badges page awards: one card however many, list a tap away', (
    tester,
  ) async {
    final communities = ['Global', 'Delhi', 'Runners', 'Yoga', 'Cyclists'];
    mockRepo.awards = [
      for (final (w, start) in [
        (0, DateTime(2026, 10, 5)),
        (1, DateTime(2026, 10, 12)),
      ])
        for (final (i, name) in communities.indexed)
          CommunityAward(
            id: w * 10 + i,
            communityId: name.toLowerCase(),
            communityName: name,
            communityType: i == 0
                ? CommunityType.global
                : CommunityType.interest,
            period: AwardPeriod.week,
            periodStart: start,
            place: 1,
            points: 500,
            players: 12,
          ),
    ];
    await pumpPage(
      tester,
      const Scaffold(body: SingleChildScrollView(child: MyCommunityAwards())),
      textScale: kMaxTextScale,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('AWARDS (10)'), findsOneWidget);
    // The summary only: best award and counts, not ten rows.
    expect(find.text('1st in Delhi'), findsNothing);
    expect(_semanticsLabel('10 gold medals'), findsOneWidget);
    expect(truncatedTexts(tester), isEmpty);

    await tester.tap(find.text('1st in Global'));
    await tester.pumpAndSettle();
    expect(find.text('Your awards'), findsOneWidget);
    expect(find.text('WEEK OF 12 OCT (5)'), findsOneWidget);
    expect(find.text('WEEK OF 5 OCT (5)'), findsOneWidget);
    expect(takeAllExceptions(tester), isEmpty);
    expect(truncatedTexts(tester), isEmpty);
  });
}
