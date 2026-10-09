import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/core/utils/load_timeout.dart';
import 'package:vital_up/features/community/domain/entities/community.dart';
import 'package:vital_up/features/community/domain/entities/friend.dart';
import 'package:vital_up/features/community/domain/repositories/community_repository.dart';

class CommunityState extends Equatable {
  final bool loading;
  final List<Community>? communities;
  final CommunitySettings settings;

  /// Friends and pending requests, for the Friends section.
  final List<Friend> friends;
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
    bool? failed,
    Set<String>? busy,
    String? message,
  }) => CommunityState(
    loading: loading ?? this.loading,
    communities: communities ?? this.communities,
    settings: settings ?? this.settings,
    friends: friends ?? this.friends,
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
    failed,
    busy,
    message,
  ];
}

class CommunityCubit extends Cubit<CommunityState> {
  final CommunityRepository _repository;

  CommunityCubit(this._repository) : super(const CommunityState());

  Future<void> load() async {
    emit(state.copyWith(loading: true, failed: false));
    try {
      final (communities, settings, friends) = await (
        _repository.getCommunities(),
        _repository.getSettings(),
        // Optional: the hub still works if friends fail to load.
        _repository.getFriends().orFallback(state.friends),
      ).wait.withLoadTimeout();
      if (isClosed) return;
      emit(
        state.copyWith(
          loading: false,
          communities: communities,
          settings: settings,
          friends: friends,
        ),
      );
    } catch (e) {
      debugPrint('Communities failed to load: $e');
      if (isClosed) return;
      emit(state.copyWith(loading: false, failed: true));
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
    try {
      await _repository.setCity(city, countryCode).withLoadTimeout();
      await load();
      return true;
    } catch (e) {
      debugPrint('Setting city failed: $e');
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
