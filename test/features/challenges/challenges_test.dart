import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/features/challenges/data/challenges_repository.dart';
import 'package:vital_up/features/challenges/presentation/widgets/challenge_tile.dart';

void main() {
  test('scores are shown in the metric unit', () {
    expect(ChallengeMetric.activeMinutes.format(42.0), '42 min');
    expect(ChallengeMetric.distanceKm.format(12.46), '12.5 km');
    expect(ChallengeMetric.workouts.format(1), '1 workout');
    expect(ChallengeMetric.workouts.format(3), '3 workouts');
    expect(ChallengeMetric.points.format(120), '120 pts');
    expect(ChallengeMetric.nutritionPoints.format(45), '45 pts');
    expect(ChallengeMetric.steps.format(8400), '8,400 steps');
    expect(ChallengeMetric.steps.format(123456), '123K steps');
  });

  test('every metric has a server code and unknown codes fall back', () {
    expect(ChallengeMetric.values.map((m) => m.code).toSet(), {
      'points',
      'nutrition_points',
      'wellbeing_points',
      'steps',
      'active_minutes',
      'workouts',
      'distance_km',
    });
    expect(
      ChallengeMetric.fromCode('nutrition_points'),
      ChallengeMetric.nutritionPoints,
    );
    expect(ChallengeMetric.fromCode('xp'), ChallengeMetric.activeMinutes);
    expect(ChallengeMetric.points.isDaily, isTrue);
    expect(ChallengeMetric.distanceKm.isDaily, isFalse);
  });

  test('names and notes read naturally for one day', () {
    expect(challengeName(ChallengeMetric.points, 1), 'Most points in 1 day');
    expect(challengeName(ChallengeMetric.steps, 7), 'Most steps in 7 days');
    expect(
      challengeWindowNote(ChallengeMetric.points, 1),
      'Counts today, until midnight.',
    );
    expect(
      challengeWindowNote(ChallengeMetric.points, 7),
      'Counts today and the next 6 days.',
    );
    expect(
      challengeWindowNote(ChallengeMetric.workouts, 1),
      'Counts workouts from now for 24 hours.',
    );
  });

  Challenge challenge(ChallengeMetric metric, DateTime start, DateTime end) =>
      Challenge(
        id: 'c',
        metric: metric,
        startsAt: start,
        endsAt: end,
        creatorUsername: 'sam',
        myStatus: ParticipantStatus.joined,
        participants: 2,
      );

  test('daily challenges end at midnight and count calendar days', () {
    // Created at 6 pm, runs today and the next 6 days.
    final week = challenge(
      ChallengeMetric.points,
      DateTime(2026, 10, 5, 18),
      DateTime(2026, 10, 12),
    );
    expect(challengeDays(week), 7);
    expect(challengeTitle(week), 'Most points · 7 days');
    expect(challengeDayLabel(week, DateTime(2026, 10, 6, 7)), 'Day 2 of 7');
    expect(challengeDayLabel(week, DateTime(2026, 10, 11, 23)), 'Day 7 of 7');

    // One day created late in the evening is still "1 day".
    final today = challenge(
      ChallengeMetric.steps,
      DateTime(2026, 10, 5, 23, 30),
      DateTime(2026, 10, 6),
    );
    expect(challengeDays(today), 1);
    expect(challengeTitle(today), 'Most steps · 1 day');
    expect(
      challengeDayLabel(today, DateTime(2026, 10, 5, 23, 45)),
      'Day 1 of 1',
    );
  });

  test('workout challenges keep rolling 24 h days', () {
    final start = DateTime(2026, 10, 5, 18);
    final c = challenge(
      ChallengeMetric.workouts,
      start,
      start.add(const Duration(days: 3)),
    );
    expect(challengeDays(c), 3);
    expect(challengeDayLabel(c, DateTime(2026, 10, 6, 7)), 'Day 1 of 3');
    expect(
      challengeDays(
        challenge(
          ChallengeMetric.workouts,
          start,
          start.add(const Duration(days: 1)),
        ),
      ),
      1,
    );
    // A week across a clock change: 6 days 23 h or 7 days 1 h.
    expect(
      challengeDays(
        challenge(
          ChallengeMetric.workouts,
          start,
          start.add(const Duration(days: 6, hours: 23)),
        ),
      ),
      7,
    );
    expect(
      challengeDays(
        challenge(
          ChallengeMetric.workouts,
          start,
          start.add(const Duration(days: 7, hours: 1)),
        ),
      ),
      7,
    );
  });

  test('parses a challenge row from get_challenges', () {
    final c = Challenge.fromJson({
      'id': 'c1',
      'metric': 'distance_km',
      'starts_at': '2026-10-01T06:00:00Z',
      'ends_at': '2026-10-08T06:00:00Z',
      'creator_username': 'sam',
      'my_status': 'joined',
      'participants': 3,
      'my_score': 12.5,
      'my_rank': 1,
    });
    expect(c.metric, ChallengeMetric.distanceKm);
    expect(c.myStatus, ParticipantStatus.joined);
    expect(c.endsAt.difference(c.startsAt).inDays, 7);
    expect(c.isActiveAt(DateTime.utc(2026, 10, 5)), isTrue);
    expect(c.isActiveAt(DateTime.utc(2026, 10, 9)), isFalse);
  });

  test('server error codes become readable messages', () {
    expect(
      ChallengeException.fromServer('ERROR: too_many_friends').message,
      'You can challenge up to 9 friends at once.',
    );
    expect(
      ChallengeException.fromServer('something else').message,
      'Something went wrong. Try again.',
    );
  });
}
