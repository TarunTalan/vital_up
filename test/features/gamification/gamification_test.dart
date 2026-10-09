import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/core/cache/cache_store.dart';
import 'package:vital_up/core/network/connectivity_service.dart';
import 'package:vital_up/features/activity_goals/domain/entities/activity_goal.dart';
import 'package:vital_up/features/gamification/data/datasources/gamification_remote_datasource.dart';
import 'package:vital_up/features/gamification/data/repositories/gamification_repository_impl.dart';
import 'package:vital_up/features/gamification/data/services/daily_metrics_collector.dart';
import 'package:vital_up/features/gamification/domain/entities/award_result.dart';
import 'package:vital_up/features/gamification/domain/entities/daily_metrics.dart';
import 'package:vital_up/features/gamification/domain/entities/game_badge.dart';
import 'package:vital_up/features/gamification/domain/entities/player_stats.dart';
import 'package:vital_up/features/gamification/domain/entities/point_event.dart';
import 'package:vital_up/features/gamification/domain/entities/score_category.dart';
import 'package:vital_up/features/gamification/domain/repositories/gamification_repository.dart';
import 'package:vital_up/features/gamification/presentation/cubit/gamification_cubit.dart';
import 'package:vital_up/features/gamification/presentation/widgets/reward_celebration_dialog.dart';

const _levels = [
  GameLevel(level: 1, minPoints: 0, title: 'Starter'),
  GameLevel(level: 2, minPoints: 100, title: 'Mover'),
  GameLevel(level: 3, minPoints: 250, title: 'Go-Getter'),
];

class _FakeCollector implements DailyMetricsCollector {
  final collected = <DateTime>[];
  int foodLogs = 2;

  @override
  Future<DailyMetrics> collect(String userId, DateTime day, {DateTime? now}) async {
    collected.add(day);
    return DailyMetrics(day: day, foodLogs: foodLogs);
  }
}

class _FakeRemote implements GamificationRemoteDataSource {
  @override
  String? userId = 'u1';
  final submitted = <DailyMetrics>[];
  Map<String, dynamic> Function(DailyMetrics) respond =
      (_) => {'points_awarded': 6, 'level': 1, 'level_up': false, 'streak': 0};
  bool fail = false;

  /// Reads throw as if there were no network.
  bool offline = false;
  int statsFetches = 0;
  int levelFetches = 0;
  int eventFetches = 0;
  Map<String, dynamic>? stats = {'total_points': 120};

  @override
  Future<Map<String, dynamic>> submitDailyReport(DailyMetrics metrics) async {
    if (fail) throw Exception('offline');
    submitted.add(metrics);
    return respond(metrics);
  }

  @override
  Future<Map<String, dynamic>?> fetchStats(String userId) async {
    if (offline) throw const SocketException('Failed host lookup');
    statsFetches++;
    return stats;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchLevels() async {
    if (offline) throw const SocketException('Failed host lookup');
    levelFetches++;
    return [
      for (final l in _levels)
        {'level': l.level, 'min_points': l.minPoints, 'title': l.title},
    ];
  }
  @override
  Future<List<Map<String, dynamic>>> fetchBadges() async => const [];
  @override
  Future<List<Map<String, dynamic>>> fetchEarnedBadges(String userId) async => const [];
  @override
  Future<List<Map<String, dynamic>>> fetchBadgeProgress() async => const [];
  @override
  Future<List<Map<String, dynamic>>> fetchEvents(
    String userId, {
    required DateTime from,
    DateTime? to,
  }) async {
    if (offline) throw const SocketException('Failed host lookup');
    eventFetches++;
    return [
      {
        'day': GamificationRemoteDataSource.dayParam(from),
        'source': 'food_log',
        'category': 'nutrition',
        'points': 6,
      },
    ];
  }
  @override
  Future<List<Map<String, dynamic>>> fetchRules() async => const [];
}

class _FakeRepository implements GamificationRepository {
  int syncs = 0;
  AwardResult? award;

  @override
  Future<AwardResult?> sync() async {
    syncs++;
    return award;
  }

