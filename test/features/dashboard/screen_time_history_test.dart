import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
import 'package:vital_up/features/dashboard/data/services/screen_time_service.dart';
import 'package:vital_up/features/dashboard/domain/entities/trend_series.dart';

const _channel = MethodChannel('com.example.vital_up/usage_stats');

/// Like Android: usage events only for the last [ScreenTimeService.systemDays]
/// days, one hour of YouTube on each of them.
void _fakeSystem(TestWidgetsFlutterBinding binding, {List<int>? calls}) {
  final now = DateTime.now();
  final window = DateTime(
    now.year,
    now.month,
    now.day - (ScreenTimeService.systemDays - 1),
  );
  binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (
    call,
  ) async {
    if (call.method != 'getExactUsageStats') return null;
    final start = DateTime.fromMillisecondsSinceEpoch(
      (call.arguments as Map)['start'] as int,
    );
    calls?.add(start.millisecondsSinceEpoch);
    if (start.isBefore(window)) return <String, int>{};
    return {'com.google.android.youtube': 3600000};
  });
}

DateTime _daysAgo(int n) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day - n);
}

String _key(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(
    () =>
        binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null),
  );

  test('history goes back past the 10 days Android keeps', () async {
    final old = _daysAgo(40);
    SharedPreferences.setMockInitialValues({
      ScreenTimeService.savedDaysKey: jsonEncode({
        _key(old): {
          'ms': 7200000,
          'apps': [
            {'n': 'Chrome', 'p': 'com.android.chrome', 'ms': 7200000},
          ],
        },
      }),
    });
    _fakeSystem(binding);
    final service = ScreenTimeService(await SharedPreferences.getInstance());

    final days = await service.history();

    expect(days.length, ScreenTimeService.systemDays + 1);
    expect(days.first.date, _daysAgo(0));
    expect(days.last.date, old);
    expect(days.last.duration, const Duration(hours: 2));
    expect(days.last.topApps.single.appName, 'Chrome');
  });

  test('finished days are saved, today and empty days are not', () async {
    SharedPreferences.setMockInitialValues({});
    _fakeSystem(binding);
    final prefs = await SharedPreferences.getInstance();
    await ScreenTimeService(prefs).trend(TrendRange.month);

    final saved =
        jsonDecode(prefs.getString(ScreenTimeService.savedDaysKey)!)
            as Map<String, dynamic>;
    expect(saved.length, ScreenTimeService.systemDays - 1);
    expect(saved.containsKey(_key(_daysAgo(0))), isFalse);
    expect(saved.containsKey(_key(_daysAgo(1))), isTrue);
    expect(saved.containsKey(_key(_daysAgo(20))), isFalse);

    // Weeks later the system has forgotten them; the saved copy hasn't.
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      (_) async => <String, int>{},
    );
    final days = await ScreenTimeService(prefs).history();
    expect(days.length, ScreenTimeService.systemDays - 1);
  });

  test('saved days are read without asking the system again', () async {
    SharedPreferences.setMockInitialValues({});
    final calls = <int>[];
    _fakeSystem(binding, calls: calls);
    final service = ScreenTimeService(await SharedPreferences.getInstance());

    await service.getWeeklySummary();
    expect(calls.length, 7);
    calls.clear();
    await service.getWeeklySummary();
    // Only today can still change.
    expect(calls, [_daysAgo(0).millisecondsSinceEpoch]);
  });

  test('a wiped device forgets the saved days', () async {
    SharedPreferences.setMockInitialValues({});
    _fakeSystem(binding);
    final prefs = await SharedPreferences.getInstance();
    final service = ScreenTimeService(prefs);
    await service.history();
    expect(prefs.getString(ScreenTimeService.savedDaysKey), isNotNull);

    await prefs.remove(ScreenTimeService.savedDaysKey);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      (_) async => <String, int>{},
    );
    expect(await service.history(), isEmpty);
  });

  test(
    'screen time is Android only: hidden and never asked for on iOS',
    () async {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      var asked = false;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (
        call,
      ) async {
        asked = true;
        return true;
      });
      addTearDown(
        () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
          _channel,
          null,
        ),
      );

      expect(TrackerMetric.screenTime.isAvailable, isTrue);
      expect(await ScreenTimeService().hasPermission(), isTrue);

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      asked = false;
      expect(ScreenTimeService.isSupported, isFalse);
      expect(TrackerMetric.screenTime.isAvailable, isFalse);
      expect(TrackerMetric.water.isAvailable, isTrue);
      expect(await ScreenTimeService().hasPermission(), isFalse);
      expect(asked, isFalse);
    },
  );
}
