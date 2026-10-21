import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/permissions/permission_card.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/features/gamification/domain/entities/point_goal.dart';

import '../../helpers/pump_app.dart';

const _channel = MethodChannel('flutter.baseflow.com/permissions/methods');

/// permission_handler's platform side: every permission has [status]
/// until a request answers [answer].
class _FakePlatform {
  int status;
  int answer;
  int requests = 0;
  int settingsOpened = 0;

  _FakePlatform({required this.status, this.answer = 1});

  Future<Object?> handle(MethodCall call) async {
    switch (call.method) {
      case 'checkPermissionStatus':
        return status;
      case 'requestPermissions':
        requests++;
        status = answer;
        return {for (final p in call.arguments as List) p: answer};
      case 'openAppSettings':
        settingsOpened++;
        return true;
    }
    return null;
  }
}

const _ask = PermissionAsk(
  main: AppPermission.camera,
  title: 'Scan your food',
  message: 'Point your camera at a meal and VitalUp fills in the details.',
);

late _FakePlatform _platform;

Future<void> _setUp(int status, {int answer = 1}) async {
  _platform = _FakePlatform(status: status, answer: answer);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, _platform.handle);
  SharedPreferences.setMockInitialValues({});
  await sl.reset();
  sl.registerSingleton<SharedPreferences>(
    await SharedPreferences.getInstance(),
  );
}

/// Runs [ensurePermission] from a button; the result lands in [result].
Future<bool?> Function() _host(
  WidgetTester tester,
  PermissionAsk ask, {
  double textScale = 1,
  Size size = kSmallPhone,
  ThemeData? theme,
}) {
  bool? result;
  return () async {
    await pumpPage(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async =>
                  result = await ensurePermission(context, ask),
              child: const Text('Go'),
            ),
          ),
        ),
      ),
      textScale: textScale,
      size: size,
      theme: theme,
    );
    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();
    return result;
  };
}

void main() {
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    await sl.reset();
  });

  testWidgets('already allowed: no card, no system dialog', (tester) async {
    await _setUp(1);
    expect(await _host(tester, _ask)(), isTrue);
    expect(find.text('Scan your food'), findsNothing);
    expect(_platform.requests, 0);
  });

  testWidgets('Not now: no system dialog', (tester) async {
    await _setUp(0);
    await _host(tester, _ask)();
    expect(find.text('Scan your food'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.text('Scan your food'), findsNothing);
    expect(_platform.requests, 0);
  });

  testWidgets('Allow shows the system dialog', (tester) async {
    await _setUp(0);
    await _host(tester, _ask)();
    await tester.tap(find.text('Allow'));
    await tester.pumpAndSettle();
    expect(_platform.requests, 1);
    expect(_platform.status, 1);
  });

  testWidgets('blocked: Open settings instead of the dialog', (tester) async {
    await _setUp(4);
    await _host(tester, _ask)();
    expect(find.text('Open settings'), findsOneWidget);
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    expect(_platform.settingsOpened, 1);
    expect(_platform.requests, 0);
  });

  testWidgets('an ask-once card never comes back', (tester) async {
    await _setUp(0, answer: 0);
    const once = PermissionAsk(
      main: AppPermission.notifications,
      title: 'Stay on track',
      message: 'Gentle reminders.',
      onceKey: 'test',
    );
    final run = _host(tester, once);
    await run();
    await tester.tap(find.text('Allow'));
    await tester.pumpAndSettle();
    // Denied in the system dialog: the card still doesn't ask again.
    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();
    expect(find.text('Stay on track'), findsNothing);
    expect(_platform.requests, 1);
  });

  // The card on the smallest phone at the largest text, and in dark mode:
  // nothing cut. `HOME_SHOTS=1` writes build/permission_shots/.
  for (final c in const [
    (width: 360.0, scale: kMaxTextScale, dark: false),
    (width: 412.0, scale: 1.0, dark: true),
  ]) {
    final id = '${c.width.round()}_${c.scale}_${c.dark ? 'dark' : 'light'}';
    testWidgets('card layout $id', (tester) async {
      await tester.runAsync(loadAllFonts);
      await _setUp(0);
      await _host(
        tester,
        const PermissionAsk(
          main: AppPermission.location,
          also: [AppPermission.notifications],
          title: 'Map your workout',
          message:
              'VitalUp follows your route while you track, so your '
              'distance and pace are right.',
        ),
        textScale: c.scale,
        size: Size(c.width, 760),
        theme: c.dark ? AppTheme.darkTheme : AppTheme.lightTheme,
      )();
      expect(find.text('Map your workout'), findsOneWidget);
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
          File('build/permission_shots/$id.png')
            ..createSync(recursive: true)
            ..writeAsBytesSync(bytes!.buffer.asUint8List());
        });
      }
      expect(takeAllExceptions(tester), isEmpty);
      expect(truncatedTexts(tester), isEmpty);
    });
  }

  group('PointGoal', () {
    test('rules map to the goal they need', () {
      expect(PointGoal.forSource('water_goal'), PointGoal.water);
      expect(PointGoal.forSource('weekly_goal'), PointGoal.activity);
      expect(PointGoal.forSource('water_log'), isNull);
    });

    test('the Arena card names what is missing', () {
      expect(
        PointGoal.sentenceFor({PointGoal.water}),
        'A water goal earns points on days you hit it.',
      );
      expect(
        PointGoal.sentenceFor({PointGoal.activity}),
        'An activity goal earns points on days you hit it.',
      );
      expect(
        PointGoal.sentenceFor({PointGoal.activity, PointGoal.water}),
        'Water and activity goals earn points on days you hit them.',
      );
    });
  });
}
