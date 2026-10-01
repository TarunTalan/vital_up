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

  Future<void> clear() async {
    await _prefs.remove(_keyReminders);
    await _prefs.remove(_keyScheduledIds);
  }
}
