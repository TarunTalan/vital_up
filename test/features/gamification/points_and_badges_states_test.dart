import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/utils/load_timeout.dart';
import 'package:vital_up/core/widgets/load_error_view.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:vital_up/features/community/domain/entities/community_award.dart';
import 'package:vital_up/features/community/domain/repositories/community_repository.dart';
import 'package:vital_up/features/gamification/domain/entities/game_badge.dart';
import 'package:vital_up/features/gamification/domain/entities/player_stats.dart';
import 'package:vital_up/features/gamification/domain/entities/point_event.dart';
import 'package:vital_up/features/gamification/domain/entities/score_category.dart';
import 'package:vital_up/features/gamification/domain/repositories/gamification_repository.dart';
import 'package:vital_up/features/gamification/presentation/pages/badges_page.dart';
import 'package:vital_up/features/gamification/presentation/pages/points_history_page.dart';

import '../../helpers/pump_app.dart';

/// Each call to a getter takes the next queued outcome: a value, or an
/// error to throw.
class _FakeGame implements GamificationRepository {
  final stats = <Object>[];
  final history = <Object>[];
  final rules = <Object>[];
  final badges = <Object>[];
  Completer<List<GameBadge>>? pendingBadges;
  int badgeCalls = 0;

  static Future<T> _next<T>(List<Object> queue) async {
    final next = queue.removeAt(0);
    if (next is Exception) throw next;
    return next as T;
  }

  @override
  Future<PlayerStats> getStats() => _next(stats);

  @override
  Future<List<PointEvent>> getHistory({int days = 30}) => _next(history);

  @override
  Future<List<PointRule>> getRules() => _next(rules);

