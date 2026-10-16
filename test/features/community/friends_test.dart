import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/features/community/domain/entities/community.dart';
import 'package:vital_up/features/community/domain/entities/friend.dart';
import 'package:vital_up/features/community/domain/entities/leaderboard_entry.dart';
import 'package:vital_up/features/community/presentation/cubit/friends_cubit.dart';

void main() {
  test('server error codes map to friendly messages', () {
    expect(
      FriendRequestException.fromServer('user_not_found').message,
      'No one has that username.',
    );
    expect(
      FriendRequestException.fromServer(
        'ERROR: already_friends (P0001)',
      ).message,
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

  test('rankedFriendsAndSelf includes self position and sorts rankwise', () {
    const friendA = Friend(
      userId: 'u1',
      username: 'alice',
      level: 5,
      status: FriendStatus.accepted,
    );
    const friendB = Friend(
      userId: 'u2',
      username: 'bob',
      level: 3,
      status: FriendStatus.accepted,
    );

    const state = FriendsState(
      friends: [friendA, friendB],
      rankedMembers: [
        LeaderboardEntry(
          rank: 1,
          userId: 'u1',
          username: 'alice',
          points: 1500,
          level: 5,
          isMe: false,
        ),
        LeaderboardEntry(
          rank: 2,
          userId: 'me',
          username: 'myself',
          points: 1200,
          level: 4,
          isMe: true,
        ),
        LeaderboardEntry(
          rank: 3,
          userId: 'u2',
          username: 'bob',
          points: 800,
          level: 3,
          isMe: false,
        ),
      ],
    );

    final ranked = state.rankedFriendsAndSelf;
    expect(ranked.length, 3);

    // Rank 1 is Alice
    expect(ranked[0].rank, 1);
    expect(ranked[0].username, 'alice');
    expect(ranked[0].isMe, isFalse);

    // Rank 2 is Current user (Self position)
    expect(ranked[1].rank, 2);
    expect(ranked[1].username, 'myself');
    expect(ranked[1].isMe, isTrue);

    // Rank 3 is Bob
    expect(ranked[2].rank, 3);
    expect(ranked[2].username, 'bob');
    expect(ranked[2].isMe, isFalse);
  });
}
