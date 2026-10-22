import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/core/utils/load_timeout.dart';
import 'package:vital_up/features/community/domain/entities/community.dart';
import 'package:vital_up/features/community/domain/entities/community_award.dart';
import 'package:vital_up/features/community/domain/entities/community_standing.dart';
import 'package:vital_up/features/community/domain/entities/friend.dart';
import 'package:vital_up/features/community/domain/entities/leaderboard_entry.dart';
import 'package:vital_up/features/community/domain/repositories/community_repository.dart';

class CommunityState extends Equatable {
  final bool loading;
  final List<Community>? communities;
  final CommunitySettings settings;

  /// Friends and pending requests, for the Friends section.
  final List<Friend> friends;

  /// The caller and their friends ranked on all-time points, best first.
  final List<LeaderboardEntry> friendsRanking;

  /// The caller's rank this week in each community, by community id.
  final Map<String, CommunityStanding> standings;

  /// Last month's winners: Global first, then the caller's city.
  final List<CommunityWinners> champions;
  final bool failed;

  /// Community ids with a join/leave in flight.
  final Set<String> busy;

  /// One-off message for a failed action (SnackBar).
  final String? message;

  const CommunityState({
    this.loading = true,
    this.communities,
    this.settings = const CommunitySettings(),
    this.friends = const [],
    this.friendsRanking = const [],
    this.standings = const {},
    this.champions = const [],
    this.failed = false,
    this.busy = const {},
    this.message,
  });

  Community? get global =>
      communities?.where((c) => c.type == CommunityType.global).firstOrNull;

  Community? get local =>
      communities?.where((c) => c.type == CommunityType.local).firstOrNull;

  int get friendCount =>
      friends.where((f) => f.status == FriendStatus.accepted).length;

  int get incomingRequests =>
      friends.where((f) => f.status == FriendStatus.incoming).length;

  List<Community> get joined => [
    for (final c in communities ?? const <Community>[])
      if (c.type == CommunityType.interest && c.isMember) c,
  ];

  List<Community> get discover => [
    for (final c in communities ?? const <Community>[])
      if (c.type == CommunityType.interest && !c.isMember) c,
  ];

  CommunityState copyWith({
    bool? loading,
    List<Community>? communities,
    CommunitySettings? settings,
    List<Friend>? friends,
    List<LeaderboardEntry>? friendsRanking,
    Map<String, CommunityStanding>? standings,
    List<CommunityWinners>? champions,
    bool? failed,
    Set<String>? busy,
    String? message,
  }) => CommunityState(
    loading: loading ?? this.loading,
    communities: communities ?? this.communities,
    settings: settings ?? this.settings,
    friends: friends ?? this.friends,
    friendsRanking: friendsRanking ?? this.friendsRanking,
    standings: standings ?? this.standings,
    champions: champions ?? this.champions,
    failed: failed ?? this.failed,
    busy: busy ?? this.busy,
    message: message,
  );

  @override
  List<Object?> get props => [
    loading,
    communities,
    settings,
    friends,
    friendsRanking,
    standings,
    champions,
    failed,
    busy,
    message,
  ];
}

class CommunityCubit extends Cubit<CommunityState> {
  final CommunityRepository _repository;

  CommunityCubit(this._repository) : super(const CommunityState());

  @override
  void emit(CommunityState state) {
    // Requests can finish after the page closed (back during a save).
    if (!isClosed) super.emit(state);
  }

  Future<void> load() async {
    emit(state.copyWith(loading: true, failed: false));
    try {
      // Friends and ranks are optional: the hub still works without them.
      final (
        communities,
        settings,
        friends,
        friendsRanking,
        standings,
      ) = await (
        _repository.getCommunities(),
        _repository.getSettings(),
        _repository.getFriends().orFallback(state.friends),
        _repository
            .getFriendRanks(
              Community.friendsOf(state.friendCount),
              period: LeaderboardPeriod.all,
            )
            .orFallback(state.friendsRanking),
        _repository.getMyStandings().orFallback(state.standings),
      ).wait.withLoadTimeout();
      if (isClosed) return;
      emit(
        state.copyWith(
          loading: false,
          communities: communities,
          settings: settings,
          friends: friends,
          friendsRanking: friendsRanking,
          standings: standings,
        ),
      );
      await _loadChampions();
    } catch (e) {
      debugPrint('Communities failed to load: $e');
      if (isClosed) return;
      emit(state.copyWith(loading: false, failed: true));
    }
  }

