import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/features/challenges/data/challenges_repository.dart';
import 'package:vital_up/features/community/domain/entities/community.dart';
import 'package:vital_up/features/community/domain/entities/friend.dart';

String? _usernameError(String input) {
  try {
    normalizeFriendUsername(input);
    return null;
  } on FriendRequestException catch (e) {
    return e.message;
  }
}

void main() {
  group('normalizeFriendUsername', () {
    test('strips a leading @ and spaces', () {
      expect(normalizeFriendUsername('  @tarun_s  '), 'tarun_s');
      expect(normalizeFriendUsername('a.b'), 'a.b');
    });

    test('rejects empty, too short, too long and filter characters', () {
      expect(_usernameError(''), 'Enter a username.');
      expect(_usernameError('@'), 'Enter a username.');
      expect(_usernameError('ab'), isNotNull);
      expect(_usernameError('a' * 21), isNotNull);
      for (final bad in ['bob%', 'a,b', 'x(y)', 'bo b', 'n*me']) {
        expect(_usernameError(bad), isNotNull, reason: bad);
      }
    });
  });

  group('city sheet', () {
    test('empty city leaves the community, so anything goes', () {
      expect(cityInputError(''), isNull);
      expect(countryCodeInputError('', ''), isNull);
    });

    test('accepts real city names in any script', () {
      for (final c in [
        'Pune',
        "St. John's",
        'Rio de Janeiro',
        'M\u00FCnchen',
      ]) {
        expect(cityInputError(c), isNull, reason: c);
      }
    });

    test('rejects symbols, digits and one letter', () {
      for (final c in ['P', '123', '!!!', 'Pune%', '(x)']) {
        expect(cityInputError(c), isNotNull, reason: c);
      }
    });

    test('country code is two letters', () {
      expect(countryCodeInputError('Pune', 'IN'), isNull);
      expect(countryCodeInputError('Pune', 'I'), isNotNull);
      expect(countryCodeInputError('Pune', 'I1'), isNotNull);
    });
  });

  group('challenge create checks', () {
    String? check(ChallengeMetric m, int days, List<String> ids) =>
        ChallengesRepository.validateCreate(
          metric: m,
          days: days,
          friendIds: ids,
        );

    test('valid request passes', () {
      expect(check(ChallengeMetric.workouts, 7, ['a']), isNull);
    });

    test('rejects unsupported metric, length and friend counts', () {
      expect(check(ChallengeMetric.xp, 7, ['a']), isNotNull);
      expect(check(ChallengeMetric.workouts, 0, ['a']), isNotNull);
      expect(check(ChallengeMetric.workouts, 5, ['a']), isNotNull);
      expect(check(ChallengeMetric.workouts, 7, []), isNotNull);
      expect(
        check(ChallengeMetric.workouts, 7, [for (var i = 0; i < 10; i++) '$i']),
        isNotNull,
      );
      // Duplicates count once.
      expect(check(ChallengeMetric.workouts, 7, ['a', 'a']), isNull);
    });

    test('unknown server errors never leak raw text', () {
      expect(
        ChallengeException.fromServer('relation "x" does not exist').message,
        'Something went wrong. Try again.',
      );
    });
  });
}
