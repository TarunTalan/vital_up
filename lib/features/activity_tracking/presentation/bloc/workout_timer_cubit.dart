import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/preferences/workout_prefs_notifier.dart';
import 'package:vital_up/features/activity_tracking/data/services/workout_timer_notification.dart';
import 'package:vital_up/features/activity_tracking/data/services/workout_timer_store.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_session.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/workout_intensity.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/workout_timer.dart';
import 'package:vital_up/features/activity_tracking/domain/services/workout_log_rules.dart';
import 'package:vital_up/features/activity_tracking/domain/usecases/log_workout.dart';
import 'package:vital_up/features/activity_tracking/presentation/utils/activity_target_rules.dart';

enum WorkoutSaveOutcome { saved, tooShort, failed }

class WorkoutTimerState extends Equatable {
  /// Type of the next workout, or of [timer] once started.
  final ActivityType type;

  /// The workout being timed; null before Start.
  final WorkoutTimer? timer;

  /// Clock reading the elapsed time is shown for (ticks every second).
  final DateTime now;
  final bool saving;

  /// The user's weight for the live calorie figure; null until read or
  /// when unknown (an average is used).
  final double? weightKg;

  const WorkoutTimerState({
    required this.type,
    required this.now,
    this.timer,
    this.saving = false,
    this.weightKg,
  });

  Duration get elapsed => timer?.elapsed(now) ?? Duration.zero;
  bool get isStarted => timer != null;
  bool get isRunning => timer?.isRunning ?? false;

  /// Stopped by [WorkoutLogRules.maxLength], not by the user.
  bool get reachedLimit => timer?.isAtLimit(now) ?? false;

  /// Calories so far at moderate effort; the saved figure follows the
  /// intensity picked when finishing.
  int get caloriesSoFar => estimateWorkoutCalories(
    type,
    WorkoutIntensity.moderate,
    elapsed,
    weightKg: weightKg ?? WorkoutLogRules.fallbackWeightKg,
  );

  WorkoutTimerState copyWith({
    ActivityType? type,
    WorkoutTimer? timer,
    bool clearTimer = false,
    DateTime? now,
    bool? saving,
    double? weightKg,
  }) {
    return WorkoutTimerState(
      type: type ?? this.type,
      timer: clearTimer ? null : (timer ?? this.timer),
      now: now ?? this.now,
      saving: saving ?? this.saving,
      weightKg: weightKg ?? this.weightKg,
    );
  }

  @override
  List<Object?> get props => [type, timer?.encode(), now, saving, weightKg];
}

/// Times a workout without a route. The timer is wall-clock times saved on
/// every change, so closing the app (or the OS killing it) loses nothing
/// and needs no foreground service: GPS workouts own that service. The
/// [notifier] keeps it in the notification tray, whose Pause / Resume
/// buttons write the same store (followed here through [WorkoutTimerStore.changes]).
class WorkoutTimerCubit extends Cubit<WorkoutTimerState> {
  final WorkoutTimerStore store;
  final LogWorkout logWorkout;
  final WorkoutTimerNotifier? notifier;
  final DateTime Function() _clock;
  Timer? _ticker;

  /// The workout [finish] saved last, for its result screen.
  ActivitySession? lastSaved;
  StreamSubscription<void>? _storeChanges;

