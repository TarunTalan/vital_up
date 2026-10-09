import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/core/cache/cache_store.dart';
import 'package:vital_up/core/utils/date_range_utils.dart';
import 'package:vital_up/features/gamification/data/datasources/gamification_remote_datasource.dart';
import 'package:vital_up/features/gamification/data/services/daily_metrics_collector.dart';
import 'package:vital_up/features/gamification/domain/entities/award_result.dart';
import 'package:vital_up/features/gamification/domain/entities/daily_metrics.dart';
import 'package:vital_up/features/gamification/domain/entities/game_badge.dart';
import 'package:vital_up/features/gamification/domain/entities/player_stats.dart';
import 'package:vital_up/features/gamification/domain/entities/point_event.dart';
import 'package:vital_up/features/gamification/domain/entities/score_category.dart';
import 'package:vital_up/features/gamification/domain/repositories/gamification_repository.dart';

/// Rows for a date-bounded query, tagged with the bound they were fetched
/// for so a cached copy from yesterday isn't mistaken for today's.
typedef _Slot = ({String day, List<Map<String, dynamic>> rows});

class GamificationRepositoryImpl implements GamificationRepository {
  final GamificationRemoteDataSource _remote;
  final DailyMetricsCollector _collector;
  final SharedPreferences _prefs;
  final CacheStore _cache;

  /// Days before today the server still accepts a report for:
  /// `submit_daily_report` raises "day out of range" for
  /// `p_day < today - 2`. Widening this needs that check relaxed first.
  static const maxBackfillDays = 2;

  /// Levels, badges and point rules change with releases, not activity.
  static const catalogMaxAge = Duration(hours: 24);

  /// The user's score, badges and ledger. Reports that changed them also
  /// mark them stale (see [_markChanged]), so this only bounds drift from
  /// other devices.
  static const playerMaxAge = Duration(minutes: 5);

  /// Below the screens' load timeout, so a dead connection falls back to
  /// the cached copy before the screen gives up.
  static const requestTimeout = Duration(seconds: 10);

  Future<AwardResult?>? _syncing;

  GamificationRepositoryImpl({
    required this._remote,
    required this._collector,
    required this._prefs,
    required this._cache,
  });

  String _syncedKey(String userId) => 'gamification_synced_day_$userId';

  /// Metrics last accepted by the server, per day, so unchanged days
  /// aren't re-sent.
  String _sentKey(String userId) => 'gamification_sent_metrics_$userId';

  /// When a report last changed this user's score on the server.
  String _changedKey(String userId) => 'gamification_changed_at_$userId';

  @override
  Future<AwardResult?> sync() =>
      // Overlapping callers share one run instead of re-sending the days.
      _syncing ??= _sync().whenComplete(() => _syncing = null);

  Future<AwardResult?> _sync() async {
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

    final sent = _readSent(userId, oldest);
    AwardResult? total;
    // Oldest first, so a late day can still extend the streak. A failure
    // throws before the cursor moves, so the next sync retries that day.
    while (!day.isAfter(today)) {
      final param = GamificationRemoteDataSource.dayParam(day);
      final metrics = await _collector.collect(userId, day);
      final fingerprint = _fingerprint(metrics);
      // The server keeps each day's highest numbers, so re-sending the
      // same ones can't award anything.
      if (sent[param] != fingerprint) {
        // Signed out or switched account mid-sync: never report this
        // user's data under another session.
        if (_remote.userId != userId) return total;
        try {
          final result = AwardResult.fromJson(
            await _remote.submitDailyReport(metrics),
          );
          total = total == null ? result : total.merge(result);
          sent[param] = fingerprint;
          await _prefs.setString(_sentKey(userId), jsonEncode(sent));
          await _markChanged(userId);
        } catch (e) {
          // Device clock / server timezone disagree about the oldest day:
          // skip it rather than blocking every later day forever.
          if (!day.isBefore(today) || !e.toString().contains('out of range')) {
            rethrow;
          }
          debugPrint('Gamification: server no longer takes $param, skipped');
        }
      }
      await _prefs.setString(_syncedKey(userId), param);
      day = nextDay(day);
    }
    return total;
  }

  Map<String, String> _readSent(String userId, DateTime oldest) {
    try {
      final raw = jsonDecode(_prefs.getString(_sentKey(userId)) ?? '{}');
      final from = GamificationRemoteDataSource.dayParam(oldest);
      return {
        for (final e in (raw as Map).entries)
          // Days the server no longer accepts can be forgotten.
          if ((e.key as String).compareTo(from) >= 0)
            e.key as String: e.value as String,
      };
    } catch (_) {
      return {};
    }
  }

  static String _fingerprint(DailyMetrics metrics) {
    final json = metrics.toJson();
    // Goal sets have no stable order.
    (json['daily_goals'] as List<String>).sort();
    (json['weekly_goals'] as List<String>).sort();
    return jsonEncode(json);
  }

  Future<void> _markChanged(String userId) =>
      _prefs.setInt(_changedKey(userId), DateTime.now().millisecondsSinceEpoch);

