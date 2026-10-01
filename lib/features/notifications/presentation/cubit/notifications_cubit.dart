import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/utils/load_timeout.dart';
import 'package:vital_up/features/community/domain/entities/friend.dart';
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
class NotificationsCubit extends Cubit<NotificationsState> {
  final NotificationsRepository _repository;
  StreamSubscription<void>? _changes;

  NotificationsCubit(this._repository) : super(const NotificationsState());

  Future<void> load() async {
    try {
      final items = await _repository.getNotifications().withLoadTimeout();
      if (isClosed) return;
      emit(state.copyWith(items: items, failed: false));
    } catch (e) {
      debugPrint('Notifications failed to load: $e');
      if (isClosed) return;
      emit(state.copyWith(failed: true));
    }
  }

  /// Reloads whenever the server adds or changes a notification.
  void watch() {
    _changes ??= _repository.watch().listen(
      (_) => load(),
      onError: (Object e) => debugPrint('Notifications feed error: $e'),
    );
  }

  Future<void> markRead(AppNotification notification) async {
    if (notification.isRead) return;
    _replace({notification.id}, (n) => n.markedRead());
    try {
      await _repository.markRead([notification.id]).withLoadTimeout();
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
      await _repository.markRead().withLoadTimeout();
    } catch (e) {
      debugPrint('Mark all notifications read failed: $e');
      await load();
    }
  }

  Future<void> remove(AppNotification notification) async {
    final items = state.items;
    if (items == null) return;
    emit(
      state.copyWith(
        items: [
          for (final n in items)
            if (n.id != notification.id) n,
        ],
      ),
    );
    try {
      await _repository.delete(notification).withLoadTimeout();
    } catch (e) {
      debugPrint('Delete notification failed: $e');
      if (isClosed) return;
      emit(state.copyWith(message: "Couldn't remove that notification."));
      await load();
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
      if (!isClosed && accept && name != null) {
        emit(state.copyWith(message: 'You and @$name are now friends!'));
      }
    } on FriendRequestException catch (e) {
      if (!isClosed) emit(state.copyWith(message: e.message));
    } catch (e) {
      debugPrint('Friend request response failed: $e');
      if (!isClosed) {
        emit(state.copyWith(message: "Couldn't update the request."));
      }
    } finally {
      await load();
      if (!isClosed) {
        emit(state.copyWith(busy: {...state.busy}..remove(notification.id)));
      }
    }
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
