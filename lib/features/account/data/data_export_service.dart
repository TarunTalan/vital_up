import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vital_up/core/sync/backup_sync.dart';
import 'package:vital_up/core/database/collections/water_log_cache.dart';
import 'package:vital_up/core/database/collections/weight_log_cache.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_session.dart';
import 'package:vital_up/features/activity_tracking/domain/repositories/activity_repository.dart';
import 'package:vital_up/features/dashboard/data/services/sleep_service.dart';
import 'package:vital_up/features/dashboard/data/services/water_intake_service.dart';
import 'package:vital_up/features/dashboard/domain/entities/sleep_session_info.dart';
import 'package:vital_up/features/food_scanner/domain/entities/meal_log_entry.dart';
import 'package:vital_up/features/food_scanner/domain/usecases/get_meal_log_history.dart';
import 'package:vital_up/features/gamification/domain/entities/point_event.dart';
import 'package:vital_up/features/gamification/domain/repositories/gamification_repository.dart';
import 'package:vital_up/features/reminders/data/reminders_service.dart';
import 'package:vital_up/features/reminders/domain/entities/reminder.dart';
import 'package:vital_up/features/vita/domain/entities/vita_insights.dart';
import 'package:vital_up/features/vita/domain/repositories/vita_repository.dart';
import 'package:vital_up/features/weight/data/weight_service.dart';

/// Everything exported, gathered before it's written out.
class ExportData {
  final DateTime exportedAt;
  final Map<String, dynamic>? profile;
  final List<WaterLogCache> water;
  final List<SleepSessionInfo> sleep;
  final List<MealLogEntry> meals;
  final List<WeightLogCache> weight;
  final List<ActivitySession> workouts;
  final List<StressCheckIn> moods;
  final List<PointEvent> points;
  final List<Reminder> reminders;

  /// App data kept on the phone (settings, goals, Vita, workout notes, diet
  /// plan), by kind; preference values as stored.
  final Map<String, Object?> app;

  /// Arena and account rows from the server (stats, badges, daily reports,
  /// friends, communities, awards, challenges, notifications, weekly
  /// summaries), by kind. Missing kinds couldn't be fetched.
  final Map<String, Object?> server;

  const ExportData({
    required this.exportedAt,
    this.profile,
    this.water = const [],
    this.sleep = const [],
    this.meals = const [],
    this.weight = const [],
    this.workouts = const [],
    this.moods = const [],
    this.points = const [],
    this.reminders = const [],
    this.app = const {},
    this.server = const {},
  });
}

/// Settings > Account > Export my data: a zip of CSV files (open in any
/// spreadsheet) plus JSON with full detail, shared through the system share
/// sheet so the user can save or send it anywhere.
class DataExportService {
  final SupabaseClient _client;
  final WaterIntakeService _water;
  final SleepService _sleep;
  final GetMealLogHistory _meals;
  final WeightService _weight;
  final ActivityRepository _activity;
  final VitaRepository _vita;
  final GamificationRepository _game;
  final RemindersService _reminders;

  /// The same per-user sources backed up to `user_backups`, plus Vita's
  /// chat and insights (not backed up, but the user's data all the same).
  final List<BackupSource> _appSources;

  DataExportService(
    this._client,
    this._water,
    this._sleep,
    this._meals,
    this._weight,
    this._activity,
    this._vita,
    this._game,
    this._reminders,
    this._appSources,
  );

