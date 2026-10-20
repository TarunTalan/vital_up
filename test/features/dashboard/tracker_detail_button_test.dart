import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
import 'package:vital_up/core/widgets/tracker/tracker_status.dart';
import 'package:vital_up/features/dashboard/domain/entities/trend_series.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/trend_cubit.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/tracker_detail_scaffold.dart';

import '../../helpers/pump_app.dart';

TrendSeries _week({double? goal}) => TrendSeries([
  for (var i = 0; i < 7; i++)
    DailyPoint(DateTime(2026, 10, 12 + i), i.isEven ? 3.0 : null),
], goal: goal);

/// A mood-like detail page: no numeric goal, [checkedIn] today or not.
Future<void> _pump(WidgetTester tester, {required bool checkedIn}) async {
  await pumpPage(
    tester,
    BlocProvider(
      create: (_) =>
          TrendCubit<int>((_) async => TrendData(_week(), const [3]))..load(),
      child: TrackerDetailScaffold<int>(
        metric: TrackerMetric.mood,
        noun: 'your mood',
        format: (v) => '$v',
        today: (_) => TrackerToday(
          value: checkedIn ? 'Calm' : 'Not yet',
          status: checkedIn ? TrackerStatus.done : TrackerStatus.notLogged,
          statusLabel: checkedIn ? 'Checked in' : null,
        ),
        dateOf: (_) => DateTime(2026, 10, 18),
        logBuilder: (_, _) => const SizedBox(),
        onLog: () {},
        editLabel: 'Edit check-in',
      ),
    ),
    size: const Size(390, 1600),
  );
  await settle(tester);
}

void main() {
  testWidgets('not logged yet: the log action, as the main button', (
    tester,
  ) async {
    await _pump(tester, checkedIn: false);
    expect(
      find.widgetWithText(AppPrimaryButton, TrackerMetric.mood.logLabel),
      findsOneWidget,
    );
    expect(find.byType(AppSecondaryButton), findsNothing);
  });

  testWidgets('logged today: the quieter edit button', (tester) async {
    await _pump(tester, checkedIn: true);
    expect(
      find.widgetWithText(AppSecondaryButton, 'Edit check-in'),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AppSecondaryButton),
        matching: find.byWidgetPredicate(
          (w) =>
              w is SvgPicture &&
              w.bytesLoader is SvgAssetLoader &&
              (w.bytesLoader as SvgAssetLoader).assetName ==
                  TrackerIcons.edit,
        ),
      ),
      findsOneWidget,
    );
    expect(find.byType(AppPrimaryButton), findsNothing);
  });

  testWidgets('a series without a goal shows days logged, not goal met', (
    tester,
  ) async {
    await _pump(tester, checkedIn: true);
    expect(find.text('Days logged'), findsOneWidget);
    expect(find.text('4/7 days'), findsOneWidget);
    expect(find.text('Goal met'), findsNothing);
  });
}
