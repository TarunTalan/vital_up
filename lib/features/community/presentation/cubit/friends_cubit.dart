import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/core/utils/load_timeout.dart';
import 'package:vital_up/features/community/domain/entities/community.dart';
import 'package:vital_up/features/community/domain/entities/friend.dart';
import 'package:vital_up/features/community/domain/entities/leaderboard_entry.dart';
import 'package:vital_up/features/community/domain/entities/player_profile.dart';
import 'package:vital_up/features/community/domain/repositories/community_repository.dart';

/// A friend or the current user in the ranked friends list.
class RankedFriendItem extends Equatable {
  final int? rank;
  final String userId;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final int points;
  final int level;
  final bool isMe;
  final Friend? friend;

  const RankedFriendItem({
    required this.rank,
    required this.userId,
    required this.username,
    this.displayName,
    this.avatarUrl,
    required this.points,
    required this.level,
    required this.isMe,
    this.friend,
  });

  @override
  List<Object?> get props => [
    rank,
    userId,
    username,
    displayName,
    avatarUrl,
    points,
    level,
    isMe,
    friend,
  ];
}

class FriendsState extends Equatable {
  final List<Friend>? friends;
  final List<LeaderboardEntry> rankedMembers;
  final PlayerProfile? myProfile;
  final bool failed;
  final bool sending;

  /// Friend ids with an accept/decline/remove in flight.
  final Set<String> busy;

  /// One-off message for the last action (SnackBar); [messageId] changes
  /// with each so repeats still show.
  final String? message;
  final int messageId;

  const FriendsState({
    this.friends,
    this.rankedMembers = const [],
    this.myProfile,
    this.failed = false,
    this.sending = false,
    this.busy = const {},
    this.message,
    this.messageId = 0,
  });

  List<Friend> _with(FriendStatus s) => [
    for (final f in friends ?? const <Friend>[])
      if (f.status == s) f,
  ];

  List<Friend> get accepted => _with(FriendStatus.accepted);
  List<Friend> get incoming => _with(FriendStatus.incoming);
  List<Friend> get outgoing => _with(FriendStatus.outgoing);

  /// Returns all accepted friends and the current user ordered rankwise.
  List<RankedFriendItem> get rankedFriendsAndSelf {
    final acceptedFriends = accepted;
    if (acceptedFriends.isEmpty && myProfile == null) return const [];

    if (rankedMembers.isNotEmpty) {
      final items = <RankedFriendItem>[];
      final seenUserIds = <String>{};

      for (final e in rankedMembers) {
        seenUserIds.add(e.userId);
        if (e.isMe) {
          items.add(
            RankedFriendItem(
              rank: e.rank,
              userId: e.userId,
              username: e.username,
              displayName: e.displayName ?? myProfile?.displayName,
              avatarUrl: e.avatarUrl ?? myProfile?.avatarUrl,
              points: e.points,
              level: e.level,
              isMe: true,
            ),
          );
        } else {
          final f = acceptedFriends
              .where((friend) => friend.userId == e.userId)
              .firstOrNull;
          items.add(
            RankedFriendItem(
              rank: e.rank,
              userId: e.userId,
              username: e.username,
              displayName: e.displayName ?? f?.fullName,
              avatarUrl: e.avatarUrl ?? f?.avatarUrl,
              points: e.points,
              level: e.level,
              isMe: false,
              friend:
                  f ??
                  Friend(
                    userId: e.userId,
                    username: e.username,
                    fullName: e.displayName,
                    avatarUrl: e.avatarUrl,
                    level: e.level,
                    status: FriendStatus.accepted,
                  ),
            ),
          );
        }
      }

      // Include accepted friends not yet indexed in points
      for (final f in acceptedFriends) {
        if (!seenUserIds.contains(f.userId)) {
          items.add(
            RankedFriendItem(
              rank: null,
              userId: f.userId,
              username: f.username,
              displayName: f.fullName,
              avatarUrl: f.avatarUrl,
              points: 0,
              level: f.level,
              isMe: false,
              friend: f,
            ),
          );
        }
      }

      // Include caller if not yet on leaderboard
      if (myProfile != null && !seenUserIds.contains(myProfile!.userId)) {
        items.add(
          RankedFriendItem(
            rank: null,
            userId: myProfile!.userId,
            username: myProfile!.username,
            displayName: myProfile!.displayName,
            avatarUrl: myProfile!.avatarUrl,
            points: myProfile!.totalPoints,
            level: myProfile!.level,
            isMe: true,
          ),
        );
      }

      return items;
    }

    // Fallback when leaderboard is offline or unranked
    final list = <RankedFriendItem>[];
    if (myProfile != null) {
      list.add(
        RankedFriendItem(
          rank: null,
          userId: myProfile!.userId,
          username: myProfile!.username,
          displayName: myProfile!.displayName,
          avatarUrl: myProfile!.avatarUrl,
          points: myProfile!.totalPoints,
          level: myProfile!.level,
          isMe: true,
        ),
      );
    }
    for (final f in acceptedFriends) {
      list.add(
        RankedFriendItem(
          rank: null,
          userId: f.userId,
          username: f.username,
          displayName: f.fullName,
          avatarUrl: f.avatarUrl,
          points: 0,
          level: f.level,
          isMe: false,
          friend: f,
        ),
      );
    }

    list.sort((a, b) {
      final pCmp = b.points.compareTo(a.points);
      if (pCmp != 0) return pCmp;
      return b.level.compareTo(a.level);
    });

    final withRanks = <RankedFriendItem>[];
    for (var i = 0; i < list.length; i++) {
      final item = list[i];
      withRanks.add(
        RankedFriendItem(
          rank: item.points > 0 ? (i + 1) : null,
          userId: item.userId,
          username: item.username,
          displayName: item.displayName,
          avatarUrl: item.avatarUrl,
          points: item.points,
          level: item.level,
          isMe: item.isMe,
          friend: item.friend,
        ),
      );
    }

    return withRanks;
  }

