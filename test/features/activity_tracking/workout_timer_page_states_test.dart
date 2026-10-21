import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/features/activity_tracking/presentation/widgets/activity_tracking_controls.dart';
import 'package:vital_up/features/activity_tracking/data/services/workout_timer_store.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_session.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/workout_intensity.dart';
import 'package:vital_up/features/activity_tracking/domain/repositories/activity_repository.dart';
import 'package:vital_up/features/activity_tracking/domain/usecases/log_workout.dart';
import 'package:vital_up/features/activity_tracking/presentation/bloc/workout_timer_cubit.dart';
import 'package:vital_up/features/activity_tracking/presentation/pages/workout_timer_page.dart';
import 'package:vital_up/features/activity_tracking/presentation/widgets/log_workout_sheet.dart';
import 'package:vital_up/features/activity_tracking/services/voice_coach_service.dart';
import 'package:vital_up/features/activity_tracking/services/workout_audio_service.dart';

import '../../helpers/pump_app.dart';

class _FakeRepo implements ActivityRepository {
  final saved = <ActivitySession>[];

  @override
  Future<void> saveSession(ActivitySession session) async =>
      saved.add(session);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// No music in tests: nothing plays, everything else is a no-op.
class _SilentAudio implements WorkoutAudioService {
  @override
  bool get isPlaying => false;

  @override
  Stream<bool> get playingStream => Stream.value(false);

  @override
  Future<void> stop() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SilentCoach implements VoiceCoachService {
  @override
  Future<void> init() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> announceCount(int count) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeRepo repo;
  late WorkoutTimerStore store;
  late DateTime clock;

  setUp(() async {
    // Notifications already allowed: Start shows no permission card.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter.baseflow.com/permissions/methods'),
          (call) async => 1,
        );
    // No 3-2-1 before Start: the countdown has its own timers.
    SharedPreferences.setMockInitialValues({'workout_countdown_duration': 0});
    store = WorkoutTimerStore(await SharedPreferences.getInstance());
    repo = _FakeRepo();
    clock = DateTime(2026, 10, 18, 18);
    final log = LogWorkout(repository: repo, weightKg: () async => 70);
    sl.registerSingleton<LogWorkout>(log);
    sl.registerSingleton<WorkoutAudioService>(_SilentAudio());
    sl.registerSingleton<VoiceCoachService>(_SilentCoach());
    sl.registerFactoryParam<WorkoutTimerCubit, ActivityType, void>(
      (type, _) => WorkoutTimerCubit(
        store: store,
        logWorkout: log,
        type: type,
        clock: () => clock,
      ),
    );
  });

  tearDown(() async {
    await sl.unregister<WorkoutTimerCubit>();
    await sl.unregister<LogWorkout>();
    await sl.unregister<WorkoutAudioService>();
    await sl.unregister<VoiceCoachService>();
  });

  testWidgets('ready, timing and paused at the largest text size', (
    tester,
  ) async {
    await pumpPage(
      tester,
      const WorkoutTimerPage(type: ActivityType.yoga),
      textScale: kMaxTextScale,
    );
    await settle(tester);

    expect(find.text('READY'), findsOneWidget);
    // The same tiles as the GPS screen, above Start.
    expect(find.byType(ActivitySelector), findsOneWidget);
    expect(takeAllExceptions(tester), isEmpty);
    expect(truncatedTexts(tester), isEmpty);

    await tester.tap(find.text('Start Yoga'));
    await settle(tester);
    clock = clock.add(const Duration(minutes: 3, seconds: 5));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('TIMING'), findsOneWidget);
    expect(find.text('00:03:05'), findsOneWidget);
    expect(store.read()!.type, ActivityType.yoga);

    // Locked: no Pause until the slider is pulled. The page can be left
    // with the workout still running.
    expect(find.byTooltip('Leave it running'), findsOneWidget);
    expect(find.text('PAUSE'), findsNothing);
    expect(find.text('SLIDE TO UNLOCK'), findsOneWidget);
    await tester.drag(
      find
          .descendant(
            of: find.byType(SlidingButton),
            matching: find.byType(GestureDetector),
          )
          .first,
      const Offset(2000, 0),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await settle(tester);

    await tester.tap(find.text('PAUSE'));
    await settle(tester);
    expect(find.text('PAUSED'), findsOneWidget);
    expect(find.text('RESUME'), findsOneWidget);
    expect(find.text('Discard workout'), findsOneWidget);
    expect(takeAllExceptions(tester), isEmpty);
    expect(truncatedTexts(tester), isEmpty);

    // Leaving the page keeps the workout for next time.
    await tester.pumpWidget(const SizedBox());
    expect(store.read(), isNotNull);
  });

  testWidgets('leaving keeps the workout running', (tester) async {
    await pumpPage(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    const WorkoutTimerPage(type: ActivityType.yoga),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
    await tester.tap(find.text('Start Yoga'));
    await settle(tester);

    await tester.tap(find.byTooltip('Leave it running'));
    await settle(tester);
    expect(find.byType(WorkoutTimerPage), findsNothing);
    expect(find.text('Your yoga timer keeps running'), findsOneWidget);
    final timer = store.read();
    expect(timer, isNotNull);
    expect(timer!.isRunning, isTrue);
  });

  testWidgets('the log sheet saves a past workout', (tester) async {
    late bool result;
    await pumpPage(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showLogWorkoutSheet(context),
            child: const Text('open'),
          ),
        ),
      ),
      textScale: kMaxTextScale,
    );
    await tester.tap(find.text('open'));
    await settle(tester);

    expect(find.text('Log a workout'), findsOneWidget);
    expect(takeAllExceptions(tester), isEmpty);
    expect(truncatedTexts(tester), isEmpty);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Yoga'));
    final thirty = find.widgetWithText(ChoiceChip, '30 min');
    await tester.ensureVisible(thirty);
    await tester.tap(thirty);
    await tester.ensureVisible(find.text('Hard'));
    await tester.tap(find.text('Hard'));
    await tester.pump();
    await tester.ensureVisible(find.text('Save workout'));
    await tester.tap(find.text('Save workout'));
    await settle(tester);

    expect(result, isTrue);
    final saved = repo.saved.single;
    expect(saved.activityType, ActivityType.yoga);
    expect(saved.totalDurationSeconds, 30 * 60);
    expect(saved.intensity, WorkoutIntensity.hard);
  });

  testWidgets('an empty duration asks for one instead of saving', (
    tester,
  ) async {
    await pumpPage(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showLogWorkoutSheet(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);

    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('Save workout'));
    await settle(tester);
    expect(
      find.text('Enter how long it lasted, 1 to 360 minutes.'),
      findsOneWidget,
    );
    expect(repo.saved, isEmpty);
  });
}
