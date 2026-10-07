import 'package:equatable/equatable.dart';

enum NotificationType {
  friendRequest('friend_request'),
  friendAccepted('friend_accepted'),
  badge('badge'),
  levelUp('level_up'),
  streak('streak'),

  /// A friend challenged the user (route: challenges).
  challenge('challenge'),

  /// A friend cheered the user on (route: friends).
  cheer('cheer'),

  /// Sent by the VitalUp team (app news, tips, reminders).
  announcement('announcement');

  final String code;
  const NotificationType(this.code);

  static NotificationType fromCode(String? code) =>
      values.where((t) => t.code == code).firstOrNull ?? announcement;

  /// Sent because of a friend (shows their avatar, "Friends" filter).
  bool get isFriend =>
      this == friendRequest ||
      this == friendAccepted ||
      this == challenge ||
      this == cheer;
  bool get isAchievement => this == badge || this == levelUp || this == streak;
}

/// One row of the caller's `notifications` inbox.
class AppNotification extends Equatable {
  final int id;
  final NotificationType type;
  final String title;
  final String? body;
  final String? actorId;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final DateTime? readAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.createdAt,
    this.body,
    this.actorId,
    this.data = const {},
    this.readAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: (json['id'] as num).toInt(),
        type: NotificationType.fromCode(json['type'] as String?),
        title: json['title'] as String? ?? '',
        body: json['body'] as String?,
        actorId: json['actor_id'] as String?,
        data: json['data'] is Map
            ? Map<String, dynamic>.from(json['data'] as Map)
            : const {},
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
        readAt: json['read_at'] == null
            ? null
            : DateTime.parse(json['read_at'] as String).toLocal(),
      );

  bool get isRead => readAt != null;

  /// The friend's username / avatar for friend notifications.
  String? get actorUsername => data['username'] as String?;
  String? get actorAvatarUrl => data['avatar_url'] as String?;

  /// A friend request still waiting for accept / decline.
  bool get isPendingRequest =>
      type == NotificationType.friendRequest && data['status'] == 'pending';

  /// `badges.icon_key` for badge notifications.
  String? get badgeIconKey => data['icon_key'] as String?;

  /// Optional in-app route name an announcement links to.
  String? get route => data['route'] as String?;

  AppNotification markedRead() => isRead ? this : _copy(readAt: DateTime.now());

  /// A friend request after it was accepted (what the server trigger does:
  /// no more buttons, and read).
  AppNotification acceptedRequest() => _copy(
    data: {...data, 'status': 'accepted'},
    readAt: readAt ?? DateTime.now(),
  );

  AppNotification _copy({Map<String, dynamic>? data, DateTime? readAt}) =>
      AppNotification(
        id: id,
        type: type,
        title: title,
        body: body,
        actorId: actorId,
        data: data ?? this.data,
        createdAt: createdAt,
        readAt: readAt ?? this.readAt,
      );

  @override
  List<Object?> get props => [
    id,
    type,
    title,
    body,
    actorId,
    data,
    createdAt,
    readAt,
  ];
}
