import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/features/vita/domain/entities/vita_insights.dart';
import 'package:vital_up/features/vita/domain/entities/vita_message.dart';

/// On-device Vita storage (SharedPreferences), scoped to the signed-in user
/// so a different account on the same phone never sees someone else's chat.
class VitaLocalDataSource {
  final SharedPreferences _prefs;

  static const maxMessages = 50;
  VitaLocalDataSource(this._prefs);

  Future<void> reload() => _prefs.reload();

  String _key(String name, String userId) => 'vita_${name}_$userId';

  // --- Chat -----------------------------------------------------------------

  /// How far up from the latest message the chat was left; null at the end.
  double? readChatScroll(String userId) {
    final value = _prefs.getDouble(_key('chatscroll', userId));
    return value != null && value.isFinite && value > 0 ? value : null;
  }

  Future<void> writeChatScroll(String userId, double? offset) {
    final key = _key('chatscroll', userId);
    return offset == null || !offset.isFinite || offset <= 0
        ? _prefs.remove(key)
        : _prefs.setDouble(key, offset);
  }

  List<VitaMessage> readChat(String userId) =>
      _readList(_key('chat', userId), VitaMessage.fromJson);

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

  List<StressCheckIn> readCheckIns(String userId) =>
      _readList(_key('checkins', userId), StressCheckIn.fromJson);

  Future<void> addCheckIn(String userId, StressCheckIn checkIn) async {
    // The mood widget writes check-ins from another isolate; start from
    // what's on disk so this write can't drop one made there.
    await _prefs.reload();
    final stored = readCheckIns(userId);
    // Check-ins and scores are kept for streaks and the 30-day stress trend.
    final cutoff = historyCutoff(stored.map((c) => c.date), DateTime.now());
    final list =
        stored
            .where(
              (c) => c.date.isAfter(cutoff) && !_sameDay(c.date, checkIn.date),
            )
            .toList()
          ..add(checkIn);
    await _prefs.setString(
      _key('checkins', userId),
      jsonEncode(list.map((c) => c.toJson()).toList()),
    );
  }

  /// Day ("yyyy-mm-dd") -> score, last 30 days.
  Map<String, int> readScores(String userId) {
    final raw = _prefs.getString(_key('scores', userId));
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return {};
      return {
        for (final e in decoded.entries)
          if (e.value is num) e.key: (e.value as num).toInt(),
      };
    } catch (e) {
      debugPrint('Vita scores unreadable: $e');
      return {};
    }
  }

  Future<void> writeScore(String userId, DateTime day, int score) {
    final scores = readScores(userId);
    final cutoff = dayKey(
      historyCutoff(
        scores.keys.map(DateTime.tryParse).nonNulls,
        DateTime.now(),
      ),
    );
    scores
      ..removeWhere((k, _) => k.compareTo(cutoff) < 0)
      ..[dayKey(day)] = score;
    return _prefs.setString(_key('scores', userId), jsonEncode(scores));
  }

  // --- Daily AI insights cache ---------------------------------------------

  VitaDailyInsights? readInsights(String userId) {
    final raw = _prefs.getString(_key('insights', userId));
    if (raw == null) return null;
    try {
      return VitaDailyInsights.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> writeInsights(String userId, VitaDailyInsights insights) =>
      _prefs.setString(_key('insights', userId), jsonEncode(insights.toJson()));

  // --- Helpers ---------------------------------------------------------------

  /// Reads a stored JSON list. A malformed entry is skipped rather than
  /// discarding the whole list (the next write would otherwise erase it).
  List<T> _readList<T>(String key, T Function(Map<String, dynamic>) parse) {
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (e) {
      debugPrint('Vita $key unreadable: $e');
      return [];
    }
    if (decoded is! List) return [];
    final items = <T>[];
    for (final item in decoded.whereType<Map<String, dynamic>>()) {
      try {
        items.add(parse(item));
      } catch (e) {
        debugPrint('Vita $key: skipped bad entry ($e)');
      }
    }
    return items;
  }

  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
