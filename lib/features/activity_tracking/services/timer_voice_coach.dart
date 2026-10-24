import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:vital_up/core/preferences/workout_prefs_notifier.dart';
import 'package:vital_up/features/activity_tracking/data/services/workout_timer_store.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/workout_intensity.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/workout_timer.dart';
import 'package:vital_up/features/activity_tracking/domain/services/timer_coach_rules.dart';
import 'package:vital_up/features/activity_tracking/domain/services/workout_log_rules.dart';
import 'package:vital_up/features/activity_tracking/services/voice_coach_service.dart';

/// The voice coach for timed workouts, app-wide rather than on the timer
/// screen: the timer keeps running when that screen is left, and Pause /
/// Resume can come from the notification. Follows [WorkoutTimerStore]
/// and looks at the clock every few seconds while it runs: "Activity
/// started / paused / resumed", then [timerCue]s (every 5 minutes with
/// calories, halfway to the goal, goal reached). Only with the voice
/// coach on in the workout settings. Speaks while the app process lives
/// (also in the background).
class TimerVoiceCoach {
  final WorkoutTimerStore _store;
  final VoiceCoachService _voice;
  final Future<double?> Function() _weightKg;
  final Future<WorkoutPrefs> Function() _prefs;
  final DateTime Function() _clock;

  TimerVoiceCoach({
    required this._store,
    required this._voice,
    required this._weightKg,
    Future<WorkoutPrefs> Function()? prefs,
    DateTime Function()? clock,
  }) : _prefs = prefs ?? WorkoutPrefsNotifier.read,
       _clock = clock ?? DateTime.now;

  static const checkEvery = Duration(seconds: 5);

  StreamSubscription<void>? _changes;
  Timer? _ticker;

  /// What was last seen, to tell starts, pauses and resumes apart.
  WorkoutTimer? _last;

  /// Active time at the last look, for cues crossed since.
  Duration? _checked;
  double? _weight;
  bool _quiet = false;

  /// Starts following the timer. Safe to call more than once.
  void start() {
    if (_changes != null) return;
    _changes = _store.changes.listen((_) => _onChange());
    _last = _store.read();
    _checked = _last?.elapsed(_clock());
    _syncTicker();
  }

  /// The next change is the app's own (Finish pauses the clock while the
  /// intensity is picked): say nothing about it.
  void skipNextChange() => _quiet = true;

  @visibleForTesting
  Future<void> onChangeForTest() => _onChange();

  @visibleForTesting
  Future<void> tickForTest() => _tick();

  Future<void> _onChange() async {
    final before = _last;
    final now = _store.read();
    _last = now;
    _syncTicker();
    if (_quiet) {
      _quiet = false;
      _checked = now?.elapsed(_clock());
      return;
    }
    final String? line;
    if (now == null) {
      _checked = null;
      line = null; // Finished or discarded: the screen says how it went.
    } else if (before == null || before.startedAt != now.startedAt) {
      _weight = null;
      _checked = Duration.zero;
      line = "Activity started. Let's go!";
    } else if (before.isRunning && !now.isRunning) {
      line = 'Activity paused.';
    } else if (!before.isRunning && now.isRunning) {
      line = 'Activity resumed.';
    } else {
      line = null;
    }
    if (line != null && await _enabled()) await _voice.say(line);
  }

  void _syncTicker() {
    final running = _last?.isRunning ?? false;
    if (running && _ticker == null) {
      _ticker = Timer.periodic(checkEvery, (_) => _tick());
    } else if (!running) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  Future<void> _tick() async {
    final timer = _last;
    if (timer == null || !timer.isRunning) return;
    final now = timer.elapsed(_clock());
    final before = _checked ?? now;
    _checked = now;
    if (now <= before) return;
    final prefs = await _prefs();
    if (!prefs.voiceCoachEnabled) return;
    final weight = _weight ??=
        await _weightKg() ?? WorkoutLogRules.fallbackWeightKg;
    int calories(Duration time) => estimateWorkoutCalories(
      timer.type,
      WorkoutIntensity.moderate,
      time,
      weightKg: weight,
    );
    final hasTarget =
        prefs.timerTargetType != WorkoutTargetType.none &&
        prefs.timerTargetValue > 0;
    final cue = timerCue(
      before: before,
      now: now,
      caloriesBefore: calories(before),
      caloriesNow: calories(now),
      target: hasTarget
          ? (type: prefs.timerTargetType, value: prefs.timerTargetValue)
          : null,
    );
    if (cue != null) await _voice.say(cue);
  }

  Future<bool> _enabled() async {
    try {
      return (await _prefs()).voiceCoachEnabled;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _changes?.cancel();
    _changes = null;
    _ticker?.cancel();
    _ticker = null;
  }
}
