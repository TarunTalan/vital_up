import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/utils/load_timeout.dart';
import 'package:vital_up/features/community/domain/entities/friend.dart';
import 'package:vital_up/features/community/domain/repositories/community_repository.dart';
import 'package:vital_up/features/notifications/domain/entities/app_notification.dart';
import 'package:vital_up/features/notifications/domain/repositories/notifications_repository.dart';

class NotificationsState extends Equatable {
  /// Newest first; null until the first load finishes.
  final List<AppNotification>? items;
  final bool failed;

  /// Notification ids with an accept/decline in flight.
  final Set<int> busy;

  /// One-off message for the last action (SnackBar); [messageId] changes
  /// with each so repeats still show.
  final String? message;
  final int messageId;

  const NotificationsState({
    this.items,
    this.failed = false,
    this.busy = const {},
    this.message,
    this.messageId = 0,
  });

  int get unreadCount => items?.where((n) => !n.isRead).length ?? 0;

  NotificationsState copyWith({
    List<AppNotification>? items,
    bool? failed,
    Set<int>? busy,
    String? message,
  }) => NotificationsState(
    items: items ?? this.items,
    failed: failed ?? this.failed,
    busy: busy ?? this.busy,
    message: message ?? this.message,
    messageId: message != null ? messageId + 1 : messageId,
  );

  @override
  List<Object?> get props => [items, failed, busy, message, messageId];
}

/// The inbox behind the home-screen bell: friend requests, achievements and
/// announcements, kept live through the realtime feed.
///
/// Opens from the cached inbox; realtime rows and the user's own changes
/// are applied locally rather than refetching the list.
class NotificationsCubit extends Cubit<NotificationsState> {
  final NotificationsRepository _repository;
  StreamSubscription<AppNotification>? _changes;

  static const _limit = 50;

  NotificationsCubit(this._repository) : super(const NotificationsState());

  /// Cache-first; [refresh] (pull to refresh) asks the server anyway.
  Future<void> load({bool refresh = false}) async {
    try {
      final items = await _repository
          .getNotifications(limit: _limit, refresh: refresh)
          .withLoadTimeout();
      if (isClosed) return;
      emit(state.copyWith(items: items, failed: false));
    } catch (e) {
      debugPrint('Notifications failed to load: $e');
      if (isClosed) return;
      // Keep showing what's there; only an empty inbox shows the error.
      emit(state.copyWith(failed: true));
    }
  }

  Future<void> refresh() => load(refresh: true);

  /// Applies each row the server adds or changes.
  void watch() {
    _changes ??= _repository.watch().listen(
      _upsert,
      onError: (Object e) => debugPrint('Notifications feed error: $e'),
    );
  }

  void _upsert(AppNotification notification) {
    final items = state.items;
    if (items == null || isClosed) return;
    final i = items.indexWhere((n) => n.id == notification.id);
    emit(
      state.copyWith(
        items: i == -1
            ? [notification, ...items].take(_limit).toList()
            : ([...items]..[i] = notification),
      ),
    );
  }

  Future<void> markRead(AppNotification notification) async {
    if (notification.isRead) return;
    _replace({notification.id}, (n) => n.markedRead());
    try {
      await _repository.markRead([notification.id]);
    } catch (e) {
      debugPrint('Mark notification read failed: $e');
    }
  }

  Future<void> markAllRead() async {
    if (state.unreadCount == 0) return;
    final unread = {
      for (final n in state.items ?? const <AppNotification>[])
        if (!n.isRead) n.id,
    };
    _replace(unread, (n) => n.markedRead());
    try {
      // Queued when offline, so only a server refusal lands here.
      await _repository.markRead();
    } catch (e) {
      debugPrint('Mark all notifications read failed: $e');
      await load(refresh: true);
    }
  }

  Future<void> remove(AppNotification notification) async {
    if (state.items == null) return;
    _drop(notification.id);
    try {
      // Queued when offline, so only a server refusal lands here.
      await _repository.delete(notification);
    } catch (e) {
      debugPrint('Delete notification failed: $e');
      if (isClosed) return;
      emit(state.copyWith(message: "Couldn't remove that notification."));
      await load(refresh: true);
    }
  }

  Future<void> respond(
    AppNotification notification, {
    required bool accept,
  }) async {
    if (state.busy.contains(notification.id)) return;
    emit(state.copyWith(busy: {...state.busy, notification.id}));
    final name = notification.actorUsername;
    try {
      await _repository
          .respondToFriendRequest(notification, accept: accept)
          .withLoadTimeout();
      // What the server trigger does to the row.
      if (accept) {
        _replace({notification.id}, (n) => n.acceptedRequest());
      } else {
        _drop(notification.id);
      }
      if (!isClosed && accept && name != null) {
        emit(state.copyWith(message: 'You and @$name are now friends!'));
      }
    } on FriendRequestException catch (e) {
      if (!isClosed) emit(state.copyWith(message: e.message));
      // Answered elsewhere or withdrawn: show the row as it is now.
      if (e.message != CommunityRepository.offlineMessage) {
        await load(refresh: true);
      }
    } catch (e) {
      debugPrint('Friend request response failed: $e');
      if (!isClosed) {
        emit(state.copyWith(message: "Couldn't update the request."));
      }
    } finally {
      if (!isClosed) {
        emit(state.copyWith(busy: {...state.busy}..remove(notification.id)));
      }
    }
  }

  void _drop(int id) {
    final items = state.items;
    if (items == null || isClosed) return;
    emit(
      state.copyWith(
        items: [
          for (final n in items)
            if (n.id != id) n,
        ],
      ),
    );
  }

  void _replace(Set<int> ids, AppNotification Function(AppNotification) f) {
    final items = state.items;
    if (items == null || isClosed) return;
    emit(
      state.copyWith(
        items: [for (final n in items) ids.contains(n.id) ? f(n) : n],
      ),
    );
  }

  @override
  Future<void> close() async {
    await _changes?.cancel();
    return super.close();
  }
}
