import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/preferences/distance_unit_notifier.dart';
import 'package:vital_up/core/preferences/workout_prefs_notifier.dart';
import 'package:vital_up/features/activity_tracking/presentation/utils/activity_target_rules.dart';
import 'package:vital_up/features/activity_tracking/presentation/widgets/hr_device_sheet.dart';
import 'package:vital_up/features/activity_tracking/services/in_app_audio_downloader.dart';

void main() {
  group('parseActivityTarget', () {
    test('empty input asks for a target', () {
      final r = parseActivityTarget(WorkoutTargetType.distance, '  ', DistanceUnit.km);
      expect(r.value, isNull);
      expect(r.error, 'Enter a target');
    });

    test('distance in km is returned as typed, comma accepted', () {
      final r = parseActivityTarget(WorkoutTargetType.distance, '5,5', DistanceUnit.km);
      expect(r.value, 5.5);
      expect(r.error, isNull);
    });

    test('distance in miles is converted to km', () {
      final r = parseActivityTarget(WorkoutTargetType.distance, '2', DistanceUnit.miles);
      expect(r.value, closeTo(3.21868, 1e-6));
    });

    test('zero, negative and huge distances are rejected', () {
      for (final input in ['0', '-3', '1000', 'abc', 'NaN', 'Infinity']) {
        final r = parseActivityTarget(WorkoutTargetType.distance, input, DistanceUnit.km);
        expect(r.value, isNull, reason: input);
        expect(r.error, 'Enter 0.1 to 300 km', reason: input);
      }
    });

    test('calories are range checked and rounded', () {
      expect(parseActivityTarget(WorkoutTargetType.calories, '250.6', DistanceUnit.km).value, 251);
      final r = parseActivityTarget(WorkoutTargetType.calories, '5', DistanceUnit.km);
      expect(r.value, isNull);
      expect(r.error, 'Enter 10 to 5000 kcal');
      expect(parseActivityTarget(WorkoutTargetType.calories, '99999', DistanceUnit.km).value, isNull);
    });
  });

  group('parseHeartRateMeasurement', () {
    test('8-bit value', () => expect(parseHeartRateMeasurement([0x00, 72]), 72));
    test('16-bit value', () => expect(parseHeartRateMeasurement([0x01, 0x8C, 0x00]), 140));
    test('short packets are ignored', () {
      expect(parseHeartRateMeasurement([]), isNull);
      expect(parseHeartRateMeasurement([0x00]), isNull);
      expect(parseHeartRateMeasurement([0x01, 0x8C]), isNull);
    });
    test('loose-strap zero and absurd values are ignored', () {
      expect(parseHeartRateMeasurement([0x00, 0]), isNull);
      expect(parseHeartRateMeasurement([0x01, 0xFF, 0x01]), isNull); // 511
    });
  });

  group('safeAudioFileName', () {
    test('keeps ids inside the audio folder', () {
      expect(safeAudioFileName("Story: It's Possible"), 'Story_It_s_Possible');
      expect(safeAudioFileName('../../etc/passwd'), '_etc_passwd');
      expect(safeAudioFileName(''), 'track');
      expect(safeAudioFileName('a' * 200).length, 80);
    });
  });
}