  @override
  Future<PlayerStats> getStats() async => PlayerStats.empty;
  @override
  Future<Map<ScoreCategory, int>> getPointsForDay(DateTime day) async =>
      const {ScoreCategory.nutrition: 6};
  @override
  Future<List<PointEvent>> getHistory({int days = 30}) async => const [];
  @override
  Future<List<GameBadge>> getBadges() async => const [];
  @override
  Future<List<PointRule>> getRules() async => const [];
}

CacheStore _cache() => CacheStore(
  ConnectivityService(),
  directory: Directory.systemTemp.createTempSync('gamification_cache'),
);

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

DateTime _daysAgo(int n) {
  final t = _today();
  return DateTime(t.year, t.month, t.day - n);
}

void main() {
  group('PlayerStats.fromRow', () {
    test('picks the level the points fall in and progress to the next', () {
      final stats = PlayerStats.fromRow(
        {'total_points': 175, 'nutrition_points': 100, 'fitness_points': 75},
        _levels,
        effectiveStreak: 3,
      );
      expect(stats.level.level, 2);
      expect(stats.nextLevel?.level, 3);
      expect(stats.levelProgress, closeTo(0.5, 1e-9));
      expect(stats.pointsToNextLevel, 75);
      expect(stats.pointsIn(ScoreCategory.nutrition), 100);
      expect(stats.pointsIn(ScoreCategory.lifestyle), 0);
      expect(stats.streak, 3);
    });

    test('a level threshold counts as reaching that level', () {
      final stats = PlayerStats.fromRow({'total_points': 100}, _levels, effectiveStreak: 0);
      expect(stats.level.level, 2);
      expect(stats.levelProgress, 0);
    });

    test('top level has no next level and full progress', () {
      final stats = PlayerStats.fromRow({'total_points': 999}, _levels, effectiveStreak: 0);
      expect(stats.level.level, 3);
      expect(stats.nextLevel, isNull);
      expect(stats.levelProgress, 1);
      expect(stats.pointsToNextLevel, 0);
    });

    test('no row yet means level 1 with zero points', () {
      final stats = PlayerStats.fromRow(null, _levels, effectiveStreak: 0);
      expect(stats.totalPoints, 0);
      expect(stats.level.level, 1);
    });
  });

  group('effectiveStreak', () {
    final now = DateTime(2026, 10, 10, 9);

    test('alive when today or yesterday was active', () {
      expect(effectiveStreak(5, DateTime(2026, 10, 10), now: now), 5);
      expect(effectiveStreak(5, DateTime(2026, 10, 9), now: now), 5);
    });

    test('broken after a whole missed day', () {
      expect(effectiveStreak(5, DateTime(2026, 10, 8), now: now), 0);
      expect(effectiveStreak(5, null, now: now), 0);
    });
  });

  test('DailyMetrics.toJson uses the keys submit_daily_report reads', () {
    final json = DailyMetrics(
      day: DateTime(2026, 10, 1),
      steps: 9000,
      dailyGoalsAchieved: const {GoalMetric.steps, GoalMetric.activeMinutes},
      weeklyGoalsAchieved: const {GoalMetric.workouts},
      sleepHours: 7.256,
      moodCheckIn: true,
      moodLevel: 2,
    ).toJson();
    expect(json.keys.toSet(), {
      'steps', 'distance_m', 'active_minutes', 'calories', 'workouts',
      'daily_goals', 'weekly_goals', 'food_logs', 'water_logs',
      'water_goal_met', 'planned_meals', 'planned_meals_logged',
      'calorie_goal_met', 'sleep_logged', 'sleep_hours', 'mood_checkin',
      'mood_level',
    });
    // Metric names must match the server's allow-list.
    expect(json['daily_goals'], containsAll(['steps', 'activeMinutes']));
    expect(json['weekly_goals'], ['workouts']);
    expect(json['sleep_hours'], 7.26);
  });

  test('AwardResult parses the RPC response and merges days', () {
    final a = AwardResult.fromJson({
      'points_awarded': 40,
      'level': 2,
      'level_up': true,
      'streak': 3,
      'new_badges': [
        {'code': 'streak_3', 'name': 'Warming Up', 'description': 'd', 'icon_key': 'streak_3'},
      ],
    });
    expect(a.celebrate, isTrue);
    expect(a.newBadges.single.code, 'streak_3');
    final merged = a.merge(const AwardResult(
      pointsAwarded: 5, level: 2, levelUp: false, streak: 4, newBadges: [],
    ));
    expect(merged.pointsAwarded, 45);
    expect(merged.levelUp, isTrue);
    expect(merged.streak, 4);
  });

  group('GamificationRepositoryImpl.sync', () {
    late _FakeRemote remote;
    late _FakeCollector collector;
    late SharedPreferences prefs;
    late CacheStore cache;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      remote = _FakeRemote();
      collector = _FakeCollector();
      cache = _cache();
    });

    GamificationRepositoryImpl repo() => GamificationRepositoryImpl(
      remote: remote,
      collector: collector,
      prefs: prefs,
      cache: cache,
    );

    test('first sync reports today only', () async {
      final result = await repo().sync();
      expect(collector.collected, [_today()]);
      expect(result?.pointsAwarded, 6);
    });

    test('re-sends the last synced day and every day since, oldest first', () async {
      await prefs.setString(
        'gamification_synced_day_u1',
        GamificationRemoteDataSource.dayParam(_daysAgo(1)),
      );
      final result = await repo().sync();
      expect(collector.collected, [_daysAgo(1), _today()]);
      expect(result?.pointsAwarded, 12);
    });

    test('backfills at most two days', () async {
      await prefs.setString(
        'gamification_synced_day_u1',
        GamificationRemoteDataSource.dayParam(_daysAgo(10)),
      );
      await repo().sync();
      expect(collector.collected, [_daysAgo(2), _daysAgo(1), _today()]);
    });

    test('a failed submit keeps the day for the next sync', () async {
      remote.fail = true;
      await expectLater(repo().sync(), throwsException);
      expect(prefs.getString('gamification_synced_day_u1'), isNull);
    });

    test('signed out does nothing', () async {
      remote.userId = null;
      expect(await repo().sync(), isNull);
      expect(collector.collected, isEmpty);
    });

    test('days whose metrics did not change are not re-sent', () async {
      final r = repo();
      await r.sync();
      expect(await r.sync(), isNull);
      expect(remote.submitted, hasLength(1));

      collector.foodLogs = 3;
      await r.sync();
      expect(remote.submitted, hasLength(2));
    });

    test('overlapping syncs share one run', () async {
      final r = repo();
      await Future.wait([r.sync(), r.sync(), r.sync()]);
      expect(remote.submitted, hasLength(1));
    });

    test('a day the server no longer accepts is skipped', () async {
      final oldest = _daysAgo(2);
      await prefs.setString(
        'gamification_synced_day_u1',
        GamificationRemoteDataSource.dayParam(oldest),
      );
      remote.respond = (m) => m.day == oldest
          ? throw Exception('day out of range')
          : {'points_awarded': 6};
      final result = await repo().sync();
      expect(result?.pointsAwarded, 12);
      expect(
        prefs.getString('gamification_synced_day_u1'),
        GamificationRemoteDataSource.dayParam(_today()),
      );
    });
  });

  group('GamificationRepositoryImpl reads', () {
    late _FakeRemote remote;
    late SharedPreferences prefs;
    late CacheStore cache;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      remote = _FakeRemote();
      cache = _cache();
    });

    GamificationRepositoryImpl repo() => GamificationRepositoryImpl(
      remote: remote,
      collector: _FakeCollector(),
      prefs: prefs,
      cache: cache,
    );

    test('fresh copies are shared across callers', () async {
      final r = repo();
      final (a, b, today) = await (
        r.getStats(),
        r.getStats(),
        r.getPointsForDay(DateTime.now()),
      ).wait;
      await r.getStats();
      await r.getPointsForDay(DateTime.now());
      expect(a.level.level, 2);
      expect(b.totalPoints, 120);
      expect(today, {ScoreCategory.nutrition: 6});
      expect(remote.statsFetches, 1);
      expect(remote.levelFetches, 1);
      expect(remote.eventFetches, 1);
    });

    test('offline returns the last copy instead of failing', () async {
      final r = repo();
      await r.getStats();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await r.sync(); // Marks the cached score stale.
      remote.offline = true;
      final stats = await r.getStats();
      expect(stats.totalPoints, 120);
      expect(remote.statsFetches, 1);
    });

    test('offline with nothing cached throws', () async {
      remote.offline = true;
      await expectLater(repo().getStats(), throwsA(anything));
    });

    test('a report that reached the server refreshes the score', () async {
      final r = repo();
      await r.getStats();
      await r.getPointsForDay(DateTime.now());
      // The report must land strictly after the cached copies.
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await r.sync();
      remote.stats = {'total_points': 300};
      expect((await r.getStats()).totalPoints, 300);
      await r.getPointsForDay(DateTime.now());
      expect(remote.statsFetches, 2);
      expect(remote.eventFetches, 2);
      // Levels are reference data and stay cached.
      expect(remote.levelFetches, 1);
    });
  });

  group('GamificationCubit', () {
    testWidgets('debounces bursts of sync requests into one', (tester) async {
      final repo = _FakeRepository();
      final cubit = GamificationCubit(repo);
      cubit
        ..sync()
        ..sync()
        ..sync();
      await tester.pump(GamificationCubit.syncDebounce + const Duration(milliseconds: 100));
      await tester.pump();
      expect(repo.syncs, 1);
      expect(cubit.state.todayTotal, 6);
      await cubit.close();
    });

    testWidgets('syncs when the network comes back', (tester) async {
      final repo = _FakeRepository();
      final online = StreamController<bool>.broadcast();
      final cubit = GamificationCubit(repo, onlineChanges: online.stream);
      online
        ..add(false)
        ..add(true);
      await tester.pump(GamificationCubit.syncDebounce + const Duration(milliseconds: 100));
      await tester.pump();
      expect(repo.syncs, 1);
      await cubit.close();
      await online.close();
    });

    testWidgets('emits a new award id for level-ups and badges', (tester) async {
      final repo = _FakeRepository()
        ..award = const AwardResult(
          pointsAwarded: 50, level: 2, levelUp: true, streak: 1, newBadges: [],
        );
      final cubit = GamificationCubit(repo);
      await tester.runAsync(cubit.syncNow);
      expect(cubit.state.awardId, 1);
      expect(cubit.state.award?.levelUp, isTrue);
      await cubit.close();
    });
  });

  group('rest days', () {
    const level = GameLevel(level: 1, minPoints: 0, title: 'Starter');

    test('stats read banked rest days and days to the next one', () {
      final stats = PlayerStats.fromRow(
        {'streak_freezes': 1, 'current_streak': 9},
        const [level],
        effectiveStreak: 9,
      );
      expect(stats.streakFreezes, 1);
      expect(stats.daysToNextFreeze, 5);
      expect(
        PlayerStats.fromRow(
          {'streak_freezes': 2},
          const [level],
          effectiveStreak: 3,
        ).daysToNextFreeze,
        0,
      );
    });

    test('a rest day earned or used is worth a quiet note', () {
      final used = AwardResult.fromJson({
        'streak': 8,
        'freezes_used': 1,
        'freeze_earned': false,
      });
      expect(used.celebrate, isFalse);
      expect(used.notable, isTrue);
      expect(awardMessage(used), 'A rest day kept your 8-day streak going');

      final earned = AwardResult.fromJson({'freeze_earned': true});
      expect(earned.notable, isTrue);
      expect(awardMessage(earned), startsWith('Rest day earned'));

      final merged = used.merge(earned);
      expect(merged.freezeEarned, isTrue);
      expect(merged.freezesUsed, 1);
    });

    test('nothing new is not notable', () {
      expect(AwardResult.fromJson({'points_awarded': 12}).notable, isFalse);
    });
  });

  test('locked badges show progress, earned ones do not', () {
    const json = {
      'code': 'workouts_25',
      'name': 'Regular',
      'description': 'Complete 25 workouts',
      'threshold': 25,
    };
    final locked = GameBadge.fromJson(
      json,
      progress: {'code': 'workouts_25', 'value': 7, 'threshold': 25},
    );
    expect(locked.progress, 7);
    expect(locked.progressFraction, closeTo(0.28, 1e-9));
    final earned = GameBadge.fromJson(
      json,
      earnedAt: DateTime(2026, 10, 1),
      progress: {'code': 'workouts_25', 'value': 30, 'threshold': 25},
    );
    expect(earned.progressFraction, isNull);
    expect(GameBadge.fromJson(json).progressFraction, isNull);
  });
}