  @override
  Future<List<GameBadge>> getBadges() {
    badgeCalls++;
    final pending = pendingBadges;
    if (pending != null) {
      pendingBadges = null;
      return pending.future;
    }
    return _next(badges);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoAwards implements CommunityRepository {
  @override
  Future<List<CommunityAward>> getPlayerAwards([String? userId]) async =>
      const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _stats = PlayerStats(
  totalPoints: 128450,
  categoryPoints: {
    ScoreCategory.nutrition: 52300,
    ScoreCategory.lifestyle: 41200,
  },
  streak: 365,
  longestStreak: 400,
  streakFreezes: 2,
  level: GameLevel(level: 17, minPoints: 120000, title: 'Unstoppable'),
  nextLevel: GameLevel(level: 18, minPoints: 150000, title: 'Legend'),
);

final _today = DateTime.now();

final _events = [
  PointEvent(
    day: DateTime(_today.year, _today.month, _today.day),
    source: 'water_goal',
    category: ScoreCategory.lifestyle,
    points: 20,
  ),
  PointEvent(
    day: DateTime(_today.year, _today.month, _today.day - 1),
    source: 'meal_logged',
    category: ScoreCategory.nutrition,
    points: 15,
  ),
];

const _rules = [
  PointRule(
    source: 'water_goal',
    category: ScoreCategory.lifestyle,
    name: 'Reach your daily water goal',
    points: 20,
    unit: 'per day',
  ),
  PointRule(
    source: 'meal_logged',
    category: ScoreCategory.nutrition,
    name: 'Log a meal with its nutrition details',
    points: 5,
    unit: 'per meal',
    dailyCap: 15,
  ),
];

final _badges = [
  GameBadge(
    code: 'streak_7',
    name: 'Week Warrior',
    description: 'Keep a 7 day streak',
    iconKey: 'streak_7',
    bonusPoints: 50,
    threshold: 7,
    progress: 7,
    earnedAt: DateTime(2026, 10, 10),
  ),
  const GameBadge(
    code: 'steps_20k',
    name: 'Marathon Walker',
    description: 'Hit 20,000 steps in a single day',
    iconKey: 'steps_20k',
    bonusPoints: 100,
    threshold: 20000,
    progress: 12500,
  ),
  const GameBadge(
    code: 'workouts_200',
    name: 'Two Hundred Club',
    description: 'Finish 200 workouts',
    iconKey: 'workouts_200',
    bonusPoints: 300,
    threshold: 200,
    progress: 0,
  ),
];

void main() {
  late _FakeGame game;

  setUp(() {
    game = _FakeGame();
    sl.registerSingleton<GamificationRepository>(game);
    sl.registerSingleton<CommunityRepository>(_NoAwards());
  });

  tearDown(() {
    sl.unregister<GamificationRepository>();
    sl.unregister<CommunityRepository>();
  });

  void queuePoints({Object? stats, List<PointEvent>? events}) {
    game.stats.add(stats ?? _stats);
    game.history.add(events ?? _events);
    game.rules.add(_rules);
  }

  group('PointsHistoryPage', () {
    testWidgets('a failed load shows the error, and retry loads', (
      tester,
    ) async {
      queuePoints(stats: Exception('offline'));
      queuePoints();
      await pumpPage(tester, const PointsHistoryPage());
      await settle(tester);

      expect(find.text(kLoadErrorMessage), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await settle(tester);

      expect(find.byType(LoadErrorView), findsNothing);
      expect(find.text('128,450 pts'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
    });

    testWidgets('no points yet shows the first-steps note', (tester) async {
      queuePoints(stats: PlayerStats.empty, events: const []);
      await pumpPage(tester, const PointsHistoryPage());
      await settle(tester);

      expect(find.textContaining('No points yet.'), findsOneWidget);
    });

    testWidgets('fits a small phone at the largest text size', (tester) async {
      queuePoints();
      await pumpPage(
        tester,
        const PointsHistoryPage(),
        textScale: kMaxTextScale,
      );
      await settle(tester);

      expect(
        shownTextScale(tester, find.byType(PointsHistoryPage)),
        kMaxTextScale,
      );
      expect(takeAllExceptions(tester), isEmpty);
      // Every label, figure and button shows whole.
      expect(truncatedTexts(tester), isEmpty);
      expect(find.text('128,450 pts'), findsOneWidget);
    });
  });

  group('BadgesPage', () {
    testWidgets('shows the loader until badges arrive', (tester) async {
      final pending = Completer<List<GameBadge>>();
      game.pendingBadges = pending;
      await pumpPage(tester, const BadgesPage());
      await tester.pump();

      expect(find.byType(VitalUpLoader), findsOneWidget);
      pending.complete(_badges);
      await settle(tester);
      expect(find.byType(VitalUpLoader), findsNothing);
      expect(find.text('1 of 3 badges'), findsOneWidget);
    });

    testWidgets('a failed load shows the error, and retry loads', (
      tester,
    ) async {
      game.badges
        ..add(Exception('offline'))
        ..add(_badges);
      await pumpPage(tester, const BadgesPage());
      await settle(tester);

      expect(find.text(kLoadErrorMessage), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await settle(tester);

      expect(game.badgeCalls, 2);
      expect(find.text('1 of 3 badges'), findsOneWidget);
    });

    testWidgets('no badges at all says so calmly', (tester) async {
      game.badges.add(const <GameBadge>[]);
      await pumpPage(tester, const BadgesPage());
      await settle(tester);

      expect(
        find.text('No badges to show yet. Pull down to try again.'),
        findsOneWidget,
      );
    });

    testWidgets('nothing earned yet shows the encouragement note', (
      tester,
    ) async {
      game.badges.add([_badges[1], _badges[2]]);
      await pumpPage(tester, const BadgesPage());
      await settle(tester);

      expect(find.text('0 of 2 badges'), findsOneWidget);
      expect(find.textContaining('No badges yet.'), findsOneWidget);
      expect(find.text('Marathon Walker'), findsWidgets);
    });

    testWidgets('fits a small phone at the largest text size', (tester) async {
      game.badges.add(_badges);
      await pumpPage(tester, const BadgesPage(), textScale: kMaxTextScale);
      await settle(tester);

      expect(shownTextScale(tester, find.byType(BadgesPage)), kMaxTextScale);
      expect(takeAllExceptions(tester), isEmpty);
      // Every label, figure and button shows whole.
      expect(truncatedTexts(tester), isEmpty);
      expect(find.text('1 of 3 badges'), findsOneWidget);
    });
  });
}
