import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/features/vita/domain/entities/vita_insights.dart';
import 'package:vital_up/features/vita/domain/entities/vita_message.dart';

/// On-device Vita storage (SharedPreferences), scoped to the signed-in user
/// so a different account on the same phone never sees someone else's chat.
class VitaLocalDataSource {
  final SharedPreferences _prefs;

  static const maxMessages = 50;
  /// Check-ins and scores kept for streaks and the 30-day stress trend.
  static const _historyDays = 90;

  VitaLocalDataSource(this._prefs);

  Future<void> reload() => _prefs.reload();

  String _key(String name, String userId) => 'vita_${name}_$userId';

  // --- Chat -----------------------------------------------------------------

  List<VitaMessage> readChat(String userId) => _readList(
        _key('chat', userId),
        VitaMessage.fromJson,
      );

  Future<void> writeChat(String userId, List<VitaMessage> messages) {
    final kept = messages.length > maxMessages
        ? messages.sublist(messages.length - maxMessages)
        : messages;
    return _prefs.setString(
      _key('chat', userId),
      jsonEncode(kept.map((m) => m.toJson()).toList()),
    );
  }

  // --- Stress check-ins & daily scores -------------------------------------

  List<StressCheckIn> readCheckIns(String userId) => _readList(
        _key('checkins', userId),
        StressCheckIn.fromJson,
      );

  Future<void> addCheckIn(String userId, StressCheckIn checkIn) {
    final cutoff = DateTime.now().subtract(const Duration(days: _historyDays));
    final list = readCheckIns(userId)
        .where((c) => c.date.isAfter(cutoff) && !_sameDay(c.date, checkIn.date))
        .toList()
      ..add(checkIn);
    return _prefs.setString(
      _key('checkins', userId),
      jsonEncode(list.map((c) => c.toJson()).toList()),
    );
  }

  /// Day ("yyyy-mm-dd") -> score, last 30 days.
  Map<String, int> readScores(String userId) {
    final raw = _prefs.getString(_key('scores', userId));
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  Future<void> writeScore(String userId, DateTime day, int score) {
    final cutoff = dayKey(DateTime.now().subtract(const Duration(days: _historyDays)));
    final scores = readScores(userId)
      ..removeWhere((k, _) => k.compareTo(cutoff) < 0)
      ..[dayKey(day)] = score;
    return _prefs.setString(_key('scores', userId), jsonEncode(scores));
  }

  // --- Daily AI insights cache ---------------------------------------------

  VitaDailyInsights? readInsights(String userId) {
    final raw = _prefs.getString(_key('insights', userId));
    if (raw == null) return null;
    try {
      return VitaDailyInsights.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> writeInsights(String userId, VitaDailyInsights insights) =>
      _prefs.setString(_key('insights', userId), jsonEncode(insights.toJson()));

  // --- Helpers ---------------------------------------------------------------

  List<T> _readList<T>(String key, T Function(Map<String, dynamic>) parse) {
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .whereType<Map<String, dynamic>>()
          .map(parse)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
