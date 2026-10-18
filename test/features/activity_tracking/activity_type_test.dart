import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';

void main() {
  test('stored names read back, unknown ones become Other workout', () {
    for (final t in ActivityType.values) {
      expect(ActivityType.fromName(t.name), t);
    }
    // A type added by a newer app version on another device.
    expect(ActivityType.fromName('rowing'), ActivityType.other);
    expect(ActivityType.fromName(null), ActivityType.other);
  });

  test('only GPS types can start a tracked workout', () {
    expect(ActivityType.outdoor, [
      ActivityType.walk,
      ActivityType.run,
      ActivityType.cycle,
      ActivityType.trekking,
      ActivityType.climbing,
    ]);
    expect(
      ActivityType.workouts.toSet().intersection(
        ActivityType.outdoor.toSet(),
      ),
      isEmpty,
    );
    expect(
      ActivityType.outdoor.length + ActivityType.workouts.length,
      ActivityType.values.length,
    );
  });

  test('workouts have a calorie rate and no distance-based one', () {
    for (final t in ActivityType.workouts) {
      expect(t.met, greaterThan(0), reason: t.name);
      expect(t.kcalPerKgPerKm, 0, reason: t.name);
    }
  });
}
