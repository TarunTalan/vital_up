import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/features/onboarding/domain/usecases/calculate_calorie_goal.dart';
import 'package:vital_up/features/profile/domain/profile_rules.dart';

void main() {
  final now = DateTime(2026, 10, 9);

  group('name', () {
    test('accepts hyphens, apostrophes and accented letters', () {
      expect(ProfileRules.nameError('Anne-Marie'), isNull);
      expect(ProfileRules.nameError("O'Brien"), isNull);
      expect(ProfileRules.nameError('Jos\u00E9 Ram\u00EDrez'), isNull);
    });

    test('rejects empty, too short and digits', () {
      expect(ProfileRules.nameError('   '), 'Enter your name');
      expect(ProfileRules.nameError('A'), isNotNull);
      expect(ProfileRules.nameError('R2D2'), isNotNull);
      expect(ProfileRules.nameError('-Ann'), isNotNull);
    });

    test('cleanName trims, collapses spaces and drops invisible chars', () {
      expect(ProfileRules.cleanName('  Ann \u200B  Lee '), 'Ann Lee');
      expect(ProfileRules.cleanName('a' * 80).length, 50);
    });
  });

  group('date of birth', () {
    test('parses valid dates and rejects impossible ones', () {
      expect(ProfileRules.parseDob('29022000'), DateTime(2000, 2, 29));
      expect(ProfileRules.parseDob('29022001'), isNull);
      expect(ProfileRules.parseDob('31042000'), isNull);
      expect(ProfileRules.parseDob('00012000'), isNull);
      expect(ProfileRules.parseDob('1501200'), isNull);
      expect(ProfileRules.parseDob('ab012000'), isNull);
    });

    test('formatDob round-trips', () {
      final date = DateTime(1997, 2, 4);
      expect(ProfileRules.formatDob(date), '04021997');
      expect(ProfileRules.parseDob(ProfileRules.formatDob(date)), date);
    });

    test('rejects future dates, under 13 and over 120', () {
      expect(ProfileRules.dobError('', now: now), isNotNull);
      expect(ProfileRules.dobError('10102026', now: now), contains('future'));
      expect(ProfileRules.dobError('10102013', now: now), contains('13'));
      expect(ProfileRules.dobError('09102013', now: now), isNull);
      expect(ProfileRules.dobError('01011900', now: now), isNotNull);
    });

    test('leap day birthday ages on 1 March in non-leap years', () {
      final dob = DateTime(2008, 2, 29);
      expect(ProfileRules.ageOn(dob, DateTime(2025, 2, 28)), 16);
      expect(ProfileRules.ageOn(dob, DateTime(2025, 3, 1)), 17);
    });

    test('picker range covers supported ages and clamps', () {
      expect(ProfileRules.lastDob(now), DateTime(2013, 10, 9));
      expect(ProfileRules.firstDob(now), DateTime(1906, 10, 9));
      expect(ProfileRules.clampDob(DateTime(2020), now), DateTime(2013, 10, 9));
      // 29 Feb today: the boundary falls back to 28 Feb.
      expect(ProfileRules.lastDob(DateTime(2024, 2, 29)), DateTime(2011, 2, 28));
    });

    test('calorie goal age ignores impossible and future dates', () {
      expect(CalculateCalorieGoal.ageFromDob('31022000', now: now), isNull);
      expect(CalculateCalorieGoal.ageFromDob('01012030', now: now), isNull);
      expect(CalculateCalorieGoal.ageFromDob('09101996', now: now), 30);
    });
  });

  group('body ranges', () {
    test('height and weight limits', () {
      expect(ProfileRules.heightError(170), isNull);
      expect(ProfileRules.heightError(30), isNotNull);
      expect(ProfileRules.heightError(300), isNotNull);
      expect(ProfileRules.heightError(null), isNotNull);
      expect(ProfileRules.weightError(70), isNull);
      expect(ProfileRules.weightError(5), isNotNull);
      expect(ProfileRules.weightError(400), isNotNull);
    });

    test('imperial heights convert inside the range', () {
      // 8 ft 11 in is the tallest the ft/in fields allow.
      expect(ProfileRules.heightError((8 * 12 + 11) * 2.54), isNull);
      expect(ProfileRules.heightError((1 * 12 + 8) * 2.54), isNull);
      expect(ProfileRules.heightError((1 * 12 + 7) * 2.54), isNotNull);
    });
  });

  test('cleanNote keeps a single line and caps length', () {
    expect(ProfileRules.cleanNote(' Asthma,\n  pollen '), 'Asthma, pollen');
    expect(ProfileRules.cleanNote('x' * 900).length, 500);
  });
}
