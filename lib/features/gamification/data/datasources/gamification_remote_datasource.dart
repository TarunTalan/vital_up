import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vital_up/features/gamification/domain/entities/daily_metrics.dart';

/// Supabase reads and the `submit_daily_report` RPC. Points, stats and
/// badges are read-only to the app; only the RPC awards them.
class GamificationRemoteDataSource {
  final SupabaseClient _client;

  GamificationRemoteDataSource(this._client);

  String? get userId => _client.auth.currentUser?.id;

  static String dayParam(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<Map<String, dynamic>> submitDailyReport(DailyMetrics metrics) async {
    // Callers share one in-flight report; a hung socket must not block
    // every later sync for the rest of the session.
    final result = await _client
        .rpc(
          'submit_daily_report',
          params: {
            'p_day': dayParam(metrics.day),
            'p_metrics': metrics.toJson(),
          },
        )
        .timeout(const Duration(seconds: 20));
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>?> fetchStats(String userId) =>
      _client.from('player_stats').select().eq('user_id', userId).maybeSingle();

  Future<List<Map<String, dynamic>>> fetchLevels() =>
      _client.from('levels').select().order('level');

  Future<List<Map<String, dynamic>>> fetchBadges() =>
      _client.from('badges').select().order('sort');

  Future<List<Map<String, dynamic>>> fetchEarnedBadges(String userId) => _client
      .from('user_badges')
      .select('badge_code, earned_at')
      .eq('user_id', userId);

  /// `get_badge_progress()`: {code, value, threshold} per badge.
  Future<List<Map<String, dynamic>>> fetchBadgeProgress() async {
    final rows = await _client.rpc('get_badge_progress');
    return [for (final r in rows as List) Map<String, dynamic>.from(r as Map)];
  }

  /// Every event in the range. PostgREST caps one response (1000 rows by
  /// default), which silently cut long histories (e.g. the data export), so
  /// this pages until a short page comes back.
  Future<List<Map<String, dynamic>>> fetchEvents(
    String userId, {
    required DateTime from,
    DateTime? to,
  }) async {
    const page = 1000;
    final rows = <Map<String, dynamic>>[];
    for (var offset = 0; ; offset += page) {
      var query = _client
          .from('point_events')
          .select('day, source, category, points')
          .eq('user_id', userId)
          .gte('day', dayParam(from));
      if (to != null) query = query.lte('day', dayParam(to));
      final batch = await query
          .order('day', ascending: false)
          .order('points', ascending: false)
          // Primary key last, so pages never overlap or skip a row.
          .order('id')
          .range(offset, offset + page - 1);
      rows.addAll(batch);
      if (batch.length < page) return rows;
    }
  }

  Future<List<Map<String, dynamic>>> fetchRules() =>
      _client.from('point_rules').select().eq('active', true).order('sort');
}
