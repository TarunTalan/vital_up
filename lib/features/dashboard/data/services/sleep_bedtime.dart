import 'package:shared_preferences/shared_preferences.dart';

/// "Going to bed" taps, stored per user in SharedPreferences so the
/// notification action (background isolate) and the app share them.

/// Notification shown while the user is in bed, with an "I'm up" action.
/// Outside the reminder id range (`reminder_schedule.dart`).
const inBedNotificationId = 999000001;

/// A bedtime older than this is forgotten (they never tapped "I'm up").
const maxTimeInBed = Duration(hours: 18);

/// "I'm up" sooner than this after "Going to bed" just cancels it: too
/// short to be a night.
const minTimeInBed = Duration(minutes: 30);

String bedtimeKey(String userId) => 'sleep_bedtime_$userId';

/// The bedtime the user tapped, if it is recent enough to still be open.
DateTime? readBedtime(SharedPreferences prefs, String userId, DateTime now) {
  final ms = prefs.getInt(bedtimeKey(userId));
  if (ms == null) return null;
  final at = DateTime.fromMillisecondsSinceEpoch(ms);
  if (at.isAfter(now) || now.difference(at) > maxTimeInBed) return null;
  return at;
}

Future<void> writeBedtime(SharedPreferences prefs, String userId, DateTime at) =>
    prefs.setInt(bedtimeKey(userId), at.millisecondsSinceEpoch);

Future<void> clearBedtime(SharedPreferences prefs, String userId) =>
    prefs.remove(bedtimeKey(userId));
