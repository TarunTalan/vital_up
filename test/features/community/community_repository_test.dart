import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/cache/cache_store.dart';
import 'package:vital_up/core/network/connectivity_service.dart';
import 'package:vital_up/features/community/data/datasources/community_remote_datasource.dart';
import 'package:vital_up/features/community/data/repositories/community_repository_impl.dart';
import 'package:vital_up/features/community/domain/entities/community.dart';
import 'package:vital_up/features/community/domain/entities/friend.dart';
import 'package:vital_up/features/community/domain/entities/leaderboard_entry.dart';
import 'package:vital_up/features/community/domain/repositories/community_repository.dart';

Map<String, dynamic> _friendRow(String id) => {
  'user_id': id,
  'username': 'user-$id',
  'level': 2,
  'status': 'accepted',
};

class _FakeRemote implements CommunityRemoteDataSource {
  int friendFetches = 0;
  int communityFetches = 0;
  Object? failWith;

  /// What [removeFriend] / [setCity] report: sent (true) or queued.
  bool online = true;
  List<Map<String, dynamic>> friends = [_friendRow('a'), _friendRow('b')];

  @override
  String? get userId => 'me';

  @override
  String requireUser() => 'me';

  @override
  Future<List<Map<String, dynamic>>> fetchFriends() async {
    friendFetches++;
    if (failWith != null) throw failWith!;
    return [for (final f in friends) {...f}];
  }

  @override
  Future<List<Map<String, dynamic>>> fetchCommunities() async {
    communityFetches++;
    if (failWith != null) throw failWith!;
    return [
      {'id': 'g', 'slug': 'global', 'name': 'Everyone', 'type': 'global'},
      {'id': 'l', 'slug': 'local-x', 'name': 'Pune', 'type': 'local'},
    ];
  }

  int standingFetches = 0;
  int friendRankFetches = 0;

  @override
  Future<List<Map<String, dynamic>>> fetchMyStandings({
    required String period,
  }) async {
    standingFetches++;
    return [
      {
        'community_id': 'g',
        'rank': 12,
        'points': 340,
        'ranked_count': 900,
        'friend_count': 2,
      },
      {'community_id': 'l', 'rank': null, 'ranked_count': 4},
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> fetchCommunityFriendRanks({
    required String communityId,
    required String period,
    String? category,
  }) async {
    friendRankFetches++;
    return [
      {'rank': 3, 'user_id': 'a', 'username': 'ann', 'points': 90},
      {'rank': 40, 'user_id': 'me', 'username': 'me', 'is_me': true},
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> fetchFriendsLeaderboard({
    required String period,
    String? category,
  }) async => [
    {'rank': 1, 'user_id': 'b', 'username': 'bo', 'points': 50},
  ];

  @override
  Future<bool> removeFriend(String userId) async => online;

  @override
  Future<bool> setCity(String city, String countryCode) async => online;

  @override
  Future<void> respondToRequest(String requesterId, bool accept) async {
    if (failWith != null) throw failWith!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory dir;
  late _FakeRemote remote;
  late CommunityRepositoryImpl repo;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('community_cache');
    remote = _FakeRemote();
    repo = CommunityRepositoryImpl(
      remote,
      CacheStore(ConnectivityService(), directory: dir),
    );
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('friends are served from the cache while fresh', () async {
    expect((await repo.getFriends()).length, 2);
    expect((await repo.getFriends()).length, 2);
    expect(remote.friendFetches, 1);
  });

  test('without a cached copy an offline load still fails', () async {
    remote.failWith = const SocketException('Failed host lookup');
    expect(repo.getFriends(), throwsA(isA<SocketException>()));
  });

  test('removing a friend offline hides them from the cached list', () async {
    await repo.getFriends();
    remote.online = false;
    await repo.removeFriend(
      const Friend(
        userId: 'a',
        username: 'user-a',
        level: 2,
        status: FriendStatus.accepted,
      ),
    );
    final friends = await repo.getFriends();
    expect(friends.map((f) => f.userId), ['b']);
    expect(remote.friendFetches, 1);
  });

  test('a queued city change drops the old local community', () async {
    await repo.getCommunities();
    remote.online = false;
    await repo.setCity('Mumbai', 'in');
    final communities = await repo.getCommunities();
    expect(communities.any((c) => c.type == CommunityType.local), isFalse);
    expect(remote.communityFetches, 1);
  });

  test('answering a request offline explains why', () async {
    remote.failWith = const SocketException('Network is unreachable');
    expect(
      repo.respondToRequest(
        const Friend(
          userId: 'c',
          username: 'c',
          level: 1,
          status: FriendStatus.incoming,
        ),
        accept: true,
      ),
      throwsA(
        isA<FriendRequestException>().having(
          (e) => e.message,
          'message',
          CommunityRepository.offlineMessage,
        ),
      ),
    );
  });

  test('standings are keyed by community and cached', () async {
    final standings = await repo.getMyStandings();
    expect(standings['g']!.rank, 12);
    expect(standings['g']!.friendCount, 2);
    expect(standings['l']!.rank, isNull);
    await repo.getMyStandings();
    expect(remote.standingFetches, 1);
  });

  test('a friend change refetches standings and friend ranks', () async {
    const global = Community(
      id: 'g',
      slug: 'global',
      name: 'Everyone',
      type: CommunityType.global,
      iconKey: 'global',
    );
    await repo.getMyStandings();
    final ranks = await repo.getFriendRanks(
      global,
      period: LeaderboardPeriod.week,
    );
    expect([for (final e in ranks) e.rank], [3, 40]);
    expect(ranks.last.isMe, isTrue);

    await repo.removeFriend(
      const Friend(
        userId: 'a',
        username: 'ann',
        level: 1,
        status: FriendStatus.accepted,
      ),
    );
    await repo.getMyStandings();
    await repo.getFriendRanks(global, period: LeaderboardPeriod.week);
    expect(remote.standingFetches, 2);
    expect(remote.friendRankFetches, 2);
  });

  test('friend ranks on the friends board come from that board', () async {
    final ranks = await repo.getFriendRanks(
      Community.friendsOf(1),
      period: LeaderboardPeriod.all,
    );
    expect(ranks.single.username, 'bo');
    expect(remote.friendRankFetches, 0);
  });

  test('common communities use real ranks for both players', () async {
    final common = await repo.getCommonCommunityRanks('a');
    final global = common.firstWhere(
      (r) => r.community.type == CommunityType.global,
    );
    expect(global.friendRank, 3);
    expect(global.myRank, 40);
    // The friends board is always shared, even without the friend on it.
    expect(
      common.any((r) => r.community.type == CommunityType.friends),
      isTrue,
    );
    // Not a member of the local board, so it isn't compared.
    expect(common.any((r) => r.community.id == 'l'), isFalse);
  });
}