  /// Cache-first read of [key]. Copies saved before the last report that
  /// changed [userId]'s score are refreshed even if younger than [maxAge].
  Future<T> _fetch<T>(
    String key, {
    required Future<T> Function() remote,
    required T Function(Object? json) decode,
    Object? Function(T value)? encode,
    Duration maxAge = playerMaxAge,
    String? userId,
    bool force = false,
  }) async {
    final changed = userId == null ? null : _prefs.getInt(_changedKey(userId));
    if (!force && changed != null) {
      final cached = await _cache.read<Object?>(key);
      force = cached != null && cached.savedAt.millisecondsSinceEpoch < changed;
    }
    return _cache.fetch<T>(
      key,
      remote: () => remote().timeout(requestTimeout),
      maxAge: maxAge,
      encode: encode,
      decode: decode,
      forceRefresh: force,
    );
  }

  /// [_fetch] for rows bounded by [day]: a copy fetched for another day is
  /// refetched. Offline that stale copy comes back as is; callers check
  /// [_Slot.day].
  Future<_Slot> _fetchSlot(
    String key,
    String day,
    Future<List<Map<String, dynamic>>> Function() remote, {
    required String userId,
  }) async {
    final cached = await _cache.read<_Slot>(key, decode: _slot);
    return _fetch<_Slot>(
      key,
      remote: () async => (day: day, rows: await remote()),
      encode: (v) => {'day': v.day, 'rows': v.rows},
      decode: _slot,
      userId: userId,
      force: cached != null && cached.value.day != day,
    );
  }

  static List<Map<String, dynamic>> _rows(Object? json) => [
    for (final r in json as List) Map<String, dynamic>.from(r as Map),
  ];

  static Map<String, dynamic>? _row(Object? json) =>
      json == null ? null : Map<String, dynamic>.from(json as Map);

  static _Slot _slot(Object? json) {
    final map = json as Map;
    return (day: map['day'] as String, rows: _rows(map['rows']));
  }

  Future<List<GameLevel>> _getLevels() async => [
    for (final r in await _fetch(
      'gamification:levels',
      remote: _remote.fetchLevels,
      decode: _rows,
      maxAge: catalogMaxAge,
    ))
      GameLevel.fromJson(r),
  ];

  @override
  Future<PlayerStats> getStats() async {
    final userId = _remote.userId;
    if (userId == null) return PlayerStats.empty;
    final (row, levels) = await (
      _fetch(
        'gamification:stats:$userId',
        remote: () => _remote.fetchStats(userId),
        decode: _row,
        userId: userId,
      ),
      _getLevels(),
    ).wait;
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
    final param = GamificationRemoteDataSource.dayParam(date);
    // One slot per user: callers only ask for today.
    final slot = await _fetchSlot(
      'gamification:day_events:$userId',
      param,
      () => _remote.fetchEvents(userId, from: date, to: date),
      userId: userId,
    );
    // Offline with only an older day cached: nothing known for this one.
    if (slot.day != param) return const {};
    final totals = <ScoreCategory, int>{};
    for (final e in slot.rows.map(PointEvent.fromJson)) {
      totals[e.category] = (totals[e.category] ?? 0) + e.points;
    }
    return totals;
  }

  @override
  Future<List<PointEvent>> getHistory({int days = 30}) async {
    final userId = _remote.userId;
    if (userId == null) return const [];
    final from = lastNDays(days).first;
    final slot = await _fetchSlot(
      'gamification:history:$userId:$days',
      GamificationRemoteDataSource.dayParam(from),
      () => _remote.fetchEvents(userId, from: from),
      userId: userId,
    );
    return [
      // An offline copy from an earlier day may reach further back.
      ...slot.rows.map(PointEvent.fromJson).where((e) => !e.day.isBefore(from)),
    ];
  }

  @override
  Future<List<GameBadge>> getBadges() async {
    final userId = _remote.userId;
    if (userId == null) return const [];
    final (catalog, earned) = await (
      _fetch(
        'gamification:badges',
        remote: _remote.fetchBadges,
        decode: _rows,
        maxAge: catalogMaxAge,
      ),
      _fetch(
        'gamification:earned:$userId',
        remote: () => _remote.fetchEarnedBadges(userId),
        decode: _rows,
        userId: userId,
      ),
    ).wait;
    final earnedAt = {
      for (final e in earned)
        e['badge_code'] as String: DateTime.tryParse(
          e['earned_at'] as String? ?? '',
        ),
    };
    final progress = {
      for (final p in await _badgeProgress(userId)) p['code'] as String: p,
    };
    return [
      for (final b in catalog)
        GameBadge.fromJson(
          b,
          earnedAt: earnedAt[b['code']],
          progress: progress[b['code']],
        ),
    ];
  }

  /// Progress is a nice-to-have: badges still load without it.
  Future<List<Map<String, dynamic>>> _badgeProgress(String userId) async {
    try {
      return await _fetch(
        'gamification:badge_progress:$userId',
        remote: _remote.fetchBadgeProgress,
        decode: _rows,
        userId: userId,
      );
    } catch (e) {
      debugPrint('Badge progress unavailable: $e');
      return const [];
    }
  }

  @override
  Future<List<PointRule>> getRules() async => [
    for (final r in await _fetch(
      'gamification:rules',
      remote: _remote.fetchRules,
      decode: _rows,
      maxAge: catalogMaxAge,
    ))
      PointRule.fromJson(r),
  ];
}
