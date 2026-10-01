import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/core/utils/date_range_utils.dart';
import 'package:vital_up/features/gamification/data/datasources/gamification_remote_datasource.dart';
import 'package:vital_up/features/gamification/data/services/daily_metrics_collector.dart';
import 'package:vital_up/features/gamification/domain/entities/award_result.dart';
import 'package:vital_up/features/gamification/domain/entities/game_badge.dart';
import 'package:vital_up/features/gamification/domain/entities/player_stats.dart';
import 'package:vital_up/features/gamification/domain/entities/point_event.dart';
import 'package:vital_up/features/gamification/domain/entities/score_category.dart';
import 'package:vital_up/features/gamification/domain/repositories/gamification_repository.dart';

class GamificationRepositoryImpl implements GamificationRepository {
  final GamificationRemoteDataSource _remote;
  final DailyMetricsCollector _collector;
  final SharedPreferences _prefs;

  /// Days before today the server still accepts a report for.
  static const maxBackfillDays = 2;

  List<GameLevel>? _levels;

  GamificationRepositoryImpl({
    required this._remote,
    required this._collector,
    required this._prefs,
  });

  String _syncedKey(String userId) => 'gamification_synced_day_$userId';

  @override
  Future<AwardResult?> sync() async {
    final userId = _remote.userId;
    if (userId == null) return null;

    final today = startOfDay(DateTime.now());
    final oldest = DateTime(
      today.year,
      today.month,
      today.day - maxBackfillDays,
    );
    final synced = DateTime.tryParse(
      _prefs.getString(_syncedKey(userId)) ?? '',
    );

    // Re-send the last synced day too: it was probably reported mid-day.
    var day = synced == null
        ? today
        : synced.isBefore(oldest)
        ? oldest
        : synced;

    AwardResult? total;
    // Oldest first, so a late day can still extend the streak.
    while (!day.isAfter(today)) {
      final metrics = await _collector.collect(userId, day);
      final result = AwardResult.fromJson(
        await _remote.submitDailyReport(metrics),
      );
      total = total == null ? result : total.merge(result);
      await _prefs.setString(
        _syncedKey(userId),
        GamificationRemoteDataSource.dayParam(day),
      );
      day = nextDay(day);
    }
    return total;
  }

  Future<List<GameLevel>> _getLevels() async => _levels ??= [
    for (final r in await _remote.fetchLevels()) GameLevel.fromJson(r),
  ];

  @override
  Future<PlayerStats> getStats() async {
    final userId = _remote.userId;
    if (userId == null) return PlayerStats.empty;
    final (row, levels) = await (_remote.fetchStats(userId), _getLevels()).wait;
    final lastActive = DateTime.tryParse(
      row?['last_active_day'] as String? ?? '',
    );
    return PlayerStats.fromRow(
      row,
      levels,
      effectiveStreak: effectiveStreak(
        (row?['current_streak'] as num?)?.toInt() ?? 0,
        lastActive,
      ),
    );
  }

  @override
  Future<Map<ScoreCategory, int>> getPointsForDay(DateTime day) async {
    final userId = _remote.userId;
    if (userId == null) return const {};
    final date = startOfDay(day);
    final rows = await _remote.fetchEvents(userId, from: date, to: date);
    final totals = <ScoreCategory, int>{};
    for (final e in rows.map(PointEvent.fromJson)) {
      totals[e.category] = (totals[e.category] ?? 0) + e.points;
    }
    return totals;
  }

  @override
  Future<List<PointEvent>> getHistory({int days = 30}) async {
    final userId = _remote.userId;
    if (userId == null) return const [];
    final from = lastNDays(days).first;
    return [
      for (final r in await _remote.fetchEvents(userId, from: from))
        PointEvent.fromJson(r),
    ];
  }

  @override
  Future<List<GameBadge>> getBadges() async {
    final userId = _remote.userId;
    if (userId == null) return const [];
    final (catalog, earned) = await (
      _remote.fetchBadges(),
      _remote.fetchEarnedBadges(userId),
    ).wait;
    final earnedAt = {
      for (final e in earned)
        e['badge_code'] as String: DateTime.tryParse(
          e['earned_at'] as String? ?? '',
        ),
    };
    return [
      for (final b in catalog)
        GameBadge.fromJson(b, earnedAt: earnedAt[b['code']]),
    ];
  }

  @override
  Future<List<PointRule>> getRules() async => [
    for (final r in await _remote.fetchRules()) PointRule.fromJson(r),
  ];
}
