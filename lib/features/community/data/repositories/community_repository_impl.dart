import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vital_up/features/community/data/datasources/community_remote_datasource.dart';
import 'package:vital_up/features/community/domain/entities/friend.dart';
import 'package:vital_up/features/community/domain/entities/community.dart';
import 'package:vital_up/features/community/domain/entities/leaderboard_entry.dart';
import 'package:vital_up/features/community/domain/repositories/community_repository.dart';
import 'package:vital_up/features/gamification/domain/entities/score_category.dart';

class CommunityRepositoryImpl implements CommunityRepository {
  final CommunityRemoteDataSource _remote;

  CommunityRepositoryImpl(this._remote);

  @override
  Future<List<Community>> getCommunities() async => [
    for (final r in await _remote.fetchCommunities()) Community.fromJson(r),
  ];

  @override
  Future<void> join(Community community) => _remote.join(community.id);

  @override
  Future<void> leave(Community community) => _remote.leave(community.id);

  @override
  Future<CommunitySettings> getSettings() async {
    final row = await _remote.fetchSettings();
    return CommunitySettings(
      username: row?['username'] as String?,
      city: row?['city'] as String?,
      countryCode: row?['country_code'] as String?,
      leaderboardVisible: row?['leaderboard_visible'] as bool? ?? true,
    );
  }

  @override
  Future<void> setCity(String city, String countryCode) =>
      _remote.setCity(city.trim(), countryCode.trim());

  @override
  Future<void> setLeaderboardVisible(bool visible) =>
      _remote.setLeaderboardVisible(visible);

  @override
  Future<List<LeaderboardEntry>> getLeaderboard(
    Community community, {
    required LeaderboardPeriod period,
    ScoreCategory? category,
    int limit = 50,
    int offset = 0,
  }) async {
    if (community.type == CommunityType.friends) {
      // Fetched whole, so there is never a next page.
      return offset > 0 ? const [] : _friendsBoard(period, category);
    }
    return [
      for (final r in await _remote.fetchLeaderboard(
        communityId: community.id,
        period: period.name,
        category: category?.name,
        limit: limit,
        offset: offset,
      ))
        LeaderboardEntry.fromJson(r),
    ];
  }

  @override
  Future<LeaderboardEntry?> getMyRank(
    Community community, {
    required LeaderboardPeriod period,
    ScoreCategory? category,
  }) async {
    if (community.type == CommunityType.friends) {
      return (await _friendsBoard(
        period,
        category,
      )).where((e) => e.isMe).firstOrNull;
    }
    final row = await _remote.fetchMyRank(
      communityId: community.id,
      period: period.name,
      category: category?.name,
    );
    return row == null ? null : LeaderboardEntry.fromJson(row);
  }

  Future<List<LeaderboardEntry>> _friendsBoard(
    LeaderboardPeriod period,
    ScoreCategory? category,
  ) async => [
    for (final r in await _remote.fetchFriendsLeaderboard(
      period: period.name,
      category: category?.name,
    ))
      LeaderboardEntry.fromJson(r),
  ];

  @override
  Future<List<Friend>> getFriends() async => [
    for (final r in await _remote.fetchFriends()) Friend.fromJson(r),
  ];

  @override
  Future<bool> sendFriendRequest(String username) async {
    final name = username.trim();
    if (name.isEmpty || name == '@') {
      throw const FriendRequestException('Enter a username.');
    }
    try {
      return await _remote.sendFriendRequest(name) == 'accepted';
    } on PostgrestException catch (e) {
      throw FriendRequestException.fromServer(e.message);
    }
  }

  @override
  Future<void> respondToRequest(Friend friend, {required bool accept}) async {
    try {
      await _remote.respondToRequest(friend.userId, accept);
    } on PostgrestException catch (e) {
      throw FriendRequestException.fromServer(e.message);
    }
  }

  @override
  Future<void> removeFriend(Friend friend) =>
      _remote.removeFriend(friend.userId);
}
