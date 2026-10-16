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
import 'package:vital_up/features/community/presentation/widgets/public_profile_sheet.dart';
import 'package:vital_up/features/gamification/domain/entities/game_badge.dart';
import 'package:vital_up/features/gamification/domain/entities/score_category.dart';

Finder _semanticsLabel(String label) => find.byWidgetPredicate(
  (w) => w is Semantics && w.properties.label == label,
);

class _MockRepo implements CommunityRepository {
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

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: BlocProvider<FriendsCubit>(
          create: (_) => FriendsCubit(mockRepo)..load(),
          child: child,
        ),
      ),
    );
  }

  testWidgets(
    'PublicProfileSheet displays circular avatar and non-friend overview',
    (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          const PublicProfileSheet(
            username: 'alex_fit',
            level: 5,
            points: 1200,
            rank: 2,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Check user avatar is circular
      final avatar = tester.widget<UserAvatar>(find.byType(UserAvatar));
      expect(avatar.username, 'alex_fit');

      // Check circular container around avatar has no glow
      final avatarContainer = find
          .ancestor(
            of: find.byType(UserAvatar),
            matching: find.byType(Container),
          )
          .first;
      final containerWidget = tester.widget<Container>(avatarContainer);
      final boxDecoration = containerWidget.decoration as BoxDecoration;
      expect(boxDecoration.shape, BoxShape.circle);
      expect(boxDecoration.boxShadow, isNull);

      // Check username and level (single clean display, no duplicate capsule)
      expect(find.text('@alex_fit'), findsOneWidget);
      expect(find.textContaining('Level 5'), findsOneWidget);
      expect(find.text('Level 5 · Committed'), findsOneWidget);

      // Check active status indicator
      expect(find.textContaining('Active'), findsWidgets);

      // Check points, rank, and activity stats in overview card (3 stats)
      expect(find.text('Points'), findsOneWidget);
      expect(find.text('1,200'), findsOneWidget);
      expect(find.text('Rank'), findsOneWidget);
      expect(find.text('#2'), findsOneWidget);
      expect(find.text('Activity'), findsOneWidget);

      // Check Add Friend action
      expect(find.text('Add Friend'), findsOneWidget);
    },
  );

  testWidgets(
    'PublicProfileSheet displays full stats and challenge when already friends',
    (tester) async {
      mockRepo.friendsList = [
        const Friend(
          userId: 'u42',
          username: 'alex_fit',
          level: 5,
          status: FriendStatus.accepted,
        ),
      ];
      mockRepo.profileToReturn = const PlayerProfile(
        userId: 'u42',
        username: 'alex_fit',
        level: 5,
        totalPoints: 3450,
        currentStreak: 12,
        longestStreak: 20,
        badgeCount: 4,
        categoryPoints: {ScoreCategory.fitness: 2000},
        cheeredToday: false,
        recentBadges: [
          GameBadge(
            code: 'streak_7',
            name: 'Week Warrior',
            description: 'Keep a 7-day streak',
            iconKey: 'streak_7',
          ),
        ],
      );

      await tester.pumpWidget(
        buildTestableWidget(
          const PublicProfileSheet(
            userId: 'u42',
            username: 'alex_fit',
            level: 5,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Stats should be loaded
      expect(find.text('Total points'), findsOneWidget);
      expect(find.text('3,450'), findsOneWidget);
      expect(find.text('Badges'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);

      // Action buttons for friends should be present
      expect(find.text('Challenge'), findsOneWidget);
      expect(find.text('Cheer'), findsOneWidget);
      expect(find.text('Compare'), findsOneWidget);
    },
  );

  testWidgets('PublicProfileSheet shows the best award first', (tester) async {
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

    await tester.pumpWidget(
      buildTestableWidget(
        const PublicProfileSheet(userId: 'u42', username: 'alex_fit', level: 5),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(mockRepo.awardsAskedFor, 'u42');
    expect(find.text('2nd in Global'), findsOneWidget);
    expect(find.text('Monthly trophy · September 2026'), findsOneWidget);
    expect(_semanticsLabel('1 trophy'), findsOneWidget);
    expect(_semanticsLabel('1 gold medal'), findsOneWidget);
  });
}
