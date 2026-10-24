import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/workout_timer.dart';
import 'package:vital_up/features/activity_tracking/presentation/widgets/active_workout_bar.dart';

import '../../helpers/pump_app.dart';

final _now = DateTime(2026, 10, 22, 18, 30);

final _running = WorkoutTimer(
  type: ActivityType.yoga,
  startedAt: _now.subtract(const Duration(minutes: 20)),
  banked: const Duration(minutes: 12),
  runningSince: _now.subtract(const Duration(seconds: 34)),
);

Future<void> _pump(
  WidgetTester tester,
  ActiveWorkout? workout, {
  double textScale = 1,
  Size size = kSmallPhone,
  ThemeData? theme,
}) async {
  await pumpPage(
    tester,
    Align(
      alignment: Alignment.bottomCenter,
      child: ActiveWorkoutBar(read: () => workout, clock: () => _now),
    ),
    textScale: textScale,
    size: size,
    theme: theme,
  );
  // The badge pulses while the clock runs: settle by time, not frames.
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('a running timer: type, In progress and the live time', (
    tester,
  ) async {
    await _pump(tester, TimedWorkout(_running));
    expect(find.text('Yoga'), findsOneWidget);
    expect(find.text('In progress'), findsOneWidget);
    expect(find.text('00:12:34'), findsOneWidget);
  });

  testWidgets('a paused timer says so', (tester) async {
    await _pump(tester, TimedWorkout(_running.pause(_now)));
    expect(find.text('Paused'), findsOneWidget);
    expect(find.text('00:12:34'), findsOneWidget);
  });

  testWidgets('a GPS workout the app was closed during', (tester) async {
    await _pump(tester, const InterruptedGpsWorkout());
    expect(find.text('Workout stopped'), findsOneWidget);
    expect(find.text('Tap to resume or save it'), findsOneWidget);
  });

  testWidgets('nothing under way: nothing shown', (tester) async {
    await _pump(tester, null);
    expect(find.byType(InkWell), findsNothing);
  });

  for (final c in const [
    (width: 360.0, scale: kMaxTextScale, dark: false),
    (width: 412.0, scale: 1.0, dark: true),
  ]) {
    final id = '${c.width.round()}_${c.scale}_${c.dark ? 'dark' : 'light'}';
    testWidgets('layout $id', (tester) async {
      await tester.runAsync(loadAllFonts);
      await _pump(
        tester,
        TimedWorkout(_running),
        textScale: c.scale,
        size: Size(c.width, 200),
        theme: c.dark ? AppTheme.darkTheme : AppTheme.lightTheme,
      );
      if (Platform.environment['HOME_SHOTS'] == '1') {
        await tester.runAsync(() async {
          final view = tester.binding.renderViews.first;
          final layer = view.debugLayer! as OffsetLayer;
          final image = await layer.toImage(
            Offset.zero & view.size,
            pixelRatio: 2,
          );
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          File('build/workout_bar_shots/$id.png')
            ..createSync(recursive: true)
            ..writeAsBytesSync(bytes!.buffer.asUint8List());
        });
      }
      expect(takeAllExceptions(tester), isEmpty);
      expect(truncatedTexts(tester), isEmpty);
    });
  }
}
