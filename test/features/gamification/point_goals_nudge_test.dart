import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/features/gamification/data/services/daily_metrics_collector.dart';
import 'package:vital_up/features/gamification/domain/entities/point_goal.dart';
import 'package:vital_up/features/gamification/presentation/widgets/point_goals_nudge.dart';

import '../../helpers/pump_app.dart';

class _FakeCollector extends Fake implements DailyMetricsCollector {
  Set<PointGoal> missing;

  _FakeCollector(this.missing);

  @override
  Future<Set<PointGoal>> missingPointGoals() async => missing;
}

Future<void> _pump(
  WidgetTester tester,
  Set<PointGoal> missing, {
  double textScale = 1,
  Size size = kSmallPhone,
  ThemeData? theme,
}) async {
  SharedPreferences.setMockInitialValues({});
  await sl.reset();
  sl.registerSingleton<SharedPreferences>(
    await SharedPreferences.getInstance(),
  );
  sl.registerSingleton<DailyMetricsCollector>(_FakeCollector(missing));
  addTearDown(sl.reset);
  await pumpPage(
    tester,
    const SingleChildScrollView(
      padding: EdgeInsets.all(AppDimens.space16),
      child: PointGoalsNudge(),
    ),
    textScale: textScale,
    size: size,
    theme: theme,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('hidden when every goal that earns points is set', (
    tester,
  ) async {
    await _pump(tester, const {});
    expect(find.text('Set goals to earn more points'), findsNothing);
  });

  testWidgets('Not now hides it until another goal goes missing', (
    tester,
  ) async {
    await _pump(tester, {PointGoal.water});
    expect(
      find.text('A water goal earns points on days you hit it.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.text('Set goals to earn more points'), findsNothing);
    expect(
      sl<SharedPreferences>().getString(PointGoalsNudge.hiddenKey),
      'water',
    );
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
        {PointGoal.water, PointGoal.activity},
        textScale: c.scale,
        size: Size(c.width, 400),
        theme: c.dark ? AppTheme.darkTheme : AppTheme.lightTheme,
      );
      if (Platform.environment['HOME_SHOTS'] == '1') {
        await tester.runAsync(() async {
          final view = tester.binding.renderViews.first;
          final layer = view.debugLayer! as OffsetLayer;
          final image = await layer.toImage(
            Offset.zero & view.size,
            pixelRatio: 1,
          );
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          File('build/arena_shots/goals_nudge_$id.png')
            ..createSync(recursive: true)
            ..writeAsBytesSync(bytes!.buffer.asUint8List());
        });
      }
      expect(takeAllExceptions(tester), isEmpty);
      expect(truncatedTexts(tester), isEmpty);
    });
  }
}
