// The water, sleep and screen time goal sheets on small and large phones,
// at every text size, light and dark: nothing cut, shrunk or overflowing,
// and the controls follow drags and taps. `HOME_SHOTS=1` also writes PNGs
// to build/goal_shots/.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/tracker/goal_controls.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
import 'package:vital_up/core/widgets/tracker/tracker_sheet.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/tracker_goal_editors.dart';

import '../../helpers/pump_app.dart';

final _writeShots = Platform.environment['HOME_SHOTS'] == '1';

typedef _Goal = ({
  TrackerMetric metric,
  String title,
  double initial,
  double min,
  double max,
  double step,
  String Function(double) format,
  double recommended,
});

final Map<String, _Goal> _goals = {
  'water': (
    metric: TrackerMetric.water,
    title: 'Daily water goal',
    initial: 2500,
    min: 500,
    max: 10000,
    step: 250,
    format: formatWaterGoal,
    recommended: 2500,
  ),
  'sleep': (
    metric: TrackerMetric.sleep,
    title: 'Nightly sleep goal',
    initial: 390,
    min: 180,
    max: 840,
    step: 30,
    format: formatMinutesGoal,
    recommended: 480,
  ),
  'screen': (
    metric: TrackerMetric.screenTime,
    title: 'Daily screen time limit',
    initial: 165,
    min: 15,
    max: 1440,
    step: 15,
    format: formatMinutesGoal,
    recommended: 120,
  ),
};

Widget _host(_Goal g, {ValueChanged<double?>? onSaved}) => Builder(
  builder: (context) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final v = await showTrackerGoalSheet(
        context: context,
        metric: g.metric,
        title: g.title,
        description: 'A short description of the goal',
        initial: g.initial,
        min: g.min,
        max: g.max,
        step: g.step,
        format: g.format,
        recommended: g.recommended,
        recommendedReason: 'A reason for the suggestion',
        // The user has a goal: "Remove goal" shows under Save.
        onRemove: () async {},
      );
      onSaved?.call(v);
    });
    return const Scaffold(body: SizedBox.expand());
  },
);

Future<void> _capture(WidgetTester tester, String path) async {
  await tester.runAsync(() async {
    final view = tester.binding.renderViews.first;
    final layer = view.debugLayer! as OffsetLayer;
    final image = await layer.toImage(Offset.zero & view.size, pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

const _cases = [
  (width: 360.0, scale: 1.0, dark: false),
  (width: 360.0, scale: kMaxTextScale, dark: false),
  (width: 412.0, scale: 1.0, dark: false),
  (width: 412.0, scale: 1.0, dark: true),
];

void main() {
  for (final MapEntry(key: name, value: goal) in _goals.entries) {
    for (final c in _cases) {
      final id =
          '${name}_${c.width.round()}_${c.scale}_'
          '${c.dark ? 'dark' : 'light'}';
      testWidgets('goal sheet: $id', (tester) async {
        await tester.runAsync(loadAllFonts);
        await pumpPage(
          tester,
          _host(goal),
          textScale: c.scale,
          size: Size(c.width, 900),
          theme: c.dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        );
        await tester.pumpAndSettle();
        final errors = takeAllExceptions(tester);
        final cut = truncatedTexts(tester);
        final shrunk = shrunkTexts(tester);
        if (_writeShots) await _capture(tester, 'build/goal_shots/$id.png');
        expect(errors, isEmpty, reason: 'layout exceptions in $id');
        expect(cut, isEmpty, reason: 'truncated texts in $id');
        expect(shrunk, isEmpty, reason: 'shrunk texts in $id');
      });
    }
  }

  testWidgets('dragging the water slider to the end sets the maximum', (
    tester,
  ) async {
    double? saved;
    await pumpPage(
      tester,
      _host(_goals['water']!, onSaved: (v) => saved = v),
      size: const Size(412, 900),
    );
    await tester.pumpAndSettle();
    final slider = find.byType(GoalSlider);
    await tester.drag(slider, const Offset(600, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save goal'));
    await tester.pumpAndSettle();
    expect(saved, 10000);
  });

  testWidgets('tapping the start of the screen time slider sets the minimum', (
    tester,
  ) async {
    double? saved;
    await pumpPage(
      tester,
      _host(_goals['screen']!, onSaved: (v) => saved = v),
      size: const Size(412, 900),
    );
    await tester.pumpAndSettle();
    final box = tester.getRect(find.byType(GoalSlider));
    await tester.tapAt(Offset(box.left + 2, box.top + 24));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save goal'));
    await tester.pumpAndSettle();
    expect(saved, 15);
  });

  testWidgets('dragging round the sleep dial raises the goal', (tester) async {
    double? saved;
    await pumpPage(
      tester,
      _host(_goals['sleep']!, onSaved: (v) => saved = v),
      size: const Size(412, 900),
    );
    await tester.pumpAndSettle();
    final dial = tester.getRect(find.byType(SleepGoalDial));
    // The top of the ring is the middle of the range (8h 30m).
    final top = Offset(dial.center.dx, dial.top + 13 + 8 + 6);
    final gesture = await tester.startGesture(top - const Offset(40, -8));
    await gesture.moveTo(top);
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save goal'));
    await tester.pumpAndSettle();
    expect(saved, 510);
  });
}
