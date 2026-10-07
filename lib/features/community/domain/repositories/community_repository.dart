import 'package:vital_up/features/community/domain/entities/community.dart';
import 'package:vital_up/features/community/domain/entities/friend.dart';
import 'package:vital_up/features/community/domain/entities/leaderboard_entry.dart';
import 'package:vital_up/features/community/domain/entities/player_profile.dart';
import 'package:vital_up/features/gamification/domain/entities/score_category.dart';

/// The caller's leaderboard settings from their profile.
class CommunitySettings {
  final String? username;
  final String? city;
  final String? countryCode;
  final bool leaderboardVisible;

  const CommunitySettings({
    this.username,
    this.city,
    this.countryCode,
    this.leaderboardVisible = true,
  });
}

abstract class CommunityRepository {
  /// For actions that can't be queued and need the network now.
  static const offlineMessage = "You're offline. Try again when connected.";

  /// Global, the caller's local community and every interest community.
  Future<List<Community>> getCommunities();

  Future<void> join(Community community);

  Future<void> leave(Community community);

  Future<CommunitySettings> getSettings();

  /// Moves the caller into [city]'s local community; empty leaves it.
  Future<void> setCity(String city, String countryCode);

  Future<void> setLeaderboardVisible(bool visible);

  Future<List<LeaderboardEntry>> getLeaderboard(
    Community community, {
    required LeaderboardPeriod period,
    ScoreCategory? category,
    int limit = 50,
    int offset = 0,
  });

  /// Friends and pending requests either way.
  Future<List<Friend>> getFriends();

  /// Sends a request to [username] (accepting theirs if they asked first).
  /// Returns true when you're now friends, false when it's pending.
  /// Throws [FriendRequestException] with a user-facing message.
  Future<bool> sendFriendRequest(String username);

  Future<void> respondToRequest(Friend friend, {required bool accept});

  /// Unfriends, or cancels a request.
  Future<void> removeFriend(Friend friend);

  /// Profile of [userId]: the caller or an accepted friend. Online only.
  /// Throws [PlayerProfileException] with a user-facing message.
  Future<PlayerProfile> getPlayerProfile(String userId);

  /// The caller's own profile, in the same shape as a friend's.
  Future<PlayerProfile> getMyProfile();

  /// Cheers a friend (once per day). Online only.
  /// Throws [PlayerProfileException] with a user-facing message.
  Future<void> sendCheer(String userId);

  Future<LeaderboardEntry?> getMyRank(
    Community community, {
    required LeaderboardPeriod period,
    ScoreCategory? category,
  });
}
