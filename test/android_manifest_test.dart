import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Play's Health Connect minimum-scope policy: every data type the app asks
/// for must be shown by a feature a reviewer can find. Heart rate and HRV
/// were rejected (Oct 2026) because nothing on screen displayed them. Add a
/// type here only together with the feature that shows it, and update the
/// Play Console declaration and privacy.html.
void main() {
  test('only Health Connect types a visible feature uses', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final requested = RegExp(
      r'android\.permission\.health\.(\w+)',
    ).allMatches(manifest).map((m) => m.group(1)!).toSet();
    expect(requested, {
      'READ_SLEEP', // sleep card, sleep trends
      'READ_STEPS', // Home, activity goals, Arena
      'READ_WEIGHT', // Health Sync weight import
      'READ_EXERCISE', // Health Sync workout import
      'READ_DISTANCE', // imported workouts' distance
      'READ_TOTAL_CALORIES_BURNED', // imported workouts' calories
    });
  });
}
