// The weight and sleep log sheets on small and large phones, at every text
// size, light and dark: nothing cut, shrunk or overflowing, and the weight
// scale responds to drags, flings and taps. `HOME_SHOTS=1` also writes
// PNGs to build/sheet_shots/.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/database/collections/weight_log_cache.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/value_ruler.dart';
import 'package:vital_up/features/dashboard/domain/entities/sleep_session_info.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/tracker_log_sheets.dart';
import 'package:vital_up/features/weight/data/weight_service.dart';
import 'package:vital_up/features/weight/presentation/weight_entry_sheet.dart';

import '../../helpers/pump_app.dart';

final _writeShots = Platform.environment['HOME_SHOTS'] == '1';

WeightLogCache _log(double kg, DateTime at) => WeightLogCache()
  ..userId = 'u1'
  ..weightKg = kg
  ..timestamp = at
  ..source = 'manual';

/// Opens [sheet] the way the app does, over a plain page.
Widget _host(Widget sheet) => Builder(
  builder: (context) {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => showAppBottomSheet<void>(context: context, builder: (_) => sheet),
    );
    return const Scaffold(body: SizedBox.expand());
  },
);

Future<void> _capture(WidgetTester tester, String path) async {
  await tester.runAsync(() async {
    final view = tester.binding.renderViews.first;
    final layer = view.debugLayer! as OffsetLayer;
    final image = await layer.toImage(
      Offset.zero & view.size,
      pixelRatio: 2,
    );
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
  final sheets = <String, Widget Function()>{
    'weight': () => WeightEntrySheet(
      unit: WeightUnit.kg,
      startKg: 72.4,
      last: _log(73.1, now.subtract(const Duration(days: 6))),
      goalKg: 70,
    ),
    'weight_lbs_first': () =>
        const WeightEntrySheet(unit: WeightUnit.lbs, startKg: 104.3),
    'weight_typing': () => WeightEntrySheet(
      unit: WeightUnit.kg,
      startKg: 72.4,
      last: _log(72.4, now),
      typing: true,
    ),
    'sleep': () => SleepLogSheet(
      goalMinutes: 8 * 60,
      initial: SleepSessionInfo(
        bedTime: DateTime(now.year, now.month, now.day - 1, 23, 15),
        wakeTime: DateTime(now.year, now.month, now.day, 6, 40),
        duration: const Duration(hours: 7, minutes: 25),
        source: SleepDataSource.manual,
      ),
    ),
  };

  for (final MapEntry(key: name, value: sheet) in sheets.entries) {
    for (final c in _cases) {
      final id =
          '${name}_${c.width.round()}_${c.scale}_${c.dark ? 'dark' : 'light'}';
      testWidgets('log sheet: $id', (tester) async {
        await tester.runAsync(loadAllFonts);
        await pumpPage(
          tester,
          _host(sheet()),
          textScale: c.scale,
          size: Size(c.width, 800),
          theme: c.dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        );
        await tester.pumpAndSettle();
        final errors = takeAllExceptions(tester);
        final cut = truncatedTexts(tester);
        final shrunk = shrunkTexts(tester);
        if (_writeShots) await _capture(tester, 'build/sheet_shots/$id.png');
        expect(errors, isEmpty, reason: 'layout exceptions in $id');
        expect(cut, isEmpty, reason: 'truncated texts in $id');
        expect(shrunk, isEmpty, reason: 'shrunk texts in $id');
      });
    }
  }

  group('weight scale', () {
    Future<void> open(WidgetTester tester) async {
      await pumpPage(
        tester,
        _host(const WeightEntrySheet(unit: WeightUnit.kg, startKg: 72.4)),
        size: const Size(412, 800),
      );
      await tester.pumpAndSettle();
    }

    String shown(WidgetTester tester) => tester
        .widget<ValueRuler>(find.byType(ValueRuler))
        .value
        .toStringAsFixed(1);

    testWidgets('dragging left by one unit of ticks adds 1 kg', (
      tester,
    ) async {
      await open(tester);
      // The first [kDragSlopDefault] dp only decide it's a drag.
      await tester.timedDrag(
        find.byType(ValueRuler),
        const Offset(-(100 + kDragSlopDefault), 0),
        const Duration(seconds: 1),
      );
      await tester.pumpAndSettle();
      expect(shown(tester), '73.4');
      expect(find.text('Save 73.4 kg'), findsOneWidget);
    });

    testWidgets('a fling glides on and lands on a tick', (tester) async {
      await open(tester);
      await tester.fling(find.byType(ValueRuler), const Offset(200, 0), 1500);
      await tester.pumpAndSettle();
      final value = double.parse(shown(tester));
      expect(value, lessThan(70.4));
      expect((value * 10).roundToDouble(), value * 10);
    });

    testWidgets('a tap on a mark glides to it', (tester) async {
      await open(tester);
      final ruler = tester.getRect(find.byType(ValueRuler));
      // 50 dp right of the marker = five ticks = 0.5 kg.
      await tester.tapAt(Offset(ruler.center.dx + 50, ruler.top + 10));
      await tester.pumpAndSettle();
      expect(shown(tester), '72.9');
    });

    testWidgets('stays within the allowed range', (tester) async {
      await pumpPage(
        tester,
        _host(const WeightEntrySheet(unit: WeightUnit.kg, startKg: 20.3)),
        size: const Size(412, 800),
      );
      await tester.pumpAndSettle();
      await tester.timedDrag(
        find.byType(ValueRuler),
        const Offset(300, 0),
        const Duration(seconds: 1),
      );
      await tester.pumpAndSettle();
      expect(shown(tester), '20.0');
    });

    testWidgets('switching to typing keeps the value and back', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.text('Type instead'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, '72.4'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '68.5');
      await tester.tap(find.text('Use the scale'));
      await tester.pumpAndSettle();
      expect(shown(tester), '68.5');
    });
  });
}
