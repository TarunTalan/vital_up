import 'package:equatable/equatable.dart';
import 'package:vital_up/features/gamification/domain/entities/score_category.dart';

/// A level and the lifetime points it starts at (`levels` table).
class GameLevel extends Equatable {
  final int level;
  final int minPoints;
  final String title;

  const GameLevel({
    required this.level,
    required this.minPoints,
    required this.title,
  });

  factory GameLevel.fromJson(Map<String, dynamic> json) => GameLevel(
    level: (json['level'] as num).toInt(),
    minPoints: (json['min_points'] as num).toInt(),
    title: json['title'] as String,
  );

  @override
  List<Object?> get props => [level, minPoints, title];
}

/// The signed-in user's lifetime score, level and streak.
class PlayerStats extends Equatable {
  final int totalPoints;
  final Map<ScoreCategory, int> categoryPoints;
  final int streak;
  final int longestStreak;

  /// Current level, and the next one (null at the top level).
  final GameLevel level;
  final GameLevel? nextLevel;

  const PlayerStats({
    required this.totalPoints,
    required this.categoryPoints,
    required this.streak,
    required this.longestStreak,
    required this.level,
    this.nextLevel,
  });

  static const empty = PlayerStats(
    totalPoints: 0,
    categoryPoints: {},
    streak: 0,
    longestStreak: 0,
    level: GameLevel(level: 1, minPoints: 0, title: 'Starter'),
  );

  /// 0–1 progress from this level to the next.
  double get levelProgress {
    final next = nextLevel;
    if (next == null) return 1;
    final span = next.minPoints - level.minPoints;
    if (span <= 0) return 1;
    return ((totalPoints - level.minPoints) / span).clamp(0.0, 1.0);
  }

  int get pointsToNextLevel => nextLevel == null
      ? 0
      : (nextLevel!.minPoints - totalPoints).clamp(0, 1 << 31);

  int pointsIn(ScoreCategory c) => categoryPoints[c] ?? 0;

  /// Builds stats from a `player_stats` row and the level table; [row] is
  /// null before the first report.
  factory PlayerStats.fromRow(
    Map<String, dynamic>? row,
    List<GameLevel> levels, {
    required int effectiveStreak,
  }) {
    final total = (row?['total_points'] as num?)?.toInt() ?? 0;
    final sorted = [...levels]
      ..sort((a, b) => a.minPoints.compareTo(b.minPoints));
    var current = sorted.isEmpty ? empty.level : sorted.first;
    GameLevel? next;
    for (final l in sorted) {
      if (l.minPoints <= total) {
        current = l;
      } else {
        next = l;
        break;
      }
    }
    int read(String key) => (row?[key] as num?)?.toInt() ?? 0;
    return PlayerStats(
      totalPoints: total,
      categoryPoints: {
        ScoreCategory.nutrition: read('nutrition_points'),
        ScoreCategory.lifestyle: read('lifestyle_points'),
        ScoreCategory.fitness: read('fitness_points'),
        ScoreCategory.bonus: read('bonus_points'),
      },
      streak: effectiveStreak,
      longestStreak: read('longest_streak'),
      level: current,
      nextLevel: next,
    );
  }

  @override
  List<Object?> get props => [
    totalPoints,
    categoryPoints,
    streak,
    longestStreak,
    level,
    nextLevel,
  ];
}

/// The streak as users should see it: alive while yesterday or today was
/// active (mirrors `effective_streak()` on the server).
int effectiveStreak(int streak, DateTime? lastActiveDay, {DateTime? now}) {
  if (lastActiveDay == null) return 0;
  final t = now ?? DateTime.now();
  final yesterday = DateTime(t.year, t.month, t.day - 1);
  final last = DateTime(
    lastActiveDay.year,
    lastActiveDay.month,
    lastActiveDay.day,
  );
  return last.isBefore(yesterday) ? 0 : streak;
}
