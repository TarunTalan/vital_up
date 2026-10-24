// A tracker detail page and its history page on small and large phones, at
// every text size, light and dark: History in the header, the trend card's
// title and range toggle, and the shared history cards, with nothing cut or
// overflowing. `HOME_SHOTS=1` also writes PNGs to build/detail_shots/.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/charts/trend_bar_chart.dart';
import 'package:vital_up/core/widgets/tracker/log_history_card.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
import 'package:vital_up/features/dashboard/domain/entities/trend_series.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/trend_cubit.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/tracker_detail_scaffold.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/trend_widgets.dart';

import '../../helpers/pump_app.dart';

final _writeShots = Platform.environment['HOME_SHOTS'] == '1';

typedef _Log = ({DateTime at, int ml});

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

typedef _Case = ({double width, double scale, bool dark});

const List<_Case> _cases = [
  (width: 360, scale: 1.0, dark: false),
  (width: 360, scale: 1.3, dark: false),
  (width: 360, scale: kMaxTextScale, dark: false),
  (width: 412, scale: 1.0, dark: false),
  (width: 412, scale: 1.0, dark: true),
];

void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final logs = <_Log>[
    (at: DateTime(today.year, today.month, today.day, 0, 30), ml: 500),
    (at: DateTime(today.year, today.month, today.day, 0, 10), ml: 250),
    (at: DateTime(today.year, today.month, today.day - 1, 21), ml: 750),
    (at: DateTime(today.year, today.month, today.day - 3, 9), ml: 250),
  ];
  final series = TrendSeries([
    for (var i = 6; i >= 0; i--)
      DailyPoint(
        DateTime(today.year, today.month, today.day - i),
        i.isEven ? 1800.0 + i * 100 : null,
      ),
  ], goal: 2500);

  Widget card(BuildContext context, _Log log) => LogHistoryCard(
    icon: const Icon(Icons.local_drink_rounded),
    color: TrackerMetric.water.color,
    title: log.ml >= 500 ? 'Large bottle' : 'Glass',
    subtitle: '12:30 AM · Logged by you',
    value: '${log.ml} ml',
    note: log.ml == 750 ? 'After a long run in the afternoon sun' : null,
    figures: log.ml == 500
        ? const [
            LogFigure('11:00 PM', 'Bedtime'),
            LogFigure('7:15 AM', 'Woke up'),
            LogFigure('82', 'Good'),
          ]
        : const [],
    deleteNoun: 'drink',
    onDelete: () {},
  );

  Widget page() => BlocProvider(
    create: (_) =>
        TrendCubit<_Log>((_) async => TrendData(series, logs))..load(),
    child: Builder(
      builder: (context) => TrackerDetailScaffold<_Log>(
        metric: TrackerMetric.water,
        noun: 'water',
        format: (v) => '${v.floor()} ml',
        dateOf: (log) => log.at,
        logBuilder: card,
        allLogs: () async => logs,
        daySummary: (day) =>
            '${day.fold<int>(0, (s, l) => s + l.ml)} ml',
        headerAction: AppHeaderAction(
          tooltip: 'Guide',
          icon: const Icon(Icons.spa_rounded),
          onTap: () {},
        ),
        onLog: () {},
      ),
    ),
  );

  for (final c in _cases) {
    final name =
        '${c.width.toInt()}_${c.scale}_${c.dark ? 'dark' : 'light'}';
    testWidgets('detail and history pages fit: $name', (tester) async {
      await tester.runAsync(loadAllFonts);
      await pumpPage(
        tester,
        page(),
        textScale: c.scale,
        size: Size(c.width, 2600),
        theme: c.dark ? AppTheme.darkTheme : AppTheme.lightTheme,
      );
      await settle(tester);

      expect(takeAllExceptions(tester), isEmpty);
      expect(truncatedTexts(tester), isEmpty);
      // History and the page's own action, side by side.
      expect(find.byTooltip('History'), findsOneWidget);
      expect(find.byTooltip('Guide'), findsOneWidget);
      // Today's entries only, as the shared history cards.
      expect(find.byType(LogHistoryCard), findsNWidgets(2));
      expect(find.text(TrendRange.week.caption), findsOneWidget);
      if (_writeShots) {
        await _capture(tester, 'build/detail_shots/detail_$name.png');
      }

      await tester.tap(find.byTooltip('History'));
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 500));

      expect(takeAllExceptions(tester), isEmpty);
      expect(truncatedTexts(tester), isEmpty);
      expect(find.byType(LogHistoryCard), findsNWidgets(logs.length));
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
      // Each day's total beside its heading.
      expect(find.text('750 ml'), findsWidgets);
      if (_writeShots) {
        await _capture(tester, 'build/detail_shots/history_$name.png');
      }
    });
  }

  testWidgets('a long trend title keeps the toggle beside or under it', (
    tester,
  ) async {
    await pumpPage(
      tester,
      Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(AppDimens.space16),
          children: [
            TrendChartCard(
              title: TrendRange.month.caption,
              caption:
                  'Active minutes · ${TrendRange.month.detail.toLowerCase()}',
              range: TrendRange.month,
              onRange: (_) {},
              chart: TrendBarChart(
                series: series.weekly(),
                weekly: true,
                color: TrackerMetric.activity.color,
                valueFormatter: (v) => '${v.round()}',
              ),
              stats: TrendStatsRow(series: series, format: (v) => '$v'),
            ),
          ],
        ),
      ),
      textScale: kMaxTextScale,
    );
    await settle(tester);

    expect(takeAllExceptions(tester), isEmpty);
    expect(truncatedTexts(tester), isEmpty);
    // The toggle never overlaps the title.
    final title = tester.getRect(find.text(TrendRange.month.caption));
    final toggle = tester.getRect(find.text(TrendRange.week.label));
    expect(
      title.right <= toggle.left || title.bottom <= toggle.top,
      isTrue,
    );
  });
}