  WorkoutTimerCubit({
    required this.store,
    required this.logWorkout,
    required ActivityType type,
    this.notifier,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       super(
         WorkoutTimerState(
           type: type.isGpsBased ? ActivityType.strength : type,
           now: (clock ?? DateTime.now)(),
         ),
       ) {
    // A workout already being timed wins over the type asked for.
    final saved = store.read();
    if (saved != null) {
      emit(state.copyWith(type: saved.type, timer: saved));
      tick();
      notifier?.show(state.timer ?? saved, _clock());
    } else {
      // A notification left from a timer already finished elsewhere.
      notifier?.cancel();
    }
    _storeChanges = store.changes.listen((_) => _followStore());
    _loadWeight();
  }

  Future<void> _loadWeight() async {
    try {
      final weight = await logWorkout.weightKg();
      if (weight != null) emit(state.copyWith(weightKg: weight));
    } catch (e) {
      debugPrint('Reading weight for the workout timer failed: $e');
    }
  }

  /// Re-reads the saved timer, e.g. on returning to the app after Pause or
  /// Resume was tapped on the notification (another isolate wrote it).
  Future<void> reload() async {
    try {
      await store.prefs.reload();
    } catch (e) {
      debugPrint('Reloading workout timer failed: $e');
    }
    _followStore();
  }

  void _followStore() {
    if (state.saving) return;
    final saved = store.read();
    emit(
      saved == null
          ? state.copyWith(clearTimer: true, now: _clock())
          : state.copyWith(type: saved.type, timer: saved, now: _clock()),
    );
    _syncTicker();
  }

  @override
  void emit(WorkoutTimerState state) {
    if (isClosed) return;
    super.emit(state);
  }

  void selectType(ActivityType type) {
    if (state.isStarted || type.isGpsBased) return;
    emit(state.copyWith(type: type));
  }

  Future<void> start() async {
    if (state.isStarted) return;
    // Without it the tray can't show the timer (the timer still works).
    await notifier?.requestPermission();
    await _save(WorkoutTimer.start(state.type, _clock()));
  }

  Future<void> pause() async {
    final timer = state.timer;
    if (timer == null || !timer.isRunning) return;
    await _save(timer.pause(_clock()));
  }

  Future<void> resume() async {
    final timer = state.timer;
    if (timer == null || timer.isRunning || state.reachedLimit) return;
    await _save(timer.resume(_clock()));
  }

  /// Drops the workout being timed without saving it.
  Future<void> discard() async {
    await notifier?.cancel();
    await store.clear();
    emit(state.copyWith(clearTimer: true, now: _clock()));
    _syncTicker();
  }

  /// Saves the timed workout at [intensity] (with its [target], if any) and
  /// clears the timer.
  Future<WorkoutSaveOutcome> finish(
    WorkoutIntensity intensity, {
    ({WorkoutTargetType type, double value})? target,
  }) async {
    final timer = state.timer;
    if (timer == null || state.saving) return WorkoutSaveOutcome.failed;
    final now = _clock();
    final paused = timer.pause(now);
    await _save(paused);
    final length = paused.elapsed(now);
    if (length < WorkoutLogRules.minLength) return WorkoutSaveOutcome.tooShort;

    emit(state.copyWith(saving: true));
    try {
      lastSaved = await logWorkout(
        type: paused.type,
        start: paused.startedAt,
        length: length,
        intensity: intensity,
        targetType: target?.type.name,
        targetValue: target?.value,
        targetAchieved:
            target != null &&
            isActivityTargetMet(
              target.type,
              target.value,
              distanceMeters: 0,
              calories: estimateWorkoutCalories(
                paused.type,
                intensity,
                length,
                weightKg: state.weightKg ?? WorkoutLogRules.fallbackWeightKg,
              ),
              elapsed: length,
            ),
      );
    } catch (e) {
      debugPrint('Saving timed workout failed: $e');
      emit(state.copyWith(saving: false));
      return WorkoutSaveOutcome.failed;
    }
    await notifier?.cancel();
    await store.clear();
    emit(state.copyWith(clearTimer: true, saving: false, now: _clock()));
    _syncTicker();
    return WorkoutSaveOutcome.saved;
  }

  /// Re-reads the clock; stops the timer at [WorkoutLogRules.maxLength].
  void tick() {
    final now = _clock();
    final timer = state.timer;
    if (timer != null && timer.isRunning && timer.isAtLimit(now)) {
      _save(timer.pause(now)).ignore();
      return;
    }
    emit(state.copyWith(now: now));
    _syncTicker();
  }

  Future<void> _save(WorkoutTimer timer) async {
    // Store first: a change event from an earlier write that arrives while
    // this one is in progress then reads this timer, not the old one.
    try {
      await store.write(timer);
    } catch (e) {
      // The screen still times it; only a restart would lose it.
      debugPrint('Saving workout timer failed: $e');
    }
    final now = _clock();
    emit(state.copyWith(timer: timer, type: timer.type, now: now));
    _syncTicker();
    await notifier?.show(timer, now);
  }

  void _syncTicker() {
    if (state.isRunning) {
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) => tick());
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  @override
  Future<void> close() {
    _ticker?.cancel();
    _storeChanges?.cancel();
    return super.close();
  }
}
