import 'package:vital_up/features/gamification/domain/entities/award_result.dart';
import 'package:vital_up/features/gamification/domain/entities/game_badge.dart';
import 'package:vital_up/features/gamification/domain/entities/player_stats.dart';
import 'package:vital_up/features/gamification/domain/entities/point_event.dart';
import 'package:vital_up/features/gamification/domain/entities/score_category.dart';

abstract class GamificationRepository {
  /// Reports every day since the last successful sync (at most the last
  /// three days, which the server accepts) whose metrics changed since they
  /// were last sent, and returns what was awarded. Null when signed out or
  /// nothing needed sending. Throws when the server can't be reached.
  Future<AwardResult?> sync();

  // Reads are cache-first: fresh copies are served without a request and,
  // offline, the last copy is returned. They throw only when nothing is
  // cached and the server can't be reached.

  Future<PlayerStats> getStats();

  /// Points earned on [day] per category.
  Future<Map<ScoreCategory, int>> getPointsForDay(DateTime day);

  /// Ledger rows for the last [days] days, newest first.
  Future<List<PointEvent>> getHistory({int days = 30});

  /// The whole badge catalog, earned ones carrying their date.
  Future<List<GameBadge>> getBadges();

  Future<List<PointRule>> getRules();
}
