import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/utils/load_timeout.dart';
import 'package:vital_up/features/community/domain/entities/community.dart';
import 'package:vital_up/features/community/domain/entities/community_award.dart';
import 'package:vital_up/features/community/domain/entities/leaderboard_entry.dart';
import 'package:vital_up/features/community/domain/repositories/community_repository.dart';
import 'package:vital_up/features/gamification/domain/entities/score_category.dart';

class LeaderboardState extends Equatable {
  final Community community;
  final LeaderboardPeriod period;

  /// Null ranks on the community's own categories (or the total).
  final ScoreCategory? category;
  final List<LeaderboardEntry>? entries;
  final LeaderboardEntry? me;

  /// The caller and their friends on this board with their real ranks,
  /// even below the loaded pages. Empty on the friends board itself.
  final List<LeaderboardEntry> friendRanks;

  /// Winners of the last finished week or month (matching [period]);
  /// empty for all time, the friends board, or too few players.
  final List<AwardWinner> pastWinners;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final bool failed;

  const LeaderboardState({
    required this.community,
    this.period = LeaderboardPeriod.week,
    this.category,
    this.entries,
    this.me,
    this.friendRanks = const [],
    this.pastWinners = const [],
    this.loading = true,
    this.loadingMore = false,
    this.hasMore = false,
    this.failed = false,
  });

  /// The award period shown with [period]; null for all time.
  AwardPeriod? get awardPeriod => switch (period) {
    LeaderboardPeriod.week => AwardPeriod.week,
    LeaderboardPeriod.month => AwardPeriod.month,
    LeaderboardPeriod.all => null,
  };

  /// Ids of the caller's friends ranked here, to tag their rows.
  Set<String> get friendIds => {
    for (final e in friendRanks)
      if (!e.isMe) e.userId,
  };

  /// Players with points this period, once every page is loaded (null
  /// while more pages remain).
  int? get rankedCount {
    final list = entries;
    if (list == null || hasMore) return null;
    return list.where((e) => e.rank != null).length;
  }

  /// Why the board lists fewer players than the community has members:
  /// only players with points this period show, and never ones who hide
  /// from leaderboards. Null when everyone is listed, on the friends board
  /// (it lists friends without points too) or before the whole board is in.
  String? get coverageNote {
    final ranked = rankedCount;
    final members = community.memberCount;
    if (ranked == null ||
        ranked == 0 ||
        ranked >= members ||
        community.type == CommunityType.friends) {
      return null;
    }
    final when = switch (period) {
      LeaderboardPeriod.week => 'this week',
      LeaderboardPeriod.month => 'this month',
      LeaderboardPeriod.all => 'so far',
    };
    final scoredIn = category == null ? '' : ' in ${category!.label}';
    return '$ranked of $members members have points$scoredIn $when. '
        "Members without points, or who hide from leaderboards, aren't "
        'listed.';
  }

  /// Category filters offered for this community.
  List<ScoreCategory> get categories => community.scoreCategories.length == 1
      ? const []
      : community.scoreCategories.isNotEmpty
      ? community.scoreCategories
      : ScoreCategory.scored;

  LeaderboardState copyWith({
    Community? community,
    LeaderboardPeriod? period,
    ScoreCategory? Function()? category,
    List<LeaderboardEntry>? entries,
    LeaderboardEntry? Function()? me,
    List<LeaderboardEntry>? friendRanks,
    List<AwardWinner>? pastWinners,
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    bool? failed,
  }) => LeaderboardState(
    community: community ?? this.community,
    period: period ?? this.period,
    category: category != null ? category() : this.category,
    entries: entries ?? this.entries,
    me: me != null ? me() : this.me,
    friendRanks: friendRanks ?? this.friendRanks,
    pastWinners: pastWinners ?? this.pastWinners,
    loading: loading ?? this.loading,
    loadingMore: loadingMore ?? this.loadingMore,
    hasMore: hasMore ?? this.hasMore,
    failed: failed ?? this.failed,
  );

  @override
  List<Object?> get props => [
    community,
    period,
    category,
    entries,
    me,
    friendRanks,
    pastWinners,
    loading,
    loadingMore,
    hasMore,
    failed,
  ];
}

class LeaderboardCubit extends Cubit<LeaderboardState> {
  final CommunityRepository _repository;

  static const pageSize = 50;

  /// Drops responses from a filter the user has already changed away from.
  int _request = 0;

  LeaderboardCubit(this._repository, Community community)
    : super(LeaderboardState(community: community));

  Future<void> load() async {
    final request = ++_request;
    emit(state.copyWith(loading: true, failed: false));
    try {
      final isFriendsBoard = state.community.type == CommunityType.friends;
      final awardPeriod = state.awardPeriod;
      final (entries, me, friendRanks, pastWinners) = await (
        _repository.getLeaderboard(
          state.community,
          period: state.period,
          category: state.category,
          limit: pageSize,
        ),
        _repository.getMyRank(
          state.community,
          period: state.period,
          category: state.category,
        ),
        // Optional: the board still shows without it.
        isFriendsBoard
            ? Future.value(const <LeaderboardEntry>[])
            : _repository
                  .getFriendRanks(
                    state.community,
                    period: state.period,
                    category: state.category,
                  )
                  .orFallback(const <LeaderboardEntry>[]),
        // Optional too.
        isFriendsBoard || awardPeriod == null
            ? Future.value(const <AwardWinner>[])
            : Future.sync(
                () => _repository.getCommunityWinners(
                  state.community,
                  awardPeriod,
                ),
              ).orFallback(const <AwardWinner>[]),
      ).wait.withLoadTimeout();
      if (isClosed || request != _request) return;
      emit(
        state.copyWith(
          loading: false,
          // A page request from the previous filter is dropped, so it
          // can't reset this itself.
          loadingMore: false,
          entries: entries,
          me: () => me,
          friendRanks: friendRanks,
          pastWinners: pastWinners,
          hasMore: entries.length == pageSize,
        ),
      );
    } catch (e) {
      debugPrint('Leaderboard failed to load: $e');
      if (isClosed || request != _request) return;
      emit(state.copyWith(loading: false, loadingMore: false, failed: true));
    }
  }

  Future<void> loadMore() async {
    final current = state.entries;
    if (current == null || !state.hasMore || state.loadingMore) return;
    final request = _request;
    emit(state.copyWith(loadingMore: true));
    try {
      final more = await _repository
          .getLeaderboard(
            state.community,
            period: state.period,
            category: state.category,
            limit: pageSize,
            offset: current.length,
          )
          .withLoadTimeout();
      if (isClosed || request != _request) return;
      // Ranks shift between pages (offset paging), so a player can come
      // back twice; keep the first copy.
      final seen = {for (final e in current) e.userId};
      emit(
        state.copyWith(
          loadingMore: false,
          entries: [
            ...current,
            for (final e in more)
              if (seen.add(e.userId)) e,
          ],
          hasMore: more.length == pageSize,
        ),
      );
    } catch (e) {
      debugPrint('Leaderboard page failed to load: $e');
      if (isClosed || request != _request) return;
      emit(state.copyWith(loadingMore: false));
    }
  }

  void setPeriod(LeaderboardPeriod period) {
    if (period == state.period) return;
    emit(state.copyWith(period: period));
    load();
  }

  void setCategory(ScoreCategory? category) {
    if (category == state.category) return;
    emit(state.copyWith(category: () => category));
    load();
  }

  /// After joining or leaving from the leaderboard page.
  void updateCommunity(Community community) {
    emit(state.copyWith(community: community));
    load();
  }
}
