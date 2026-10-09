import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/utils/load_timeout.dart';
import 'package:vital_up/features/community/domain/entities/community.dart';
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
    this.loading = true,
    this.loadingMore = false,
    this.hasMore = false,
    this.failed = false,
  });

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
      final (entries, me) = await (
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
