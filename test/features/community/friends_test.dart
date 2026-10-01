import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/features/community/domain/entities/community.dart';
import 'package:vital_up/features/community/domain/entities/friend.dart';
import 'package:vital_up/features/community/domain/entities/leaderboard_entry.dart';

void main() {
  test('server error codes map to friendly messages', () {
    expect(
      FriendRequestException.fromServer('user_not_found').message,
      'No one has that username.',
    );
    expect(
      FriendRequestException.fromServer('ERROR: already_friends (P0001)').message,
      "You're already friends.",
    );
    expect(
      FriendRequestException.fromServer('something else').message,
      "Couldn't send the request. Try again.",
    );
  });

  test('get_friends rows parse with their status', () {
    final f = Friend.fromJson({
      'user_id': 'u2',
      'username': 'bob',
      'avatar_url': null,
      'level': 3,
      'status': 'incoming',
    });
    expect(f.status, FriendStatus.incoming);
    expect(f.level, 3);
  });

  test('friends community counts the caller and ranks on the total', () {
    final c = Community.friendsOf(4);
    expect(c.type, CommunityType.friends);
    expect(c.memberCount, 5);
    expect(c.canJoin, isFalse);
    expect(c.rankedOn, 'Total score');
  });

  test('friends with no points come back unranked', () {
    final e = LeaderboardEntry.fromJson({
      'rank': null,
      'user_id': 'u3',
      'username': 'carol',
      'points': 0,
      'level': 1,
      'is_me': false,
    });
    expect(e.rank, isNull);
  });
}
