import 'package:equatable/equatable.dart';
import 'package:vital_up/features/gamification/domain/entities/game_badge.dart';
import 'package:vital_up/features/gamification/domain/entities/score_category.dart';

/// Level, points, streaks and recent badges of the caller or an accepted
/// friend, from `get_player_profile`.
class PlayerProfile extends Equatable {
  final String userId;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final int level;
  final int totalPoints;
  final Map<ScoreCategory, int> categoryPoints;
  final int currentStreak;
  final int longestStreak;
  final int badgeCount;

  /// Latest earned first, at most six.
  final List<GameBadge> recentBadges;

  /// The caller already cheered this friend today.
  final bool cheeredToday;

  /// The friend turned off "Show me on leaderboards": only name, avatar
  /// and level are shared; every stat below reads as zero.
  final bool isPrivate;

  const PlayerProfile({
    required this.userId,
    required this.username,
    this.displayName,
    this.avatarUrl,
    required this.level,
    required this.totalPoints,
    required this.categoryPoints,
    required this.currentStreak,
    required this.longestStreak,
    required this.badgeCount,
    required this.recentBadges,
    required this.cheeredToday,
    this.isPrivate = false,
  });

  int pointsIn(ScoreCategory category) => categoryPoints[category] ?? 0;

  factory PlayerProfile.fromJson(Map<String, dynamic> json) {
    int n(String key) => (json[key] as num?)?.toInt() ?? 0;
    return PlayerProfile(
      userId: json['user_id'] as String,
      username: json['username'] as String? ?? 'VitalUp user',
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      level: (json['level'] as num?)?.toInt() ?? 1,
      totalPoints: n('total_points'),
      categoryPoints: {
        for (final c in ScoreCategory.values) c: n('${c.name}_points'),
      },
      currentStreak: n('current_streak'),
      longestStreak: n('longest_streak'),
      badgeCount: n('badge_count'),
      recentBadges: [
        for (final b in (json['badges'] as List? ?? const []))
          if (b is Map<String, dynamic>)
            GameBadge.fromJson(
              b,
              earnedAt: DateTime.tryParse(b['earned_at'] as String? ?? ''),
            ),
      ],
      cheeredToday: json['cheered_today'] as bool? ?? false,
      isPrivate: json['private'] as bool? ?? false,
    );
  }

  PlayerProfile copyWith({bool? cheeredToday}) => PlayerProfile(
    userId: userId,
    username: username,
    displayName: displayName,
    avatarUrl: avatarUrl,
    level: level,
    totalPoints: totalPoints,
    categoryPoints: categoryPoints,
    currentStreak: currentStreak,
    longestStreak: longestStreak,
    badgeCount: badgeCount,
    recentBadges: recentBadges,
    cheeredToday: cheeredToday ?? this.cheeredToday,
    isPrivate: isPrivate,
  );

  @override
  List<Object?> get props => [
    userId,
    username,
    displayName,
    avatarUrl,
    level,
    totalPoints,
    categoryPoints,
    currentStreak,
    longestStreak,
    badgeCount,
    recentBadges,
    cheeredToday,
    isPrivate,
  ];
}

/// A profile or cheer request the server refused, with a message for the
/// user.
class PlayerProfileException implements Exception {
  final String message;
  const PlayerProfileException(this.message);

  static const alreadyCheered = 'You already cheered them today.';

  static PlayerProfileException fromServer(String serverMessage) {
    const messages = {
      'not_friends': "You're no longer friends.",
      'user_not_found': "That profile isn't available.",
      'already_cheered': alreadyCheered,
      'cannot_cheer_self': "You can't cheer yourself.",
    };
    for (final e in messages.entries) {
      if (serverMessage.contains(e.key)) return PlayerProfileException(e.value);
    }
    return const PlayerProfileException(
      "Couldn't reach the server. Try again.",
    );
  }

  @override
  String toString() => message;
}
