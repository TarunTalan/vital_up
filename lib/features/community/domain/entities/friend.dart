import 'package:equatable/equatable.dart';

enum FriendStatus {
  accepted,

  /// They sent the caller a request.
  incoming,

  /// The caller sent them a request.
  outgoing;

  static FriendStatus fromName(String? name) =>
      values.where((s) => s.name == name).firstOrNull ?? outgoing;
}

class Friend extends Equatable {
  final String userId;
  final String username;
  final String? fullName;
  final String? avatarUrl;
  final int level;
  final FriendStatus status;

  const Friend({
    required this.userId,
    required this.username,
    required this.level,
    required this.status,
    this.fullName,
    this.avatarUrl,
  });

  factory Friend.fromJson(Map<String, dynamic> json) => Friend(
    userId: json['user_id'] as String,
    username: json['username'] as String? ?? 'VitalUp user',
    fullName: json['full_name'] as String?,
    avatarUrl: json['avatar_url'] as String?,
    level: (json['level'] as num?)?.toInt() ?? 1,
    status: FriendStatus.fromName(json['status'] as String?),
  );

  @override
  List<Object?> get props => [
    userId,
    username,
    fullName,
    avatarUrl,
    level,
    status,
  ];
}

/// A friend request the server refused, with a message for the user.
class FriendRequestException implements Exception {
  final String message;
  const FriendRequestException(this.message);

  /// Maps the codes raised by the friends functions to user-facing text.
  static FriendRequestException fromServer(String serverMessage) {
    const messages = {
      'user_not_found': 'No one has that username.',
      'cannot_add_self': "That's your own username.",
      'already_friends': "You're already friends.",
      'already_requested': 'Request already sent.',
      'too_many_requests':
          'Too many pending requests. Wait for some replies first.',
      'request_not_found': 'That request is no longer there.',
    };
    for (final e in messages.entries) {
      if (serverMessage.contains(e.key)) return FriendRequestException(e.value);
    }
    return const FriendRequestException(
      "Couldn't send the request. Try again.",
    );
  }

  @override
  String toString() => message;
}
