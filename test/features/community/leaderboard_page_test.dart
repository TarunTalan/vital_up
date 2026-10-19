import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/features/challenges/data/challenges_repository.dart';
import 'package:vital_up/features/challenges/presentation/challenges_cubit.dart';
import 'package:vital_up/features/challenges/presentation/widgets/challenge_tile.dart';
import 'package:vital_up/features/community/domain/entities/community.dart';
import 'package:vital_up/features/community/domain/entities/community_award.dart';
import 'package:vital_up/features/community/domain/entities/leaderboard_entry.dart';
import 'package:vital_up/features/community/domain/repositories/community_repository.dart';
import 'package:vital_up/features/community/presentation/pages/leaderboard_page.dart';
import 'package:vital_up/features/gamification/domain/entities/score_category.dart';

LeaderboardEntry _entry(int rank, {String? id, bool isMe = false}) =>
    LeaderboardEntry(
      rank: rank,
      userId: id ?? 'u$rank',
      username: id ?? 'player$rank',
      points: 1000 - rank,
      level: 2,
      isMe: isMe,
    );

class _FakeRepo implements CommunityRepository {
  final List<LeaderboardEntry> board;
  final List<LeaderboardEntry> friends;
  final List<AwardWinner> winners;
  final winnersAsked = <AwardPeriod>[];
  int joins = 0;

  _FakeRepo({
    required this.board,
    this.friends = const [],
    this.winners = const [],
  });

  @override
  Future<List<AwardWinner>> getCommunityWinners(
    Community community,
    AwardPeriod period,
  ) async {
    winnersAsked.add(period);
    return winners;
  }

  @override
  Future<List<LeaderboardEntry>> getLeaderboard(
    Community community, {
    required LeaderboardPeriod period,
    ScoreCategory? category,
    int limit = 50,
    int offset = 0,
  }) async => offset > 0 ? const [] : board;

  @override
  Future<LeaderboardEntry?> getMyRank(
    Community community, {
    required LeaderboardPeriod period,
    ScoreCategory? category,
  }) async => null;

  @override
  Future<List<LeaderboardEntry>> getFriendRanks(
    Community community, {
    required LeaderboardPeriod period,
    ScoreCategory? category,
  }) async => friends;

  @override
  Future<void> join(Community community) async => joins++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoChallenges implements ChallengesRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _runners = Community(
  id: 'run',
  slug: 'runners',
  name: 'Runners',
  type: CommunityType.interest,
  iconKey: 'runners',
  description: 'People who run',
  memberCount: 340,
  isMember: true,
);

void main() {
  late _FakeRepo repo;

  void register(_FakeRepo r) {
    repo = r;
    if (sl.isRegistered<CommunityRepository>()) {
      sl.unregister<CommunityRepository>();
    }
    sl.registerSingleton<CommunityRepository>(repo);
  }

  tearDown(() {
    if (sl.isRegistered<CommunityRepository>()) {
      sl.unregister<CommunityRepository>();
    }
  });

  Future<void> pump(WidgetTester tester, Community community) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: LeaderboardPage(community: community),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('top ten first, then you and friends further down', (
    tester,
  ) async {
    register(
      _FakeRepo(
        board: [for (var r = 1; r <= 30; r++) _entry(r)],
        friends: [
          _entry(5),
          _entry(24),
          _entry(40, id: 'me', isMe: true),
        ],
      ),
    );
    await pump(tester, _runners);

    expect(find.text('player10'), findsOneWidget);
    expect(find.text('player11'), findsNothing);
    // Friend already in the top ten isn't repeated below.
    expect(find.text('player5'), findsOneWidget);
    expect(find.text('Friend · Level 2'), findsNWidgets(2));
    await tester.scrollUntilVisible(
      find.text('me (you)'),
      200,
      scrollable: find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      ),
    );
    expect(find.text('YOU AND YOUR FRIENDS'), findsOneWidget);
    expect(find.text('player24'), findsOneWidget);
    expect(find.text('40'), findsOneWidget);

    await tester.tap(find.text('Show more'));
    await tester.pumpAndSettle();
    expect(find.text('player30'), findsOneWidget);
    // Now on the board itself, so listed once, not again below.
    expect(find.text('player24'), findsOneWidget);
  });

  testWidgets('filters fit on one line and leave lives in the menu', (
    tester,
  ) async {
    register(_FakeRepo(board: [_entry(1)]));
    await pump(tester, _runners);

    expect(find.text('This week'), findsOneWidget);
    expect(find.text('Overall'), findsOneWidget);
    expect(find.text('Leave community'), findsNothing);
    expect(find.text('340 members · Total score'), findsOneWidget);

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    expect(find.text('People who run'), findsOneWidget);
    expect(find.text('Leave community'), findsOneWidget);

    await tester.tap(find.text('Leave community'));
    await tester.pumpAndSettle();
    expect(find.text('Leave Runners?'), findsOneWidget);
  });

  testWidgets('not a member: a join banner instead of a big button', (
    tester,
  ) async {
    register(_FakeRepo(board: [_entry(1)]));
    await pump(tester, _runners.copyWith(isMember: false));
    expect(find.text('Join to appear on this leaderboard'), findsOneWidget);
    await tester.tap(find.text('Join'));
    await tester.pumpAndSettle();
    expect(repo.joins, 1);
    expect(find.text('Join to appear on this leaderboard'), findsNothing);
  });

  testWidgets('a top-three challenge rank shows the medal alone', (
    tester,
  ) async {
    final now = DateTime.now();
    Widget tile(int rank) => BlocProvider(
      create: (_) => ChallengesCubit(_NoChallenges()),
      child: ChallengeTile(
        challenge: Challenge(
          id: 'c',
          metric: ChallengeMetric.workouts,
          startsAt: now.subtract(const Duration(days: 1)),
          endsAt: now.add(const Duration(days: 6)),
          creatorUsername: 'ann',
          myStatus: ParticipantStatus.joined,
          participants: 4,
          myScore: 3,
          myRank: rank,
        ),
      ),
    );
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: tile(1)),
      ),
    );
    expect(find.text('#1'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('Rank 1')), findsOneWidget);
    semantics.dispose();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: tile(4)),
      ),
    );
    expect(find.text('#4'), findsOneWidget);
  });

  testWidgets("the awards card sits under the live board", (tester) async {
    register(
      _FakeRepo(
        board: [for (var r = 1; r <= 3; r++) _entry(r)],
        winners: [
          AwardWinner(
            place: 1,
            userId: 'w1',
            username: 'champ',
            points: 700,
            level: 4,
            players: 20,
            periodStart: DateTime(2026, 10, 5),
          ),
        ],
      ),
    );
    await pump(tester, _runners);

    expect(repo.winnersAsked, [AwardPeriod.week]);
    await tester.scrollUntilVisible(
      find.text('Weekly medals'),
      200,
      scrollable: find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      ),
    );
    expect(find.text('Last winners · Week of 5 Oct'), findsOneWidget);
    expect(find.textContaining("week's medals"), findsOneWidget);
    expect(find.byTooltip('How awards work'), findsOneWidget);
    expect(find.text('@champ'), findsOneWidget);
    expect(find.text('700 pts'), findsOneWidget);
  });
}
