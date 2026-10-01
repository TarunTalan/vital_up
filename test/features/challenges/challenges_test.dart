import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/features/challenges/data/challenges_repository.dart';

void main() {
  test('scores are shown in the metric unit', () {
    expect(ChallengeMetric.activeMinutes.format(42.0), '42 min');
    expect(ChallengeMetric.distanceKm.format(12.46), '12.5 km');
    expect(ChallengeMetric.workouts.format(1), '1 workout');
    expect(ChallengeMetric.workouts.format(3), '3 workouts');
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
      "Couldn't reach the server. Try again.",
    );
  });
}