  /// Builds the zip and opens the share sheet. Returns null, or a message.
  Future<String?> exportAndShare() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 'Sign in to export your data.';
    File? file;
    try {
      final data = await _gather(userId);
      final bytes = zipExport(buildExportFiles(data));
      final day = data.exportedAt.toIso8601String().substring(0, 10);
      file = File(
        '${(await getTemporaryDirectory()).path}/vitalup-export-$day.zip',
      );
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/zip')],
          subject: 'My VitalUp data',
        ),
      );
      return null;
    } catch (e) {
      debugPrint('Export failed: $e');
      return "Couldn't create the export. Try again.";
    } finally {
      // The whole health history; don't leave a copy in the cache folder.
      try {
        if (file != null && await file.exists()) await file.delete();
      } catch (e) {
        debugPrint('Export file not deleted: $e');
      }
    }
  }

  Future<ExportData> _gather(String userId) async {
    final now = DateTime.now();
    final from = DateTime(2000);
    final to = now.add(const Duration(days: 1));

    // Server-only parts are optional: the export still works offline.
    Map<String, dynamic>? profile;
    List<PointEvent> points = const [];
    try {
      // Bounded so a bad connection can't hang the export.
      const timeout = Duration(seconds: 15);
      // Named columns: email isn't readable from profiles (it comes from
      // the session below), so select('*') would be refused.
      final account = await _client
          .from('profiles')
          .select(
            'username, display_name, avatar_url, city, country_code, '
            'leaderboard_visible, timezone',
          )
          .eq('id', userId)
          .maybeSingle()
          .timeout(timeout);
      final health = await _client
          .from('user_health_data')
          .select()
          .eq('id', userId)
          .maybeSingle()
          .timeout(timeout);
      profile = {
        'email': _client.auth.currentUser?.email,
        'account': account,
        'health': health,
      };
    } catch (e) {
      debugPrint('Export without profile: $e');
    }
    // Apart from the profile, with longer to finish: years of points are
    // read 1,000 rows at a time.
    try {
      points = await _game
          .getHistory(days: 3650)
          .timeout(const Duration(seconds: 60));
    } catch (e) {
      debugPrint('Export without points history: $e');
    }

    final app = <String, Object?>{};
    for (final source in _appSources) {
      try {
        app[source.kind] = await source.export(userId);
      } catch (e) {
        debugPrint('Export without ${source.kind}: $e');
      }
    }
    try {
      app['goal_weight_kg'] = await _weight.targetKg();
    } catch (e) {
      debugPrint('Export without goal weight: $e');
    }

    return ExportData(
      exportedAt: now,
      profile: profile,
      water: await _water.getLogsBetween(userId, from, to),
      sleep: await _sleep.getSleepBetween(from, to),
      meals: (await _meals.callAll()).getOrElse(() => const []),
      weight: await _weight.between(from, to),
      workouts: await _activity.getSessions(withRoutes: true),
      moods: _vita.getStressCheckIns(),
      points: points,
      reminders: _reminders.load(),
      app: app,
      server: await _gatherServer(userId),
    );
  }

  /// Each part on its own: one that fails (offline, timeout) is left out
  /// and the rest still exported.
  Future<Map<String, Object?>> _gatherServer(String userId) async {
    const timeout = Duration(seconds: 15);
    final parts = <String, Future<Object?> Function()>{
      'player_stats': () => _client
          .from('player_stats')
          .select(
            'total_points, nutrition_points, lifestyle_points, '
            'fitness_points, bonus_points, level, current_streak, '
            'longest_streak, last_active_day, streak_freezes, streak_start, '
            'frozen_days, updated_at',
          )
          .eq('user_id', userId)
          .maybeSingle(),
      'badges': () => _client
          .from('user_badges')
          .select('badge_code, earned_at')
          .eq('user_id', userId)
          .order('earned_at'),
      'daily_reports': () => _paged(
        (from, to) => _client
            .from('daily_reports')
            .select('day, metrics, updated_at')
            .eq('user_id', userId)
            .order('day')
            .range(from, to),
      ),
      // Friends as this user sees them: username, status and since when.
      'friends': () async => [
        for (final r in await _client.rpc('get_friends') as List)
          {
            'username': r['username'],
            'status': r['status'],
            'since': r['since'],
          },
      ],
      'communities': () => _client
          .from('community_members')
          .select('joined_at, communities(name, type)')
          .eq('user_id', userId),
      'community_awards': () =>
          _client.rpc('get_player_awards', params: {'p_user': userId}),
      'challenges': () => _client.rpc('get_challenges'),
      'notifications': () => _paged(
        (from, to) => _client
            .from('notifications')
            .select('type, title, body, data, created_at, read_at')
            .eq('user_id', userId)
            .order('created_at')
            .order('id')
            .range(from, to),
      ),
      'weekly_summaries': () => _client
          .from('weekly_summaries')
          .select('week_start, stats, sent_at')
          .eq('user_id', userId)
          .order('week_start'),
    };
    final server = <String, Object?>{};
    for (final MapEntry(key: kind, value: fetch) in parts.entries) {
      try {
        // Paged tables get longer: a page each per bounded request.
        final paged = kind == 'daily_reports' || kind == 'notifications';
        server[kind] = await fetch().timeout(
          paged ? const Duration(seconds: 60) : timeout,
        );
      } catch (e) {
        debugPrint('Export without $kind: $e');
      }
    }
    return server;
  }

  /// Every row of a query, [_page] at a time: the API returns at most
  /// 1,000 rows per request, so one plain select silently cut a long
  /// history short. [page] must order by a unique key.
  static const _page = 1000;

  Future<List<Map<String, dynamic>>> _paged(
    Future<List<Map<String, dynamic>>> Function(int from, int to) page,
  ) async {
    final rows = <Map<String, dynamic>>[];
    while (true) {
      final batch = await page(
        rows.length,
        rows.length + _page - 1,
      ).timeout(const Duration(seconds: 15));
      rows.addAll(batch);
      if (batch.length < _page) return rows;
    }
  }
}

