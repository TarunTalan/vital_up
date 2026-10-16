import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/features/community/domain/entities/friend.dart';
import 'package:vital_up/features/community/domain/entities/leaderboard_entry.dart';
import 'package:vital_up/features/community/presentation/widgets/friends_quick_row.dart';

Friend _friend(String id) => Friend(
  userId: id,
  username: 'user-$id',
  level: 1,
  status: FriendStatus.accepted,
);

LeaderboardEntry _entry(String id, int? rank, {bool isMe = false}) =>
    LeaderboardEntry(
      rank: rank,
      userId: id,
      username: 'user-$id',
      points: 0,
      level: 1,
      isMe: isMe,
    );

void main() {
  test('friends and the caller follow the ranking', () {
    final chips = rankedFriendChips(
      [_friend('a'), _friend('b'), _friend('c')],
      [_entry('b', 1), _entry('me', 2, isMe: true), _entry('a', 3)],
    );
    expect([for (final c in chips) c.friend.userId], ['b', 'me', 'a', 'c']);
    expect([for (final c in chips) c.rank], [1, 2, 3, null]);
    expect(chips[1].isMe, isTrue);
  });

  test('without a ranking the friends keep their order', () {
    final chips = rankedFriendChips([_friend('a'), _friend('b')], const []);
    expect([for (final c in chips) c.friend.userId], ['a', 'b']);
    expect(chips.every((c) => !c.isMe), isTrue);
  });

  test('no friends means no strip, even with a ranking', () {
    expect(rankedFriendChips(const [], [_entry('me', 1, isMe: true)]), isEmpty);
  });

  test('removed friends left in a stale ranking are skipped', () {
    final chips = rankedFriendChips(
      [_friend('a')],
      [_entry('gone', 1), _entry('a', 2)],
    );
    expect([for (final c in chips) c.friend.userId], ['a']);
  });
}
