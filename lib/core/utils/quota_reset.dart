import 'package:intl/intl.dart';

/// Daily AI and scan quotas reset at 00:00 India time on the server
/// (`ai_quota_day()`), which is not midnight for users elsewhere.
const _serverOffset = Duration(hours: 5, minutes: 30);

/// The next quota reset as a local time.
DateTime nextQuotaReset({DateTime? now}) {
  final utc = (now ?? DateTime.now()).toUtc();
  final server = utc.add(_serverOffset);
  final nextServerMidnight = DateTime.utc(
    server.year,
    server.month,
    server.day + 1,
  );
  return nextServerMidnight.subtract(_serverOffset).toLocal();
}

/// "midnight" or a clock time such as "11:30 AM", for quota messages.
String quotaResetTime({DateTime? now}) {
  final reset = nextQuotaReset(now: now);
  if (reset.hour == 0 && reset.minute == 0) return 'midnight';
  return DateFormat('h:mm a').format(reset);
}
