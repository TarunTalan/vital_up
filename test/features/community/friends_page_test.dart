import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/features/community/domain/entities/community.dart';
import 'package:vital_up/features/community/domain/entities/friend.dart';
import 'package:vital_up/features/community/domain/entities/leaderboard_entry.dart';
import 'package:vital_up/features/community/domain/entities/player_profile.dart';
import 'package:vital_up/features/community/domain/repositories/community_repository.dart';
import 'package:vital_up/features/community/presentation/cubit/friends_cubit.dart';
import 'package:vital_up/features/community/presentation/pages/friends_page.dart';
import 'package:vital_up/features/gamification/domain/entities/score_category.dart';

class _FakeRepo implements CommunityRepository {
  @override
  Future<(List<Community>, CommunitySettings)?> savedHub() async => null;

  List<Friend> friends = [];
  List<LeaderboardEntry> board = [];
  FriendRequestException? sendError;

  @override
  Future<List<Friend>> getFriends() async => friends;

  @override
  Future<PlayerProfile> getMyProfile() async =>
      throw const PlayerProfileException('offline');

  @override
  Future<List<LeaderboardEntry>> getLeaderboard(
    Community community, {
    required LeaderboardPeriod period,
    ScoreCategory? category,
    int limit = 50,
    int offset = 0,
  }) async => board;

  @override
  Future<bool> sendFriendRequest(String username) async {
    if (sendError != null) throw sendError!;
    return false;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Friend _friend(String id, FriendStatus status) =>
    Friend(userId: id, username: 'user_$id', level: 3, status: status);

void main() {
  late _FakeRepo repo;

  setUp(() {
    repo = _FakeRepo();
    if (sl.isRegistered<FriendsCubit>()) sl.unregister<FriendsCubit>();
    sl.registerFactory<FriendsCubit>(() => FriendsCubit(repo));
  });

  tearDown(() => sl.unregister<FriendsCubit>());

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const FriendsPage(myUsername: 'me_user'),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('no friends shows one empty card with add and invite', (
    tester,
  ) async {
    await pumpPage(tester);
    expect(find.text('No friends yet'), findsOneWidget);
    expect(find.text('Add a friend'), findsOneWidget);
    expect(find.text('Share invite'), findsOneWidget);
    expect(find.text('Send request'), findsNothing);
  });

  testWidgets('friends are listed by rank with no per-row buttons', (
    tester,
  ) async {
    repo.friends = [
      _friend('a', FriendStatus.accepted),
      _friend('b', FriendStatus.accepted),
      _friend('c', FriendStatus.outgoing),
    ];
    repo.board = const [
      LeaderboardEntry(
        rank: 1,
        userId: 'b',
        username: 'user_b',
        points: 900,
        level: 3,
      ),
      LeaderboardEntry(
        rank: 2,
        userId: 'a',
        username: 'user_a',
        points: 400,
        level: 3,
      ),
    ];
    await pumpPage(tester);

    expect(find.text('RANKED BY ALL-TIME POINTS'), findsOneWidget);
    final b = tester.getTopLeft(find.text('@user_b')).dy;
    final a = tester.getTopLeft(find.text('@user_a')).dy;
    expect(b, lessThan(a));
    expect(find.text('Level 3 · 900 pts'), findsOneWidget);
    expect(find.text('Challenge'), findsNothing);
    // Few friends: no search yet.
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('Sent 1'));
    await tester.pumpAndSettle();
    expect(find.text('@user_c'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('@user_a'), findsNothing);
  });

  testWidgets('opens on Requests while some are waiting', (tester) async {
    repo.friends = [
      _friend('a', FriendStatus.accepted),
      _friend('r', FriendStatus.incoming),
    ];
    await pumpPage(tester);
    expect(find.text('@user_r'), findsOneWidget);
    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
  });

  testWidgets('long lists get a search that filters by username', (
    tester,
  ) async {
    repo.friends = [
      for (final id in ['ann', 'bob', 'cat', 'dan', 'eve', 'fay'])
        _friend(id, FriendStatus.accepted),
    ];
    await pumpPage(tester);

    await tester.enterText(find.byType(TextField), 'EV');
    await tester.pumpAndSettle();
    expect(find.text('@user_eve'), findsOneWidget);
    expect(find.text('@user_ann'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No matches'), findsOneWidget);
  });

  testWidgets('the add sheet shows request errors under the field', (
    tester,
  ) async {
    repo.sendError = const FriendRequestException('No one has that username.');
    await pumpPage(tester);

    await tester.tap(find.byTooltip('Add a friend'));
    await tester.pumpAndSettle();
    expect(find.text('Send request'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'ghost');
    await tester.tap(find.text('Send request'));
    await tester.pumpAndSettle();

    expect(find.text('No one has that username.'), findsOneWidget);
    expect(find.text('Send request'), findsOneWidget);
  });
}