  FriendsState copyWith({
    List<Friend>? friends,
    List<LeaderboardEntry>? rankedMembers,
    PlayerProfile? myProfile,
    bool? failed,
    bool? sending,
    Set<String>? busy,
    String? message,
  }) => FriendsState(
    friends: friends ?? this.friends,
    rankedMembers: rankedMembers ?? this.rankedMembers,
    myProfile: myProfile ?? this.myProfile,
    failed: failed ?? this.failed,
    sending: sending ?? this.sending,
    busy: busy ?? this.busy,
    message: message ?? this.message,
    messageId: message != null ? messageId + 1 : messageId,
  );

  @override
  List<Object?> get props => [
    friends,
    rankedMembers,
    myProfile,
    failed,
    sending,
    busy,
    message,
    messageId,
  ];
}

class FriendsCubit extends Cubit<FriendsState> {
  final CommunityRepository _repository;

  FriendsCubit(this._repository) : super(const FriendsState());

  @override
  void emit(FriendsState state) {
    // Requests can finish after the page closed (back during a save).
    if (!isClosed) super.emit(state);
  }

  Future<void> load() async {
    emit(state.copyWith(failed: false));
    try {
      final friends = await _repository.getFriends().withLoadTimeout();
      PlayerProfile? myProfile;
      try {
        myProfile = await _repository.getMyProfile();
      } catch (_) {}

      List<LeaderboardEntry> ranked = [];
      try {
        final acceptedCount = friends
            .where((f) => f.status == FriendStatus.accepted)
            .length;
        ranked = await _repository.getLeaderboard(
          Community.friendsOf(acceptedCount),
          period: LeaderboardPeriod.all,
        );
      } catch (e) {
        debugPrint('Friends leaderboard fetch: $e');
      }

      if (isClosed) return;
      emit(
        state.copyWith(
          friends: friends,
          rankedMembers: ranked,
          myProfile: myProfile,
        ),
      );
    } catch (e) {
      debugPrint('Friends failed to load: $e');
      if (isClosed) return;
      emit(state.copyWith(failed: true));
    }
  }

  /// Returns true when the request went through (the field can be cleared).
  Future<bool> send(String username) async {
    if (state.sending) return false;
    final String name;
    try {
      name = normalizeFriendUsername(username);
    } on FriendRequestException catch (e) {
      emit(state.copyWith(message: e.message));
      return false;
    }
    // Already on the list: say so without asking the server.
    final existing = state.friends
        ?.where((f) => f.username.toLowerCase() == name.toLowerCase())
        .firstOrNull;
    if (existing != null && existing.status != FriendStatus.incoming) {
      emit(
        state.copyWith(
          message: existing.status == FriendStatus.accepted
              ? "You're already friends."
              : 'Request already sent.',
        ),
      );
      return false;
    }
    emit(state.copyWith(sending: true));
    try {
      final nowFriends = await _repository
          .sendFriendRequest(name)
          .withLoadTimeout();
      if (isClosed) return true;
      emit(
        state.copyWith(
          sending: false,
          message: nowFriends
              ? 'You and @$name are now friends.'
              : 'Friend request sent to @$name.',
        ),
      );
      await load();
      return true;
    } on FriendRequestException catch (e) {
      if (!isClosed) emit(state.copyWith(sending: false, message: e.message));
      return false;
    } catch (e) {
      debugPrint('Friend request failed: $e');
      if (!isClosed) {
        emit(
          state.copyWith(
            sending: false,
            message: userMessage(
              e,
              fallback: "Couldn't send the request. Try again.",
            ),
          ),
        );
      }
      return false;
    }
  }

  Future<void> respond(Friend friend, {required bool accept}) => _act(
    friend,
    () => _repository.respondToRequest(friend, accept: accept),
    failure: "Couldn't update the request. Try again.",
  );

  Future<void> remove(Friend friend) => _act(
    friend,
    () => _repository.removeFriend(friend),
    failure: friend.status == FriendStatus.accepted
        ? "Couldn't remove @${friend.username}. Try again."
        : "Couldn't cancel the request. Try again.",
  );

  Future<void> _act(
    Friend friend,
    Future<void> Function() action, {
    required String failure,
  }) async {
    if (state.busy.contains(friend.userId)) return;
    emit(state.copyWith(busy: {...state.busy, friend.userId}));
    try {
      await action().withLoadTimeout();
      await load();
    } on FriendRequestException catch (e) {
      if (!isClosed) emit(state.copyWith(message: e.message));
      await load();
    } catch (e) {
      debugPrint('Friend action failed: $e');
      if (!isClosed) {
        emit(state.copyWith(message: userMessage(e, fallback: failure)));
      }
    } finally {
      if (!isClosed) {
        emit(state.copyWith(busy: {...state.busy}..remove(friend.userId)));
      }
    }
  }
}
