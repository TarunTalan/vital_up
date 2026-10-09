import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/core/utils/load_timeout.dart';
import 'package:vital_up/features/community/domain/entities/friend.dart';
import 'package:vital_up/features/community/domain/repositories/community_repository.dart';

class FriendsState extends Equatable {
  final List<Friend>? friends;
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

  FriendsState copyWith({
    List<Friend>? friends,
    bool? failed,
    bool? sending,
    Set<String>? busy,
    String? message,
  }) => FriendsState(
    friends: friends ?? this.friends,
    failed: failed ?? this.failed,
    sending: sending ?? this.sending,
    busy: busy ?? this.busy,
    message: message ?? this.message,
    messageId: message != null ? messageId + 1 : messageId,
  );

  @override
  List<Object?> get props => [
    friends,
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

  Future<void> load() async {
    emit(state.copyWith(failed: false));
    try {
      final friends = await _repository.getFriends().withLoadTimeout();
      if (isClosed) return;
      emit(state.copyWith(friends: friends));
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
