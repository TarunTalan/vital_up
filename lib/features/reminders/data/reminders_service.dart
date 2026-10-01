import 'package:flutter/foundation.dart';
import 'package:vital_up/features/reminders/data/reminder_scheduler.dart';
import 'package:vital_up/features/reminders/data/reminders_local_datasource.dart';
import 'package:vital_up/features/reminders/domain/entities/reminder.dart';
import 'package:vital_up/features/reminders/domain/reminder_presets.dart';
import 'package:vital_up/features/reminders/domain/reminder_schedule.dart';
import 'package:vital_up/features/settings/domain/repositories/settings_repository.dart';

/// Saves reminders and keeps the system schedule in step with them and with
/// the global Notifications switch.
class RemindersService {
  final RemindersLocalDataSource _local;
  final ReminderScheduler _scheduler;
  final SettingsRepository _settings;

  RemindersService(this._local, this._scheduler, this._settings);

  List<Reminder> load() => _local.load();

  Future<bool> notificationsEnabled() async {
    final result = await _settings.getSettings();
    return result.fold((_) => true, (s) => s.notificationsEnabled);
  }

  Future<bool> requestPermission() => _scheduler.requestPermission();

  /// Saves [reminders] and reschedules. Returns how many notifications were
  /// left out to stay under the system limit.
  Future<int> save(List<Reminder> reminders) async {
    await _local.save(reminders);
    return _sync(reminders);
  }

  /// Re-applies the saved reminders (startup, time-zone change, Notifications
  /// switch flipped).
  Future<void> resync() async {
    try {
      await _scheduler.init();
      await _sync(_local.load());
    } catch (e) {
      debugPrint('Reminder resync failed: $e');
    }
  }

  /// Onboarding "Health reminders": turns on the starter presets.
  Future<void> enableStarterSet() async {
    await _scheduler.requestPermission();
    await save([
      for (final r in _local.load())
        starterPresetIds.contains(r.id) ? r.copyWith(enabled: true) : r,
    ]);
  }

  /// Before sign-out: the next account on this device starts clean.
  Future<void> clear() async {
    await _scheduler.cancel(_local.scheduledIds());
    await _local.clear();
  }

  Future<int> _sync(List<Reminder> reminders) async {
    await _scheduler.cancel(_local.scheduledIds());
    if (!await notificationsEnabled()) {
      await _local.saveScheduledIds(const []);
      return 0;
    }
    final plan = planReminders(reminders);
    await _local.saveScheduledIds(await _scheduler.schedule(plan));
    return plan.dropped;
  }
}
