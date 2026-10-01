import 'package:equatable/equatable.dart';

enum LeaderboardPeriod {
  week('This week'),
  month('This month'),
  all('All time');

  final String label;
  const LeaderboardPeriod(this.label);
}

class LeaderboardEntry extends Equatable {
  /// Null for the caller's own row when they have no points this period.
  final int? rank;
  final String userId;
  final String username;
  final String? avatarUrl;
  final int points;
  final int level;
  final bool isMe;

  const LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.username,
    required this.points,
    required this.level,
    this.avatarUrl,
    this.isMe = false,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      LeaderboardEntry(
        rank: (json['rank'] as num?)?.toInt(),
        userId: json['user_id'] as String,
        username: json['username'] as String? ?? 'VitalUp user',
        avatarUrl: json['avatar_url'] as String?,
        points: (json['points'] as num?)?.toInt() ?? 0,
        level: (json['level'] as num?)?.toInt() ?? 1,
        isMe: json['is_me'] as bool? ?? false,
      );

  @override
  List<Object?> get props => [
    rank,
    userId,
    username,
    avatarUrl,
    points,
    level,
    isMe,
  ];
}
