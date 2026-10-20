// The weight and sleep log sheets on small and large phones, at every text
// size, light and dark: nothing cut, shrunk or overflowing, and the weight
// scale responds to drags, flings and taps. `HOME_SHOTS=1` also writes
// PNGs to build/sheet_shots/.
import 'dart:math' as math;
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/database/collections/weight_log_cache.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/circular_sleep_clock.dart';
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

    testWidgets('dragging left by one unit of ticks adds 1 kg', (tester) async {
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

    testWidgets(
      'each step ticks with sound and vibration, firmer on whole kg',
      (tester) async {
        final calls = <String>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'SystemSound.play' ||
                call.method == 'HapticFeedback.vibrate') {
              calls.add('${call.method} ${call.arguments}');
            }
            return null;
          },
        );
        const feedback = MethodChannel('com.vitalup.app/feedback');
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          feedback,
          (call) async {
            if (call.method == 'tick') calls.add('tick ${call.arguments}');
            return null;
          },
        );
        addTearDown(() {
          final messenger = tester.binding.defaultBinaryMessenger;
          messenger.setMockMethodCallHandler(SystemChannels.platform, null);
          messenger.setMockMethodCallHandler(feedback, null);
        });
        await open(tester);
        // 72.4 -> 73.0: six steps, slowly, so none are skipped.
        for (var i = 0; i < 6; i++) {
          await tester.timedDrag(
            find.byType(ValueRuler),
            Offset(-(10 + kDragSlopDefault), 0),
            const Duration(milliseconds: 300),
          );
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.pumpAndSettle();
        expect(shown(tester), '73.0');
        // The app's own tick, deeper on the whole kilo; no system click.
        expect(calls.where((c) => c.startsWith('tick')), hasLength(6));
        expect(calls.where((c) => c == 'tick {strong: true}'), hasLength(1));
        expect(calls.where((c) => c.startsWith('SystemSound')), isEmpty);
        expect(
          calls.where((c) => c.contains('HapticFeedbackType.lightImpact')),
          hasLength(1),
        );
        expect(
          calls.where((c) => c.contains('HapticFeedbackType.selectionClick')),
          hasLength(5),
        );
      },
    );

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

    testWidgets('switching to typing keeps the value and back', (tester) async {
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

  group('sleep clock', () {
    final now = DateTime.now();
    Widget sheet() => SleepLogSheet(
      goalMinutes: 8 * 60,
      initial: SleepSessionInfo(
        bedTime: DateTime(now.year, now.month, now.day - 1, 23, 15),
        wakeTime: DateTime(now.year, now.month, now.day, 6, 40),
        duration: const Duration(hours: 7, minutes: 25),
        source: SleepDataSource.manual,
      ),
    );

    /// Where the moon (bedtime) handle is drawn.
    Offset moon(WidgetTester tester) {
      final clock = tester.getRect(
        find
            .descendant(
              of: find.byType(CircularSleepClockPicker),
              matching: find.byType(CustomPaint),
            )
            .first,
      );
      final radius = clock.width / 2 - 24;
      final angle = (23.25 / 24) * 2 * math.pi - math.pi / 2;
      return clock.center + Offset(math.cos(angle), math.sin(angle)) * radius;
    }

    // Small phone, largest text: the sheet scrolls, so a vertical drag
    // could go either way.
    Future<void> open(WidgetTester tester) async {
      await tester.runAsync(loadAllFonts);
      await pumpPage(
        tester,
        _host(sheet()),
        textScale: kMaxTextScale,
        size: const Size(360, 800),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('dragging the moon up or down moves bedtime, not the sheet', (
      tester,
    ) async {
      await open(tester);
      expect(find.text('11:15 PM'), findsOneWidget);
      final before = tester.getRect(find.byType(SleepLogSheet));
      final gesture = await tester.startGesture(moon(tester));
      for (var i = 0; i < 8; i++) {
        await gesture.moveBy(const Offset(0, 10));
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('11:15 PM'), findsNothing);
      // The sheet stayed put (no scroll, no drag-to-close).
      expect(tester.getRect(find.byType(SleepLogSheet)), before);
    });

    testWidgets('the moon pushed onto the sun stops at 30 minutes', (
      tester,
    ) async {
      await open(tester);
      final clock = tester.getRect(
        find
            .descendant(
              of: find.byType(CircularSleepClockPicker),
              matching: find.byType(CustomPaint),
            )
            .first,
      );
      final radius = clock.width / 2 - 24;
      Offset at(double hour) {
        final angle = hour / 24 * 2 * math.pi - math.pi / 2;
        return clock.center + Offset(math.cos(angle), math.sin(angle)) * radius;
      }

      // Drag the moon (11:15 PM) clockwise round to the sun (6:40 AM) and
      // beyond, in small steps like a finger.
      final gesture = await tester.startGesture(moon(tester));
      for (var h = 23.25; h <= 24 + 8; h += 0.25) {
        await gesture.moveTo(at(h % 24));
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('6:10 AM'), findsOneWidget);
      expect(find.text('Save 0h 30m'), findsOneWidget);
    });

    testWidgets('a phone estimate keeps its time asleep until the times '
        'change', (tester) async {
      await tester.runAsync(loadAllFonts);
      final wake = DateTime(now.year, now.month, now.day, 6);
      await pumpPage(
        tester,
        _host(
          SleepLogSheet(
            goalMinutes: 8 * 60,
            // 8h in bed, 20 minutes of screen-on check-ins.
            initial: SleepSessionInfo(
              bedTime: wake.subtract(const Duration(hours: 8)),
              wakeTime: wake,
              duration: const Duration(hours: 7, minutes: 40),
              source: SleepDataSource.phone,
            ),
          ),
        ),
        size: const Size(412, 915),
      );
      await tester.pumpAndSettle();
      // Dial and Save agree with the card ("Slept 7h 40m?").
      expect(find.text('Save 7h 40m'), findsOneWidget);
      // (The goal line keeps its words together with non-breaking spaces.)
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              w.data?.replaceAll('\u00a0', ' ') == '20m under your 8h goal',
        ),
        findsOneWidget,
      );

      // Moving bedtime makes it a hand-entered night: bed to wake.
      final gesture = await tester.startGesture(_handle(tester, hour: 22));
      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(const Offset(-6, 6));
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('Save 7h 40m'), findsNothing);
      // Save now shows the new bed-to-wake span, as the dial does.
      final bed = tester.widget<Text>(
        find
            .descendant(
              of: find.byType(CircularSleepClockPicker),
              matching: find.textContaining(RegExp(r'^\d+:\d\d [AP]M$')),
            )
            .first,
      );
      final parts = RegExp(r'^(\d+):(\d\d) ([AP]M)$').firstMatch(bed.data!)!;
      final bedHour = int.parse(parts[1]!) % 12 + (parts[3] == 'PM' ? 12 : 0);
      final bedMinutes = bedHour * 60 + int.parse(parts[2]!);
      final span = (6 * 60 - bedMinutes) % (24 * 60);
      expect(find.text('Save ${span ~/ 60}h ${span % 60}m'), findsOneWidget);
    });

    testWidgets('a wake-up time in the future is flagged and Save is off', (
      tester,
    ) async {
      await tester.runAsync(loadAllFonts);
      final soon = DateTime.now().add(const Duration(hours: 2));
      await pumpPage(
        tester,
        _host(
          SleepLogSheet(
            goalMinutes: 8 * 60,
            initial: SleepSessionInfo(
              bedTime: soon.subtract(const Duration(hours: 7)),
              wakeTime: soon,
              duration: const Duration(hours: 7),
              source: SleepDataSource.manual,
            ),
          ),
        ),
        size: const Size(412, 915),
      );
      await tester.pumpAndSettle();
      expect(find.text("Wake-up time can't be in the future."), findsOneWidget);
      final save = tester.widget<AppPrimaryButton>(
        find.byType(AppPrimaryButton),
      );
      expect(save.enabled, isFalse);
    });

    for (final (size, scale) in [
      (const Size(360, 640), kMaxTextScale),
      (const Size(360, 640), 1.0),
      (const Size(360, 800), kMaxTextScale),
      (const Size(360, 740), 1.3),
      (const Size(412, 915), kMaxTextScale),
    ]) {
      testWidgets(
        'fits without scrolling, times side by side, nothing behind Save: '
        '${size.width.round()}x${size.height.round()} at $scale',
        (tester) async {
          await tester.runAsync(loadAllFonts);
          await pumpPage(tester, _host(sheet()), textScale: scale, size: size);
          await tester.pumpAndSettle();
          expect(takeAllExceptions(tester), isEmpty);
          expect(truncatedTexts(tester), isEmpty);
          expect(
            find.descendant(
              of: find.byType(SleepLogSheet),
              matching: find.byType(Scrollable),
            ),
            findsNothing,
          );
          final clock = tester.getRect(
            find
                .descendant(
                  of: find.byType(CircularSleepClockPicker),
                  matching: find.byType(CustomPaint),
                )
                .first,
          );
          expect(
            clock.width,
            greaterThanOrEqualTo(CircularSleepClockPicker.minClockSize - 0.5),
          );
          // Bed and wake times side by side.
          expect(
            tester.getRect(find.text('11:15 PM')).top,
            tester.getRect(find.text('6:40 AM')).top,
          );
          final save = tester.getRect(find.textContaining('Save'));
          final wake = tester.getRect(find.text('6:40 AM'));
          expect(wake.bottom, lessThanOrEqualTo(save.top));
          expect(save.bottom, lessThanOrEqualTo(size.height));
        },
      );
    }
  });
}

/// Where the handle for [hour] (24 h clock) sits on the sleep dial.
Offset _handle(WidgetTester tester, {required double hour}) {
  final clock = tester.getRect(
    find
        .descendant(
          of: find.byType(CircularSleepClockPicker),
          matching: find.byType(CustomPaint),
        )
        .first,
  );
  final radius = clock.width / 2 - 24;
  final angle = hour / 24 * 2 * math.pi - math.pi / 2;
  return clock.center + Offset(math.cos(angle), math.sin(angle)) * radius;
}
