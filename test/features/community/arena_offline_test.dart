import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/features/community/domain/entities/community.dart';
import 'package:vital_up/features/community/domain/entities/community_award.dart';
import 'package:vital_up/features/community/domain/entities/community_standing.dart';
import 'package:vital_up/features/community/domain/entities/friend.dart';
import 'package:vital_up/features/community/domain/entities/leaderboard_entry.dart';
import 'package:vital_up/features/gamification/domain/entities/score_category.dart';
import 'package:vital_up/features/community/domain/repositories/community_repository.dart';
import 'package:vital_up/features/community/presentation/cubit/community_cubit.dart';

const _global = Community(
  id: 'g',
  slug: 'global',
  name: 'Global',
  type: CommunityType.global,
  iconKey: 'global',
  isMember: true,
);

/// The server can't be reached (DNS fails); a saved Arena exists.
class _Unreachable implements CommunityRepository {
  final bool saved;
  _Unreachable({this.saved = true});

  @override
  Future<(List<Community>, CommunitySettings)?> savedHub() async => saved
      ? (const [_global], const CommunitySettings(username: 'tarun'))
      : null;

  static Future<T> _offline<T>() =>
      Future<T>.error(const SocketException('Failed host lookup'));

  @override
  Future<List<Community>> getCommunities() => _offline();
  @override
  Future<CommunitySettings> getSettings() => _offline();
  @override
  Future<List<Friend>> getFriends() => _offline();
  @override
  Future<List<LeaderboardEntry>> getFriendRanks(
    Community community, {
    required LeaderboardPeriod period,
    ScoreCategory? category,
  }) => _offline();
  @override
  Future<Map<String, CommunityStanding>> getMyStandings({
    LeaderboardPeriod period = LeaderboardPeriod.week,
  }) => _offline();
  @override
  Future<List<AwardWinner>> getCommunityWinners(
    Community community,
    AwardPeriod period,
  ) => _offline();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('unreachable server: the saved Arena shows, not an error', () async {
    final cubit = CommunityCubit(_Unreachable());
    final shown = <CommunityState>[];
    final sub = cubit.stream.listen(shown.add);
    await cubit.load();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    // The saved copy came before the network gave up.
    expect(shown.any((s) => s.communities?.single.id == 'g'), isTrue);
    expect(cubit.state.communities?.single.id, 'g');
    expect(cubit.state.settings.username, 'tarun');
    expect(cubit.state.loading, isFalse);
    await cubit.close();
  });

  test('nothing saved and unreachable: the error with Retry', () async {
    final cubit = CommunityCubit(_Unreachable(saved: false));
    await cubit.load();
    expect(cubit.state.communities, isNull);
    expect(cubit.state.failed, isTrue);
    await cubit.close();
  });
}
