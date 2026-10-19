import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/features/gamification/presentation/widgets/month_calendar_grid.dart';

import '../../helpers/pump_app.dart';

Future<List<DateTime>> _pump(
  WidgetTester tester, {
  double textScale = 1,
  Size size = const Size(412, 600),
}) async {
  final tapped = <DateTime>[];
  await pumpPage(
    tester,
    Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: MonthCalendarGrid(
          month: DateTime(2026, 1),
          selected: DateTime(2026, 1, 14),
          today: DateTime(2026, 1, 14),
          gradeOf: (d) =>
              d.day.isEven ? CalendarDayGrade.good : CalendarDayGrade.light,
          onSelect: tapped.add,
        ),
      ),
    ),
    textScale: textScale,
    size: size,
  );
  return tapped;
}

void main() {
  testWidgets('January 2026 starts on Thursday, Sunday first', (tester) async {
    await _pump(tester);
    expect(find.text('Sun'), findsOneWidget);
    expect(find.text('31'), findsOneWidget);
    // Thursday is the fifth column: 1 sits right of four blank cells.
    final sun = tester.getCenter(find.text('Sun')).dx;
    final thu = tester.getCenter(find.text('Thu')).dx;
    expect(tester.getCenter(find.text('1')).dx, closeTo(thu, 0.5));
    expect(tester.getCenter(find.text('4')).dx, closeTo(sun, 0.5));
  });

  testWidgets('past days can be picked, future days cannot', (tester) async {
    final tapped = await _pump(tester);
    await tester.tap(find.text('3'));
    await tester.tap(find.text('20'));
    expect(tapped, [DateTime(2026, 1, 3)]);
  });

  testWidgets('cells stay square on a phone at normal text', (tester) async {
    await _pump(tester);
    final cell = tester.getSize(
      find.ancestor(of: find.text('15'), matching: find.byType(Material)).first,
    );
    expect(cell.width, closeTo(cell.height, 0.5));
  });

  testWidgets('narrow phone, largest text: whole, with short weekdays', (
    tester,
  ) async {
    await _pump(tester, textScale: kMaxTextScale, size: const Size(360, 700));
    expect(takeAllExceptions(tester), isEmpty);
    expect(truncatedTexts(tester), isEmpty);
    expect(find.text('W'), findsOneWidget);
  });
}
