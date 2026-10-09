import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:vital_up/core/events/habit_events.dart';
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

  /// The signed-in user, so water reminders can log "+250 ml" for them.
  final String? Function() _userId;

  RemindersService(
    this._local,
    this._scheduler,
    this._settings, {
    String? Function()? userId,
  }) : _userId = userId ?? (() => null);

  StreamSubscription<HabitLogged>? _habits;
  AppLifecycleListener? _lifecycle;

  /// Re-arms reminders skipped yesterday when the app is reopened on a new
  /// day (needed on iOS, where a skipped reminder becomes a one-off).
  /// Also resyncs when the time zone changed while away, so reminders keep
  /// their wall-clock times after travelling.
  void resyncOnNewDay() {
    String stamp() {
      final now = DateTime.now();
      return '${dayKey(now)}|${now.timeZoneOffset.inMinutes}|${now.timeZoneName}';
    }

    var last = stamp();
    _lifecycle ??= AppLifecycleListener(
      onResume: () {
        final current = stamp();
        if (current == last) return;
        last = current;
        resync();
      },
    );
  }

  /// Quiets reminders for the rest of the day once their habit is logged.
  void watch(Stream<HabitLogged> habits) {
    _habits?.cancel();
    _habits = habits.listen((event) async {
      try {
        await markDone(event);
      } catch (e) {
        debugPrint('Reminder skip failed: $e');
      }
    });
  }

  bool smartSkip() => _local.smartSkip();

  Future<void> setSmartSkip(bool value) async {
    await _local.setSmartSkip(value);
    await _sync(_local.load());
  }

  /// Skips today's remaining reminders made unnecessary by [event].
  Future<void> markDone(HabitLogged event) async {
    if (!_local.smartSkip()) return;
    final reminders = _local.load();
    final today = dayKey(DateTime.now());
    final done = remindersDoneBy(
      event,
      reminders,
    ).difference(_local.skippedOn(today));
    if (done.isEmpty) return;
    await _local.addSkipped(today, done);
    await _sync(reminders);
  }

  List<Reminder> load() => _local.load();

  Future<bool> notificationsEnabled() async {
    try {
      final result = await _settings.getSettings();
      return result.fold((_) => true, (s) => s.notificationsEnabled);
    } catch (e) {
      debugPrint('Settings unreadable, assuming notifications on: $e');
      return true;
    }
  }

  Future<bool> requestPermission() => _scheduler.requestPermission();

  /// Null when unknown; see [ReminderScheduler.permissionGranted].
  Future<bool?> permissionGranted() => _scheduler.permissionGranted();

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
    await _local.saveScheduledIds(
      await _scheduler.schedule(
        plan,
        skippedToday: _local.smartSkip()
            ? _local.skippedOn(dayKey(DateTime.now()))
            : const {},
        userId: _userId(),
      ),
    );
    return plan.dropped;
  }
}
