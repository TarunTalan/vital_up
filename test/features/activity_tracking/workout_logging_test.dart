import 'package:drift/native.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/core/database/drift_database.dart';
import 'package:vital_up/features/activity_tracking/data/repositories/activity_repository_impl.dart';
import 'package:vital_up/features/activity_tracking/data/services/workout_timer_notification.dart';
import 'package:vital_up/features/activity_tracking/data/services/workout_timer_store.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/workout_intensity.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/workout_timer.dart';
import 'package:vital_up/features/activity_tracking/domain/services/workout_log_rules.dart';
import 'package:vital_up/features/activity_tracking/domain/usecases/log_workout.dart';
import 'package:vital_up/features/activity_tracking/presentation/bloc/workout_timer_cubit.dart';

/// Records what the tray would show.
class _FakeNotifier implements WorkoutTimerNotifier {
  final shown = <WorkoutTimer>[];
  int cancels = 0;
  int permissionAsks = 0;

  @override
  Future<void> show(WorkoutTimer timer, DateTime now) async => shown.add(timer);

  @override
  Future<void> cancel() async => cancels++;

  @override
  Future<void> requestPermission() async => permissionAsks++;
}

void main() {
  final now = DateTime(2026, 10, 18, 19, 0);

  group('workout entry rules', () {
    test('calories follow MET, intensity, weight and time', () {
      // Strength MET 5 x 80 kg x 1 h.
      int kcal(WorkoutIntensity i) => estimateWorkoutCalories(
        ActivityType.strength,
        i,
        const Duration(hours: 1),
        weightKg: 80,
      );
      expect(kcal(WorkoutIntensity.moderate), 400);
      expect(kcal(WorkoutIntensity.light), 280);
      expect(kcal(WorkoutIntensity.hard), 520);
      // No weight on the profile: an average one.
      expect(
        estimateWorkoutCalories(
          ActivityType.yoga,
          WorkoutIntensity.moderate,
          const Duration(hours: 1),
          weightKg: double.nan,
        ),
        175,
      );
    });

    test('entries must be 1 min to 6 h, in the past, within 30 days', () {
      String? error(DateTime start, int minutes) =>
          workoutEntryError(start, Duration(minutes: minutes), now: now);
      final hourAgo = now.subtract(const Duration(hours: 1));

      expect(error(hourAgo, 45), isNull);
      expect(error(hourAgo, 60), isNull); // ends right now
      expect(error(hourAgo, 0), 'Enter at least 1 minute.');
      expect(
        error(now.subtract(const Duration(hours: 8)), 361),
        'A workout can be up to 6 hours.',
      );
      expect(
        error(hourAgo, 61),
        'This workout ends in the future. Check the time.',
      );
      expect(error(DateTime(2026, 9, 18, 6), 30), isNull);
      expect(
        error(DateTime(2026, 9, 17, 23), 30),
        'You can log workouts from the last 30 days.',
      );
    });
  });

  group('WorkoutTimer', () {
    test('counts only running time across pauses', () {
      var t = WorkoutTimer.start(ActivityType.hiit, now);
      t = t.pause(now.add(const Duration(minutes: 10)));
      expect(t.isRunning, isFalse);
      // Time on pause doesn't count.
      expect(t.elapsed(now.add(const Duration(hours: 1))), const Duration(minutes: 10));
      t = t.resume(now.add(const Duration(minutes: 30)));
      expect(
        t.elapsed(now.add(const Duration(minutes: 35))),
        const Duration(minutes: 15),
      );
      expect(t.startedAt, now);
    });

    test('caps at 6 hours and ignores a clock set back', () {
      final t = WorkoutTimer.start(ActivityType.yoga, now);
      expect(t.elapsed(now.add(const Duration(hours: 9))), WorkoutLogRules.maxLength);
      expect(t.isAtLimit(now.add(const Duration(hours: 6))), isTrue);
      expect(t.elapsed(now.subtract(const Duration(minutes: 5))), Duration.zero);
    });

    test('survives a round trip and rejects junk', () {
      final t = WorkoutTimer.start(ActivityType.dance, now)
          .pause(now.add(const Duration(minutes: 7)));
      final back = WorkoutTimer.decode(t.encode())!;
      expect(back.type, ActivityType.dance);
      expect(back.startedAt, now);
      expect(back.banked, const Duration(minutes: 7));
      expect(back.isRunning, isFalse);

      expect(WorkoutTimer.decode(null), isNull);
      expect(WorkoutTimer.decode('not json'), isNull);
      expect(WorkoutTimer.decode('{"type":"yoga"}'), isNull);
    });
  });

  group('timing and saving a workout', () {
    late AppDatabase db;
    late ActivityRepositoryImpl repo;
    late WorkoutTimerStore store;
    late DateTime clock;
    late LogWorkout logWorkout;
    late _FakeNotifier notifier;

    WorkoutTimerCubit cubit({ActivityType type = ActivityType.strength}) =>
        WorkoutTimerCubit(
          store: store,
          logWorkout: logWorkout,
          notifier: notifier,
          type: type,
          clock: () => clock,
        );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = WorkoutTimerStore(await SharedPreferences.getInstance());
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = ActivityRepositoryImpl(db);
      clock = now;
      notifier = _FakeNotifier();
      logWorkout = LogWorkout(
        repository: repo,
        weightKg: () async => 80,
        now: () => clock,
      );
    });

    tearDown(() => db.close());

    test('a timed workout saves with its type, time and intensity', () async {
      final c = cubit(type: ActivityType.hiit);
      addTearDown(c.close);
      await c.start();
      clock = now.add(const Duration(minutes: 20));
      await c.pause();
      clock = now.add(const Duration(minutes: 50));
      await c.resume();
      clock = now.add(const Duration(minutes: 60));

      expect(await c.finish(WorkoutIntensity.hard), WorkoutSaveOutcome.saved);
      expect(c.state.isStarted, isFalse);
      expect(store.read(), isNull);

      final saved = (await repo.getSessions()).single;
      expect(saved.activityType, ActivityType.hiit);
      expect(saved.startTime, now);
      expect(saved.totalDurationSeconds, 30 * 60);
      expect(saved.endTime, now.add(const Duration(minutes: 30)));
      expect(saved.intensity, WorkoutIntensity.hard);
      expect(saved.totalDistanceMeters, 0);
      expect(saved.hasDistance, isFalse);
      // HIIT MET 8 x 1.3 x 80 kg x 0.5 h.
      expect(saved.calories, 416);
    });

    test('closing the app keeps the timer: a new screen picks it up', () async {
      final first = cubit(type: ActivityType.yoga);
      await first.start();
      await first.close();

      clock = now.add(const Duration(minutes: 12));
      // Opened for another type: the workout being timed wins.
      final second = cubit(type: ActivityType.dance);
      addTearDown(second.close);
      expect(second.state.type, ActivityType.yoga);
      expect(second.state.isRunning, isTrue);
      expect(second.state.elapsed, const Duration(minutes: 12));
    });

    test('a timer left running stops itself at 6 hours', () async {
      final first = cubit();
      await first.start();
      await first.close();

      clock = now.add(const Duration(hours: 10));
      final c = cubit();
      addTearDown(c.close);
      await Future<void>.delayed(Duration.zero);
      expect(c.state.isRunning, isFalse);
      expect(c.state.reachedLimit, isTrue);
      expect(store.read()!.isRunning, isFalse);
      await c.resume();
      expect(c.state.isRunning, isFalse);
    });

    test('under a minute is not saved; discard clears it', () async {
      final c = cubit();
      addTearDown(c.close);
      await c.start();
      clock = now.add(const Duration(seconds: 40));
      expect(
        await c.finish(WorkoutIntensity.moderate),
        WorkoutSaveOutcome.tooShort,
      );
      expect(c.state.isStarted, isTrue);
      await c.discard();
      expect(c.state.isStarted, isFalse);
      expect(store.read(), isNull);
      expect(await repo.getSessions(), isEmpty);
    });

      test('the tray follows the timer and clears when it ends', () async {
      final c = cubit();
      addTearDown(c.close);
      expect(notifier.cancels, 1); // nothing timed: any old one goes

      await c.start();
      expect(notifier.permissionAsks, 1);
      expect(notifier.shown.last.isRunning, isTrue);

      clock = now.add(const Duration(minutes: 5));
      await c.pause();
      expect(notifier.shown.last.isRunning, isFalse);
      await c.resume();
      expect(notifier.shown.last.isRunning, isTrue);

      clock = now.add(const Duration(minutes: 30));
      await c.finish(WorkoutIntensity.moderate);
      expect(notifier.cancels, 2);
    });

    testWidgets('Pause on the notification pauses an open timer', (
      tester,
    ) async {
      final c = cubit();
      addTearDown(c.close);
      await tester.runAsync(c.start);
      expect(c.state.isRunning, isTrue);

      // What the notification's action handler does with the app running.
      await tester.runAsync(
        () => handleWorkoutTimerAction(
          LocalWorkoutTimerNotifier.pauseAction,
          prefs: store.prefs,
          plugin: FlutterLocalNotificationsPlugin(),
          clock: () => clock,
        ),
      );
      await tester.pump();
      expect(c.state.isStarted, isTrue);
      expect(c.state.isRunning, isFalse);

      await tester.runAsync(
        () => handleWorkoutTimerAction(
          LocalWorkoutTimerNotifier.resumeAction,
          prefs: store.prefs,
          plugin: FlutterLocalNotificationsPlugin(),
          clock: () => clock,
        ),
      );
      await tester.pump();
      expect(c.state.isRunning, isTrue);
      await c.discard();
    });

    testWidgets('a pause written by the background engine reaches the screen', (
      tester,
    ) async {
      final c = cubit();
      addTearDown(c.close);
      await tester.runAsync(c.start);
      expect(c.state.isRunning, isTrue);

      // Android runs notification buttons in a separate engine: it writes
      // prefs behind this isolate's back, then sends the port message.
      final paused = c.state.timer!.pause(clock);
      await tester.runAsync(() async {
        await store.prefs.setString(WorkoutTimerStore.key, paused.encode());
        WorkoutTimerStore.notifyOtherIsolates();
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      expect(c.state.isStarted, isTrue);
      expect(c.state.isRunning, isFalse);
      await c.discard();
    });

    test('GPS types are not offered for the timer', () async {
      final c = cubit(type: ActivityType.run);
      addTearDown(c.close);
      expect(c.state.type, ActivityType.strength);
      c.selectType(ActivityType.cycle);
      expect(c.state.type, ActivityType.strength);
      c.selectType(ActivityType.swimming);
      expect(c.state.type, ActivityType.swimming);
    });

    test('a past workout is checked before saving', () async {
      await expectLater(
        logWorkout(
          type: ActivityType.sports,
          start: now.add(const Duration(minutes: 5)),
          length: const Duration(minutes: 30),
          intensity: WorkoutIntensity.light,
        ),
        throwsArgumentError,
      );
      final saved = await logWorkout(
        type: ActivityType.sports,
        start: now.subtract(const Duration(days: 1)),
        length: const Duration(minutes: 90),
        intensity: WorkoutIntensity.light,
      );
      expect((await repo.getSessions()).single.id, saved.id);
    });

    test('weight that fails to load still saves the workout', () async {
      final log = LogWorkout(
        repository: repo,
        weightKg: () async => throw Exception('offline'),
        now: () => clock,
      );
      final saved = await log(
        type: ActivityType.strength,
        start: now.subtract(const Duration(hours: 1)),
        length: const Duration(hours: 1),
        intensity: WorkoutIntensity.moderate,
      );
      expect(saved.calories, 350); // 5 x 70 kg x 1 h
    });
  });
}
