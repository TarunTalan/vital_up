import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/features/reminders/domain/entities/reminder.dart';
import 'package:vital_up/features/reminders/domain/reminder_presets.dart';

/// Reminders live on this device only.
class RemindersLocalDataSource {
  final SharedPreferences _prefs;

  RemindersLocalDataSource(this._prefs);

  static const _keyReminders = 'reminders_v1';
  static const _keyScheduledIds = 'reminders_scheduled_ids';
  static const _keySmartSkip = 'reminders_smart_skip';
  static const _keySkipped = 'reminders_skipped_on';

  /// Saved reminders merged with the built-in presets.
  List<Reminder> load() {
    final raw = _prefs.getString(_keyReminders);
    if (raw == null) return mergeWithPresets(const []);
    try {
      final list = jsonDecode(raw) as List;
      return mergeWithPresets([
        for (final item in list)
          Reminder.fromJson(Map<String, dynamic>.from(item as Map)),
      ]);
    } catch (e) {
      debugPrint('Saved reminders unreadable, using defaults: $e');
      return mergeWithPresets(const []);
    }
  }

  Future<void> save(List<Reminder> reminders) => _prefs.setString(
    _keyReminders,
    jsonEncode([for (final r in reminders) r.toJson()]),
  );

  /// System notification ids currently scheduled, so they can be cancelled.
  List<int> scheduledIds() => [
    for (final id in _prefs.getStringList(_keyScheduledIds) ?? const [])
      ?int.tryParse(id),
  ];

  Future<void> saveScheduledIds(List<int> ids) =>
      _prefs.setStringList(_keyScheduledIds, [for (final id in ids) '$id']);

  /// Stay quiet once a habit is done for the day (default on).
  bool smartSkip() => _prefs.getBool(_keySmartSkip) ?? true;

  Future<void> setSmartSkip(bool value) => _prefs.setBool(_keySmartSkip, value);

  /// Reminder ids already done today, keyed by their `yyyy-mm-dd`.
  Set<String> skippedOn(String day) {
    final raw = _prefs.getString(_keySkipped);
    if (raw == null) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final e in map.entries)
          if (e.value == day) e.key,
      };
    } catch (_) {
      return {};
    }
  }

  /// Marks [ids] done on [day]; entries for other days are dropped.
  Future<void> addSkipped(String day, Iterable<String> ids) => _prefs.setString(
    _keySkipped,
    jsonEncode({
      for (final id in skippedOn(day)) id: day,
      for (final id in ids) id: day,
    }),
  );

  Future<void> clear() async {
    await _prefs.remove(_keyReminders);
    await _prefs.remove(_keyScheduledIds);
    await _prefs.remove(_keySkipped);
  }
}