  /// Fast path for Settings: loads only settings without the full Arena payload.
  Future<void> loadSettings() async {
    emit(state.copyWith(loading: true, failed: false));
    try {
      final settings = await _repository.getSettings().withLoadTimeout();
      if (isClosed) return;
      emit(state.copyWith(loading: false, settings: settings));
    } catch (e) {
      debugPrint('Leaderboard settings failed to load: $e');
      if (isClosed) return;
      emit(state.copyWith(loading: false, failed: true));
    }
  }

  /// Optional: the Arena shows without it, keeping the last copy.
  Future<void> _loadChampions() async {
    final boards = [?state.global, ?state.local];
    try {
      final champions = await Future.wait([
        for (final period in AwardPeriod.values)
          for (final c in boards)
            _repository
                .getCommunityWinners(c, period)
                .then(
                  (w) => CommunityWinners(
                    community: c,
                    period: period,
                    winners: w,
                  ),
                ),
      ]).withLoadTimeout();
      if (isClosed) return;
      emit(state.copyWith(champions: champions));
    } catch (e) {
      debugPrint('Champions failed to load: $e');
    }
  }

  Future<void> toggleMembership(Community community) async {
    if (!community.canJoin || state.busy.contains(community.id)) return;
    final joining = !community.isMember;
    emit(state.copyWith(busy: {...state.busy, community.id}));
    try {
      if (joining) {
        await _repository.join(community);
      } else {
        await _repository.leave(community);
      }
      if (isClosed) return;
      emit(
        state.copyWith(
          busy: {...state.busy}..remove(community.id),
          communities: [
            for (final c in state.communities ?? const <Community>[])
              c.id == community.id
                  ? c.copyWith(
                      isMember: joining,
                      memberCount: c.memberCount + (joining ? 1 : -1),
                    )
                  : c,
          ],
        ),
      );
    } catch (e) {
      debugPrint('Membership change failed: $e');
      if (isClosed) return;
      emit(
        state.copyWith(
          busy: {...state.busy}..remove(community.id),
          message: userMessage(
            e,
            fallback: joining
                ? "Couldn't join. Try again."
                : "Couldn't leave. Try again.",
          ),
        ),
      );
    }
  }

  /// Returns false when saving failed. Offline, the change is queued and
  /// counts as saved.
  Future<bool> setCity(String city, String countryCode) async {
    final c = sanitizeText(city, maxLength: InputLimits.city);
    final cc = sanitizeText(countryCode).toUpperCase();
    final previous = state.settings;
    emit(
      state.copyWith(
        settings: CommunitySettings(
          username: previous.username,
          city: c.isEmpty ? null : c,
          countryCode: cc.isEmpty ? null : cc,
          leaderboardVisible: previous.leaderboardVisible,
        ),
      ),
    );
    try {
      await _repository.setCity(city, countryCode).withLoadTimeout();
      if (state.communities != null) {
        await load();
      } else {
        await loadSettings();
      }
      return true;
    } catch (e) {
      debugPrint('Setting city failed: $e');
      if (isClosed) return false;
      emit(state.copyWith(settings: previous));
      return false;
    }
  }

  Future<void> setLeaderboardVisible(bool visible) async {
    final previous = state.settings;
    emit(
      state.copyWith(
        settings: CommunitySettings(
          username: previous.username,
          city: previous.city,
          countryCode: previous.countryCode,
          leaderboardVisible: visible,
        ),
      ),
    );
    try {
      await _repository.setLeaderboardVisible(visible);
    } catch (e) {
      debugPrint('Updating leaderboard visibility failed: $e');
      if (isClosed) return;
      emit(
        state.copyWith(
          settings: previous,
          message: userMessage(
            e,
            fallback: "Couldn't update your visibility. Try again.",
          ),
        ),
      );
    }
  }
}
