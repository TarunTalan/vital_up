import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/features/activity_tracking/data/services/workout_timer_store.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_session.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/workout_intensity.dart';
import 'package:vital_up/features/activity_tracking/domain/repositories/activity_repository.dart';
import 'package:vital_up/features/activity_tracking/domain/usecases/log_workout.dart';
import 'package:vital_up/features/activity_tracking/presentation/bloc/workout_timer_cubit.dart';
import 'package:vital_up/features/activity_tracking/presentation/pages/workout_timer_page.dart';
import 'package:vital_up/features/activity_tracking/presentation/widgets/log_workout_sheet.dart';

import '../../helpers/pump_app.dart';

class _FakeRepo implements ActivityRepository {
  final saved = <ActivitySession>[];

  @override
  Future<void> saveSession(ActivitySession session) async =>
      saved.add(session);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeRepo repo;
  late WorkoutTimerStore store;
  late DateTime clock;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = WorkoutTimerStore(await SharedPreferences.getInstance());
    repo = _FakeRepo();
    clock = DateTime(2026, 10, 18, 18);
    final log = LogWorkout(repository: repo, weightKg: () async => 70);
    sl.registerSingleton<LogWorkout>(log);
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

    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('Log a past workout instead'), findsOneWidget);
    expect(takeAllExceptions(tester), isEmpty);
    expect(truncatedTexts(tester), isEmpty);

    await tester.tap(find.text('Start'));
    await settle(tester);
    clock = clock.add(const Duration(minutes: 3, seconds: 5));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Timing'), findsOneWidget);
    expect(find.text('00:03:05'), findsOneWidget);
    expect(store.read()!.type, ActivityType.yoga);

    await tester.tap(find.text('Pause'));
    await settle(tester);
    expect(find.text('Paused'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);
    expect(find.text('Discard workout'), findsOneWidget);
    expect(takeAllExceptions(tester), isEmpty);
    expect(truncatedTexts(tester), isEmpty);

    // Leaving the page keeps the workout for next time.
    await tester.pumpWidget(const SizedBox());
    expect(store.read(), isNotNull);
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
