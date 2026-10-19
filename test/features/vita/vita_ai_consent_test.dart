import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/features/vita/data/services/health_snapshot_builder.dart';
import 'package:vital_up/features/vita/data/services/vita_ai_consent.dart';
import 'package:vital_up/features/vita/domain/entities/health_snapshot.dart';

void main() {
  group('VitaAiConsent', () {
    late SharedPreferences prefs;
    String? user = 'u1';

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      user = 'u1';
    });

    VitaAiConsent consent() => VitaAiConsent(prefs, userId: () => user);

    test('nothing is allowed by default', () {
      expect(consent().accepted, isFalse);
      expect(consent().includeHealthConnect, isFalse);
    });

    test('accept keeps the Health Connect choice, per user', () async {
      await consent().accept(includeHealthConnect: true);
      expect(consent().accepted, isTrue);
      expect(consent().includeHealthConnect, isTrue);

      user = 'u2';
      expect(consent().accepted, isFalse);
      expect(consent().includeHealthConnect, isFalse);
    });

    test('Health Connect opt-in needs acceptance first', () async {
      await consent().setIncludeHealthConnect(true);
      expect(consent().includeHealthConnect, isFalse);

      await consent().accept(includeHealthConnect: false);
      expect(consent().includeHealthConnect, isFalse);
      await consent().setIncludeHealthConnect(true);
      expect(consent().includeHealthConnect, isTrue);
    });

    test('withdraw turns everything off', () async {
      await consent().accept(includeHealthConnect: true);
      await consent().withdraw();
      expect(consent().accepted, isFalse);
      expect(consent().includeHealthConnect, isFalse);
    });

    test('signed out: never accepted, writes nothing', () async {
      user = null;
      await consent().accept(includeHealthConnect: true);
      expect(consent().accepted, isFalse);
      expect(prefs.getKeys(), isEmpty);
    });
  });

  group('HealthSnapshot.forAi', () {
    final full = HealthSnapshot(
      takenAt: DateTime(2026, 10, 18, 9),
      profile: const ProfileSnapshot(age: 31, medicines: 'Metformin'),
      mealsToday: 2,
      sleepLastNightHours: 7.5,
      sleepAvgHours: 7.2,
      sleepNightsLogged: 5,
      sleepLastNightFromHealthConnect: true,
      loggedSleepLastNightHours: 6,
      loggedSleepAvgHours: 6.5,
      loggedSleepNights: 4,
      stepsToday: 9000,
      stepsFromHealthConnect: true,
      workoutStepsToday: 1200,
      workoutsThisWeek: 3,
      distanceThisWeekKm: 12,
      activeMinutesThisWeek: 90,
      importedWorkoutsThisWeek: 1,
      importedDistanceThisWeekKm: 5,
      importedActiveMinutesThisWeek: 30,
      vitals: const VitalsSnapshot(
        connected: true,
        restingHeartRate: 58,
        hrvMs: 45,
        spo2Percent: 97,
        systolic: 120,
        diastolic: 80,
      ),
    );

    test('with the opt-in, everything is sent', () {
      expect(full.forAi(includeHealthConnect: true).toJson(), full.toJson());
    });

    test('without it, Health Connect data is left out', () {
      final json = full.forAi(includeHealthConnect: false).toJson();
      expect(json.containsKey('vitals'), isFalse);
      expect(json['sleep'], {
        'lastNightHours': 6,
        'avgHoursLast7Days': 6.5,
        'nightsLogged': 4,
      });
      final activity = json['activity'] as Map<String, dynamic>;
      expect(activity['stepsToday'], 1200);
      expect(activity['workoutsLast7Days'], 2);
      expect(activity['distanceLast7DaysKm'], 7.0);
      expect(activity['activeMinutesLast7Days'], 60);
      // App logs and health answers stay.
      expect((json['diet'] as Map)['mealsToday'], 2);
      expect((json['profile'] as Map)['medicines'], 'Metformin');
    });

    test('steps and sleep logged in the app are kept without the opt-in', () {
      final own = HealthSnapshot(
        takenAt: DateTime(2026, 10, 18),
        profile: const ProfileSnapshot(),
        stepsToday: 1500,
        workoutStepsToday: 1500,
        sleepLastNightHours: 7,
        loggedSleepLastNightHours: 7,
        loggedSleepAvgHours: 7,
        sleepNightsLogged: 1,
        loggedSleepNights: 1,
      ).forAi(includeHealthConnect: false).toJson();
      expect((own['activity'] as Map)['stepsToday'], 1500);
      expect((own['sleep'] as Map)['lastNightHours'], 7);
    });
  });

  group('HealthSnapshotBuilder.ageFromDob', () {
    test('reads ddMMyyyy, the stored format', () {
      final now = DateTime.now();
      final y = now.year - 30;
      expect(HealthSnapshotBuilder.ageFromDob('0101$y'), 30);
    });

    test('older dd/MM/yyyy values still work', () {
      final y = DateTime.now().year - 40;
      expect(HealthSnapshotBuilder.ageFromDob('01/01/$y'), 40);
    });

    test('day 19-31 is not read as a year', () {
      // "20061995" used to be parsed as the year 2006.
      final age = HealthSnapshotBuilder.ageFromDob('20061995');
      final now = DateTime.now();
      final hadBirthday =
          now.month > 6 || (now.month == 6 && now.day >= 20);
      expect(age, now.year - 1995 - (hadBirthday ? 0 : 1));
    });

    test('garbage gives null', () {
      expect(HealthSnapshotBuilder.ageFromDob(''), isNull);
      expect(HealthSnapshotBuilder.ageFromDob('31021990'), isNull);
    });
  });
}