/// File name → contents. Pure, so it can be tested.
Map<String, String> buildExportFiles(ExportData d) {
  String iso(DateTime t) => t.toIso8601String();
  return {
    'README.txt':
        'Your VitalUp data, exported ${iso(d.exportedAt)}.\n\n'
        'CSV files open in any spreadsheet app. JSON files have full detail\n'
        '(meal items and nutrition, workout GPS routes). Weights are in kg,\n'
        'distances in metres, durations in minutes or seconds as labelled.\n'
        'Meal photos stay on your phone and are not included.\n'
        'app_data.json has settings, goals, Vita chats and insights, mood\n'
        'scores, workout notes and your diet plan. arena.json has points,\n'
        'level, badges, daily reports, friends, communities, awards,\n'
        'challenges, notifications and weekly summaries.\n',
    'water.csv': csv(
      ['logged_at', 'amount_ml'],
      [
        for (final w in d.water) [iso(w.timestamp), w.amountMl],
      ],
    ),
    'sleep.csv': csv(
      ['bed_time', 'wake_time', 'duration_minutes', 'source'],
      [
        for (final s in d.sleep)
          [
            iso(s.bedTime),
            iso(s.wakeTime),
            s.duration.inMinutes,
            s.source.name,
          ],
      ],
    ),
    'meals.csv': csv(
      ['captured_at', 'meal', 'calories', 'items'],
      [
        for (final m in d.meals)
          [
            iso(m.capturedAt),
            m.mealType.name,
            m.totalCalories.round(),
            m.items.map((i) => i.name).join('; '),
          ],
      ],
    ),
    'weight.csv': csv(
      ['logged_at', 'weight_kg', 'source'],
      [
        for (final w in d.weight)
          [iso(w.timestamp), w.weightKg.toStringAsFixed(2), w.source],
      ],
    ),
    'workouts.csv': csv(
      [
        'start',
        'end',
        'type',
        'duration_seconds',
        'distance_m',
        'calories',
        'steps',
      ],
      [
        for (final s in d.workouts)
          [
            iso(s.startTime),
            s.endTime == null ? '' : iso(s.endTime!),
            s.activityType.name,
            s.totalDurationSeconds,
            s.totalDistanceMeters.round(),
            s.calories,
            s.steps,
          ],
      ],
    ),
    'mood.csv': csv(
      ['date', 'level_1_to_5', 'label', 'tags'],
      [
        for (final m in d.moods)
          [iso(m.date), m.level, m.label, m.tags.map((t) => t.name).join('; ')],
      ],
    ),
    'points.csv': csv(
      ['day', 'category', 'source', 'points'],
      [
        for (final p in d.points)
          [iso(p.day).substring(0, 10), p.category.name, p.source, p.points],
      ],
    ),
    'meals.json': _json([
      for (final m in d.meals)
        {
          'captured_at': iso(m.capturedAt),
          'meal': m.mealType.name,
          'total_calories': m.totalCalories,
          'items': [
            for (var i = 0; i < m.items.length; i++)
              {
                'name': m.items[i].name,
                'quantity': m.items[i].quantity,
                'unit': m.items[i].unit,
                'serving': m.items[i].servingDescription,
                if (i < m.nutrition.length) ...{
                  'calories': m.nutrition[i].calories,
                  'protein_g': m.nutrition[i].proteinG,
                  'carbs_g': m.nutrition[i].carbsG,
                  'fat_g': m.nutrition[i].fatG,
                  'fiber_g': m.nutrition[i].fiberG,
                  'sugar_g': m.nutrition[i].sugarG,
                  'sodium_mg': m.nutrition[i].sodiumMg,
                },
              },
          ],
        },
    ]),
    'workouts.json': _json([
      for (final s in d.workouts)
        {
          'start': iso(s.startTime),
          'end': s.endTime == null ? null : iso(s.endTime!),
          'type': s.activityType.name,
          'duration_seconds': s.totalDurationSeconds,
          'distance_m': s.totalDistanceMeters,
          'calories': s.calories,
          'steps': s.steps,
          'route': [
            for (final p in s.points)
              {
                'time': iso(p.timestamp),
                'lat': p.latitude,
                'lng': p.longitude,
                'altitude_m': p.altitude,
              },
          ],
        },
    ]),
    'reminders.json': _json([for (final r in d.reminders) r.toJson()]),
    'app_data.json': _json(decodeStoredJson(d.app)),
    if (d.server.isNotEmpty) 'arena.json': _json(d.server),
    if (d.profile != null) 'profile.json': _json(d.profile),
  };
}

/// Preferences keep lists and maps as JSON strings; decode them so the
/// export reads as one JSON document instead of escaped strings.
Object? decodeStoredJson(Object? value) {
  if (value is Map) {
    return {
      for (final e in value.entries) '${e.key}': decodeStoredJson(e.value),
    };
  }
  if (value is List) return [for (final v in value) decodeStoredJson(v)];
  if (value is String && (value.startsWith('{') || value.startsWith('['))) {
    try {
      return decodeStoredJson(jsonDecode(value));
    } on FormatException {
      return value;
    }
  }
  return value;
}

String _json(Object? value) =>
    const JsonEncoder.withIndent('  ').convert(value);

/// RFC 4180 CSV: quotes fields with commas, quotes or line breaks.
String csv(List<String> header, List<List<Object?>> rows) {
  String field(Object? v) {
    final s = v?.toString() ?? '';
    return s.contains(RegExp(r'[",\r\n]')) ? '"${s.replaceAll('"', '""')}"' : s;
  }

  return [
    header.map(field).join(','),
    for (final r in rows) r.map(field).join(','),
  ].join('\r\n');
}

List<int> zipExport(Map<String, String> files) {
  final archive = Archive();
  for (final MapEntry(key: name, value: content) in files.entries) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }
  return ZipEncoder().encode(archive);
}
