import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/core/preferences/workout_prefs_notifier.dart';
import 'package:vital_up/features/activity_tracking/data/services/workout_timer_store.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/workout_timer.dart';
import 'package:vital_up/features/activity_tracking/domain/services/timer_coach_rules.dart';
import 'package:vital_up/features/activity_tracking/services/timer_voice_coach.dart';
import 'package:vital_up/features/activity_tracking/services/voice_coach_service.dart';

class _Voice implements VoiceCoachService {
  final said = <String>[];

  @override
  Future<void> say(String text) async => said.add(text);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Duration _m(int minutes, [int seconds = 0]) =>
    Duration(minutes: minutes, seconds: seconds);

void main() {
  group('timerCue', () {
    test('every 5 minutes: time, calories and what is left', () {
      expect(
        timerCue(
          before: _m(4, 55),
          now: _m(5),
          caloriesBefore: 39,
          caloriesNow: 40,
          target: (type: WorkoutTargetType.duration, value: 30),
        ),
        '5 minutes. About 40 calories. 25 minutes to your goal.',
      );
      expect(
        timerCue(
          before: _m(59, 58),
          now: _m(60, 3),
          caloriesBefore: 480,
          caloriesNow: 482,
        ),
        '1 hour. About 482 calories.',
      );
    });

    test('nothing between the marks', () {
      expect(
        timerCue(
          before: _m(6),
          now: _m(6, 5),
          caloriesBefore: 50,
          caloriesNow: 51,
        ),
        isNull,
      );
    });

    test('halfway and reached win over the 5-minute cue', () {
      const goal = (type: WorkoutTargetType.duration, value: 20.0);
      expect(
        timerCue(
          before: _m(9, 58),
          now: _m(10, 2),
          caloriesBefore: 80,
          caloriesNow: 81,
          target: goal,
        ),
        'Halfway to your 20-minute goal.',
      );
      expect(
        timerCue(
          before: _m(19, 58),
          now: _m(20, 2),
          caloriesBefore: 160,
          caloriesNow: 161,
          target: goal,
        ),
        'Goal reached. 20 minutes. Great work.',
      );
    });

    test('a calorie goal counts calories', () {
      expect(
        timerCue(
          before: _m(12),
          now: _m(12, 5),
          caloriesBefore: 99,
          caloriesNow: 101,
          target: (type: WorkoutTargetType.calories, value: 200),
        ),
        'Halfway to your 200-calorie goal.',
      );
    });
  });

  group('TimerVoiceCoach', () {
    late WorkoutTimerStore store;
    late _Voice voice;
    late DateTime clock;
    late TimerVoiceCoach coach;
    var voiceOn = true;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = WorkoutTimerStore(await SharedPreferences.getInstance());
      voice = _Voice();
      clock = DateTime(2026, 10, 22, 18);
      voiceOn = true;
      coach = TimerVoiceCoach(
        store: store,
        voice: voice,
        weightKg: () async => 70,
        prefs: () async => WorkoutPrefs(
          voiceCoachEnabled: voiceOn,
          timerTargetType: WorkoutTargetType.duration,
          timerTargetValue: 30,
        ),
        clock: () => clock,
      );
      coach.start();
    });

    tearDown(() => coach.dispose());

    test('says start, pause and resume, and the 5-minute cue', () async {
      await store.write(WorkoutTimer.start(ActivityType.yoga, clock));
      await coach.onChangeForTest();
      clock = clock.add(_m(5, 1));
      await coach.tickForTest();
      await store.write(store.read()!.pause(clock));
      await coach.onChangeForTest();
      await store.write(store.read()!.resume(clock));
      await coach.onChangeForTest();
      expect(voice.said, [
        "Activity started. Let's go!",
        startsWith('5 minutes. About '),
        'Activity paused.',
        'Activity resumed.',
      ]);
      expect(voice.said[1], endsWith('25 minutes to your goal.'));
    });

    test("Finish's own pause is quiet", () async {
      await store.write(WorkoutTimer.start(ActivityType.yoga, clock));
      await coach.onChangeForTest();
      coach.skipNextChange();
      await store.write(store.read()!.pause(clock));
      await coach.onChangeForTest();
      expect(voice.said, ["Activity started. Let's go!"]);
    });

    test('silent with the voice coach off', () async {
      voiceOn = false;
      await store.write(WorkoutTimer.start(ActivityType.yoga, clock));
      await coach.onChangeForTest();
      clock = clock.add(_m(5, 1));
      await coach.tickForTest();
      expect(voice.said, isEmpty);
    });
  });
}
