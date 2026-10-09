import 'package:equatable/equatable.dart';
import 'package:vital_up/features/gamification/domain/entities/game_badge.dart';

/// What one `submit_daily_report` call awarded.
class AwardResult extends Equatable {
  final int pointsAwarded;
  final int level;
  final bool levelUp;
  final int streak;
  final List<GameBadge> newBadges;

  /// A rest day was earned (7 active days in a row).
  final bool freezeEarned;

  /// Rest days spent to keep the streak through missed days.
  final int freezesUsed;

  const AwardResult({
    required this.pointsAwarded,
    required this.level,
    required this.levelUp,
    required this.streak,
    required this.newBadges,
    this.freezeEarned = false,
    this.freezesUsed = 0,
  });

  /// Worth interrupting the user for.
  bool get celebrate => levelUp || newBadges.isNotEmpty;

  /// Worth a quiet note (a snackbar) at least.
  bool get notable => celebrate || freezeEarned || freezesUsed > 0;

  factory AwardResult.fromJson(Map<String, dynamic> json) => AwardResult(
    pointsAwarded: (json['points_awarded'] as num?)?.toInt() ?? 0,
    level: (json['level'] as num?)?.toInt() ?? 1,
    levelUp: json['level_up'] as bool? ?? false,
    streak: (json['streak'] as num?)?.toInt() ?? 0,
    newBadges: [
      for (final b in (json['new_badges'] as List? ?? const []))
        if (b is Map<String, dynamic>)
          GameBadge.fromJson(b, earnedAt: DateTime.now()),
    ],
    freezeEarned: json['freeze_earned'] as bool? ?? false,
    freezesUsed: (json['freezes_used'] as num?)?.toInt() ?? 0,
  );

  /// Combines results from submitting several days in one sync.
  AwardResult merge(AwardResult other) => AwardResult(
    pointsAwarded: pointsAwarded + other.pointsAwarded,
    level: other.level,
    levelUp: levelUp || other.levelUp,
    streak: other.streak,
    newBadges: [...newBadges, ...other.newBadges],
    freezeEarned: freezeEarned || other.freezeEarned,
    freezesUsed: freezesUsed + other.freezesUsed,
  );

  @override
  List<Object?> get props => [
    pointsAwarded,
    level,
    levelUp,
    streak,
    newBadges,
    freezeEarned,
    freezesUsed,
  ];
}
