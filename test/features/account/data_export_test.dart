import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/database/collections/water_log_cache.dart';
import 'package:vital_up/features/account/data/data_export_service.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_session.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';

void main() {
  test('CSV quotes commas, quotes and line breaks', () {
    expect(
      csv(
        ['a', 'b'],
        [
          ['plain', 'x, y'],
          ['say "hi"', 'two\nlines'],
        ],
      ),
      'a,b\r\nplain,"x, y"\r\n"say ""hi""","two\nlines"',
    );
  });

  test('export has a file per log type and round-trips through the zip', () {
    final files = buildExportFiles(
      ExportData(
        exportedAt: DateTime(2026, 10, 2, 9),
        water: [
          WaterLogCache()
            ..userId = 'u'
            ..amountMl = 250
            ..timestamp = DateTime(2026, 10, 1, 8),
        ],
        workouts: [
          ActivitySession(
            id: 'w1',
            activityType: ActivityType.run,
            startTime: DateTime(2026, 10, 1, 7),
            endTime: DateTime(2026, 10, 1, 7, 30),
            totalDistanceMeters: 5000,
            totalDurationSeconds: 1800,
            avgPaceSecondsPerKm: 360,
            calories: 300,
            steps: 5000,
            stepCountReliable: true,
            points: const [],
          ),
        ],
      ),
    );
    expect(
      files.keys,
      containsAll([
        'README.txt',
        'water.csv',
        'sleep.csv',
        'meals.csv',
        'weight.csv',
        'workouts.csv',
        'mood.csv',
        'workouts.json',
      ]),
    );
    expect(files.containsKey('profile.json'), isFalse);
    expect(files['water.csv'], contains('2026-10-01T08:00:00.000,250'));
    expect(files['workouts.csv'], contains(',run,1800,5000,300,5000'));

    final zip = ZipDecoder().decodeBytes(zipExport(files));
    final water = zip.findFile('water.csv')!;
    expect(utf8.decode(water.content as List<int>), files['water.csv']);
  });
}
