import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_session.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/track_point.dart';
import 'package:vital_up/features/activity_tracking/domain/services/geo_math.dart';
import 'package:vital_up/features/activity_tracking/domain/usecases/get_live_location_stream.dart';
import 'package:vital_up/features/activity_tracking/domain/usecases/get_live_steps_stream.dart';
import 'package:vital_up/features/activity_tracking/domain/usecases/stop_and_save_session.dart';
import 'package:vital_up/features/activity_tracking/presentation/bloc/activity_tracking_event.dart';
import 'package:vital_up/features/activity_tracking/presentation/bloc/activity_tracking_state.dart';
import 'package:vital_up/features/activity_tracking/presentation/bloc/foreground_service_manager.dart';
import 'package:vital_up/features/auth/domain/repositories/auth_repository.dart';

class ActivityTrackingBloc extends Bloc<ActivityTrackingEvent, ActivityTrackingState> {
  final GetLiveLocationStream getLiveLocationStream;
  final GetLiveStepsStream getLiveStepsStream;
  final StopAndSaveSession stopAndSaveSession;
  final AuthRepository authRepository;

  /// How often a running workout is checkpointed to the local database.
  static const Duration _checkpointInterval = Duration(seconds: 30);

  /// Wait before re-subscribing after the GPS stream errors or closes
  /// (location toggled off, provider restart…).
  static const Duration _gpsRetryDelay = Duration(seconds: 3);

  /// No fix for this long means we can't claim the user is still moving.
  static const Duration _speedStaleAfter = Duration(seconds: 5);

  /// Climb only counts once altitude moves this far from the last
  /// reference, so GPS altitude jitter isn't summed into fake gain.
  static const double _elevationThresholdMeters = 3.0;

  /// Below this distance avg pace is dominated by noise (e.g. 200:00 /km).
  static const double _minDistanceForPaceMeters = 20.0;

  StreamSubscription<TrackPoint>? _locationSubscription;
  StreamSubscription<int>? _stepSubscription;
  Timer? _timer;
  Timer? _gpsRetryTimer;

  /// Monotonic active-time clock: unaffected by wall-clock changes (NTP,
  /// timezone, manual edits) and naturally excludes paused time.
  final Stopwatch _activeClock = Stopwatch();

  /// Monotonic clock for "when did the last fix arrive", independent of
  /// the GPS timestamps (which follow the satellite clock).
  final Stopwatch _sessionClock = Stopwatch();
  Duration? _lastFixAt;

  String? _currentSessionId;
  DateTime? _startedAt;
  int _currentSteps = 0;
  int _lastRawSteps = 0;
  int _rawStepsAtPause = 0;
  int _ignoredPausedSteps = 0;
  bool _stepCountReliable = true;
  bool _skipDistanceForNextPoint = false;
  bool _isStarting = false;
  bool _isStopping = false;

  double _elevationGain = 0.0;
  double? _elevationReference;

  /// User weight cached at session start to avoid hitting the DB on every tick.
  double _cachedWeightKg = 70.0;

  Duration _lastCheckpointAt = Duration.zero;
  Future<void> _pendingSave = Future.value();
  DateTime? _stationarySince;

  ActivityTrackingBloc({
    required this.getLiveLocationStream,
    required this.getLiveStepsStream,
    required this.stopAndSaveSession,
    required this.authRepository,
  }) : super(const TrackingIdle()) {
    on<SelectActivityType>(_onSelectActivityType);
    on<StartTracking>(_onStartTracking);
    on<PauseTracking>(_onPauseTracking);
    on<ResumeTracking>(_onResumeTracking);
    on<StopAndSaveTracking>(_onStopAndSaveTracking);
    on<UpdateTrackPoint>(_onUpdateTrackPoint);
    on<UpdateSteps>(_onUpdateSteps);
    on<TickTimer>(_onTickTimer);
    on<ResetTracking>(_onResetTracking);
    on<PersistProgress>(_onPersistProgress);
  }

  bool get _isTracking =>
      state is TrackingInProgress || state is TrackingPaused;

  void _onSelectActivityType(SelectActivityType event, Emitter<ActivityTrackingState> emit) {
    if (state is! TrackingIdle || _isStarting) return;
    emit(TrackingIdle(activityType: event.activityType));
  }

  Future<void> _onStartTracking(StartTracking event, Emitter<ActivityTrackingState> emit) async {
    // Handlers run concurrently, and the awaits below leave the state Idle
    // for a while — without this a double tap starts two sessions.
    if (state is! TrackingIdle || _isStarting) return;
    _isStarting = true;

    try {
      final activityType = state.activityType;

      final hasPermission = await getLiveLocationStream.ensurePermission();
      if (!hasPermission) {
        emit(TrackingPermissionDenied(
          'Location permission is required for tracking.',
          activityType: activityType,
        ));
        // Back to Idle straight away so the user can retry or leave the
        // screen (the page only allows popping while Idle).
        emit(TrackingIdle(activityType: activityType));
        return;
      }

      final hasStepPermission = await getLiveStepsStream.ensurePermission();

      // Cache user weight once per session — avoids async DB hit on every tick.
      final userResult = await authRepository.getCurrentUser();
      _cachedWeightKg = userResult.fold(
        (failure) => 70.0,
        (user) {
          final weight = user?.weightKg;
          return weight != null && weight > 0 ? weight : 70.0;
        },
      );

      // Start the foreground service (and its permission prompts) before
      // the clock starts, so time spent in system dialogs isn't counted.
      try {
        await ForegroundServiceManager.start(activityName: activityType.label);
      } catch (e) {
        debugPrint('Foreground service failed to start: $e');
      }

      _currentSessionId = const Uuid().v4();
      _startedAt = DateTime.now();
      _activeClock
        ..reset()
        ..start();
      _sessionClock
        ..reset()
        ..start();
      _lastFixAt = null;
      _currentSteps = 0;
      _lastRawSteps = 0;
      _rawStepsAtPause = 0;
      _ignoredPausedSteps = 0;
      _stepCountReliable = hasStepPermission;
      _skipDistanceForNextPoint = false;
      _stationarySince = null;
      _elevationGain = 0.0;
      _elevationReference = null;
      _lastCheckpointAt = Duration.zero;

      emit(TrackingInProgress(
        activityType: activityType,
        elapsed: Duration.zero,
        distanceMeters: 0.0,
        avgPaceSecondsPerKm: 0,
        calories: 0,
        steps: 0,
        stepCountReliable: _stepCountReliable,
        routePoints: const [],
      ));

      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => add(TickTimer()));

      _subscribeToLocation(activityType);

      await _stepSubscription?.cancel();
      _stepSubscription = null;
      if (hasStepPermission) {
        _stepSubscription = getLiveStepsStream().listen(
          (steps) => add(UpdateSteps(steps)),
          onError: (Object e) {
            // Sensor missing or revoked: keep the workout going, but don't
            // present a frozen count as accurate.
            debugPrint('Step counter error: $e');
            _stepCountReliable = false;
          },
        );
      }
    } finally {
      _isStarting = false;
    }
  }

  void _subscribeToLocation(ActivityType activityType) {
    _gpsRetryTimer?.cancel();
    _locationSubscription?.cancel();
    _locationSubscription = getLiveLocationStream(activityType).listen(
      (point) => add(UpdateTrackPoint(point)),
      onError: (Object e) {
        debugPrint('GPS stream error: $e');
        _scheduleLocationRetry(activityType);
      },
      onDone: () => _scheduleLocationRetry(activityType),
      cancelOnError: true,
    );
  }

  /// Keeps recording through GPS hiccups instead of silently freezing the
  /// distance for the rest of the workout.
  void _scheduleLocationRetry(ActivityType activityType) {
    _locationSubscription = null;
    _gpsRetryTimer?.cancel();
    _gpsRetryTimer = Timer(_gpsRetryDelay, () {
      if (isClosed || !_isTracking || _isStopping) return;
      _subscribeToLocation(activityType);
    });
  }

  void _onPauseTracking(PauseTracking event, Emitter<ActivityTrackingState> emit) {
    final s = state;
    if (s is! TrackingInProgress || _isStopping) return;

    _activeClock.stop();
    _rawStepsAtPause = _lastRawSteps;
    _timer?.cancel();

    final elapsed = _activeClock.elapsed;
    final paused = TrackingPaused(
      activityType: s.activityType,
      elapsed: elapsed,
      distanceMeters: s.distanceMeters,
      avgPaceSecondsPerKm: s.avgPaceSecondsPerKm,
      calories: _calculateCalories(s.activityType, elapsed, s.distanceMeters),
      steps: s.steps,
      stepCountReliable: s.stepCountReliable,
      routePoints: s.routePoints,
      elevationGainMeters: s.elevationGainMeters,
      currentSpeedMps: 0.0,
    );
    emit(paused);

    ForegroundServiceManager.update(
      'Paused\nDistance: ${(s.distanceMeters / 1000).toStringAsFixed(2)} km | Duration: ${_formatDuration(elapsed)}',
    );
    _checkpoint(paused);
  }

  void _onResumeTracking(ResumeTracking event, Emitter<ActivityTrackingState> emit) {
    final s = state;
    if (s is! TrackingPaused || _isStopping) return;

    _activeClock.start();
    _ignoredPausedSteps += _lastRawSteps - _rawStepsAtPause;
    // Distance walked while paused must not count, so the first fix after
    // resuming only re-anchors the route.
    _skipDistanceForNextPoint = true;
    _stationarySince = null;

    emit(TrackingInProgress(
      activityType: s.activityType,
      elapsed: s.elapsed,
      distanceMeters: s.distanceMeters,
      avgPaceSecondsPerKm: s.avgPaceSecondsPerKm,
      calories: s.calories,
      steps: s.steps,
      stepCountReliable: s.stepCountReliable,
      routePoints: s.routePoints,
      elevationGainMeters: s.elevationGainMeters,
    ));

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => add(TickTimer()));
  }

  Future<void> _onStopAndSaveTracking(StopAndSaveTracking event, Emitter<ActivityTrackingState> emit) async {
    final s = state;
    if ((s is! TrackingInProgress && s is! TrackingPaused) || _isStopping) return;
    _isStopping = true;

    try {
      _activeClock.stop();
      _sessionClock.stop();
      _timer?.cancel();
      _gpsRetryTimer?.cancel();
      await _locationSubscription?.cancel();
      _locationSubscription = null;
      await _stepSubscription?.cancel();
      _stepSubscription = null;

      final session = _buildSession(
        endTime: DateTime.now(),
        targetType: event.targetType,
        targetValue: event.targetValue,
        targetAchieved: event.targetAchieved,
      );

      try {
        await ForegroundServiceManager.stop();
      } catch (e) {
        debugPrint('Foreground service failed to stop: $e');
      }

      // A checkpoint may still be writing; let it land first so it can't
      // overwrite the final session with endTime = null.
      await _pendingSave;

      var saved = true;
      try {
        await stopAndSaveSession(session);
      } catch (e) {
        saved = false;
        debugPrint('Saving activity session failed: $e');
      }

      emit(TrackingCompleted(
        activityType: s.activityType,
        session: session,
        elevationGainMeters: _elevationGain,
        saved: saved,
      ));
    } finally {
      _isStopping = false;
    }
  }

  void _onTickTimer(TickTimer event, Emitter<ActivityTrackingState> emit) {
    final s = state;
    if (s is! TrackingInProgress || _isStopping) return;

    final elapsed = _activeClock.elapsed;
    final calories = _calculateCalories(s.activityType, elapsed, s.distanceMeters);
    final pace = _calculateOverallPace(elapsed, s.distanceMeters);

    final lastFixAt = _lastFixAt;
    final fixIsStale = lastFixAt == null ||
        _sessionClock.elapsed - lastFixAt > _speedStaleAfter;

    final next = TrackingInProgress(
      activityType: s.activityType,
      elapsed: elapsed,
      distanceMeters: s.distanceMeters,
      avgPaceSecondsPerKm: pace,
      calories: calories,
      steps: s.steps,
      stepCountReliable: s.stepCountReliable && _stepCountReliable,
      routePoints: s.routePoints,
      elevationGainMeters: s.elevationGainMeters,
      currentSpeedMps: fixIsStale ? 0.0 : s.currentSpeedMps,
    );
    emit(next);

    ForegroundServiceManager.update(
      'Distance: ${(s.distanceMeters / 1000).toStringAsFixed(2)} km\nDuration: ${_formatDuration(elapsed)}',
    );

    if (_sessionClock.elapsed - _lastCheckpointAt >= _checkpointInterval) {
      _checkpoint(next);
    }
  }

  void _onUpdateTrackPoint(UpdateTrackPoint event, Emitter<ActivityTrackingState> emit) {
    final s = state;
    if (s is! TrackingInProgress || _isStopping) return;

    final point = event.point;
    final points = [...s.routePoints];
    final previous = points.isNotEmpty ? points.last : null;
    double distance = s.distanceMeters;

    // Fixes can arrive out of order after a GPS stream restart.
    if (previous != null && !point.timestamp.isAfter(previous.timestamp)) {
      return;
    }

    final segmentDistance =
        previous != null ? haversineMeters(previous, point) : 0.0;
    if (previous != null &&
        !_skipDistanceForNextPoint &&
        _isPlausibleSegment(s.activityType, previous, point, segmentDistance)) {
      distance += segmentDistance;
    }
    _skipDistanceForNextPoint = false;
    points.add(point);
    _lastFixAt = _sessionClock.elapsed;
    _updateStationaryState(point, segmentDistance);
    _updateElevation(point);

    final elapsed = _activeClock.elapsed;
    final pace = _calculateOverallPace(elapsed, distance);
    final calories = _calculateCalories(s.activityType, elapsed, distance);

    emit(TrackingInProgress(
      activityType: s.activityType,
      elapsed: elapsed,
      distanceMeters: distance,
      avgPaceSecondsPerKm: pace,
      calories: calories,
      steps: s.steps,
      stepCountReliable: s.stepCountReliable,
      routePoints: points,
      elevationGainMeters: _elevationGain,
      currentSpeedMps: point.speed,
    ));

    ForegroundServiceManager.update(
      'Distance: ${(distance / 1000).toStringAsFixed(2)} km\nDuration: ${_formatDuration(elapsed)}',
    );
  }

  /// Final guard on the distance itself. The repository's filter covers
  /// one continuous stream, but after a GPS restart or a long gap the first
  /// new fix is compared against nothing — a cold-start fix hundreds of
  /// meters off must not be added as distance.
  bool _isPlausibleSegment(
    ActivityType type,
    TrackPoint from,
    TrackPoint to,
    double meters,
  ) {
    final seconds = to.timestamp.difference(from.timestamp).inMilliseconds / 1000.0;
    if (seconds <= 0) return false;
    return meters / seconds <= type.maxReasonableSpeedMetersPerSecond * 2;
  }

  void _onUpdateSteps(UpdateSteps event, Emitter<ActivityTrackingState> emit) {
    _lastRawSteps = event.steps;

    final s = state;
    if (s is! TrackingInProgress || _isStopping) return;

    final previousSteps = _currentSteps;
    _currentSteps = (event.steps - _ignoredPausedSteps).clamp(0, 1 << 31).toInt();
    _stepCountReliable = s.stepCountReliable &&
        _isStepCountStillReliable(
          state: s,
          previousSteps: previousSteps,
          currentSteps: _currentSteps,
        );

    emit(TrackingInProgress(
      activityType: s.activityType,
      elapsed: s.elapsed,
      distanceMeters: s.distanceMeters,
      avgPaceSecondsPerKm: s.avgPaceSecondsPerKm,
      calories: s.calories,
      steps: _currentSteps,
      stepCountReliable: _stepCountReliable,
      routePoints: s.routePoints,
      elevationGainMeters: s.elevationGainMeters,
      currentSpeedMps: s.currentSpeedMps,
    ));
  }

  void _onPersistProgress(PersistProgress event, Emitter<ActivityTrackingState> emit) {
    final s = state;
    if (s is TrackingInProgress || s is TrackingPaused) _checkpoint(s);
  }

  bool _isStepCountStillReliable({
    required TrackingInProgress state,
    required int previousSteps,
    required int currentSteps,
  }) {
    final elapsedSeconds = _activeClock.elapsed.inSeconds;
    // Too early to judge cadence: a handful of steps in the first seconds
    // reads as an absurd steps-per-minute figure.
    if (elapsedSeconds < 30) return true;

    final cadence = currentSteps / (elapsedSeconds / 60.0);
    if (cadence > 220) return false;

    final stepsAdded = currentSteps - previousSteps;
    final stationaryFor = _stationarySince == null
        ? Duration.zero
        : DateTime.now().difference(_stationarySince!);
    if (stepsAdded > 0 && stationaryFor.inSeconds >= 60) {
      return false;
    }

    return true;
  }

  void _updateStationaryState(TrackPoint point, double segmentDistance) {
    final isStationary = point.speed < 0.4 && segmentDistance < 1.5;
    if (isStationary) {
      _stationarySince ??= DateTime.now();
    } else {
      _stationarySince = null;
    }
  }

  /// Hysteresis climb counter: altitude must rise [_elevationThresholdMeters]
  /// above the reference to count, and the reference only follows descents
  /// of the same size, so ±2 m jitter around a flat road adds nothing.
  void _updateElevation(TrackPoint point) {
    final altitude = point.altitude;
    if (!altitude.isFinite || altitude == 0.0) return; // 0 = no altitude fix
    final reference = _elevationReference;
    if (reference == null) {
      _elevationReference = altitude;
      return;
    }
    final delta = altitude - reference;
    if (delta >= _elevationThresholdMeters) {
      _elevationGain += delta;
      _elevationReference = altitude;
    } else if (delta <= -_elevationThresholdMeters) {
      _elevationReference = altitude;
    }
  }

  /// Calculates calories burned using a MET×weight×time + distance-correction blend.
  ///
  /// Strategy (mirrors Adidas Running app approach):
  ///   1. Duration-only MET estimate: `MET × weight(kg) × hours`
  ///   2. Distance-based estimate:    `kcalPerKgPerKm × weight(kg) × distance(km)`
  ///   3. We blend them:  when distance < 10 m use pure MET;
  ///      otherwise return the average of both to smooth out GPS noise.
  int _calculateCalories(
    ActivityType type,
    Duration elapsed,
    double distanceMeters,
  ) {
    final weightKg = _cachedWeightKg;
    final hours = elapsed.inSeconds / 3600.0;
    final metCalories = type.met * weightKg * hours;

    if (distanceMeters < 10.0) {
      return metCalories.round();
    }

    final distanceKm = distanceMeters / 1000.0;
    final distanceCalories = type.kcalPerKgPerKm * weightKg * distanceKm;

    // Blend: 50% MET-based, 50% distance-based for best overall accuracy.
    return ((metCalories + distanceCalories) / 2).round();
  }

  int _calculateOverallPace(Duration elapsed, double distanceMeters) {
    if (elapsed.inSeconds <= 0 || distanceMeters < _minDistanceForPaceMeters) return 0;

    final distanceKm = distanceMeters / 1000.0;
    return (elapsed.inSeconds / distanceKm).round();
  }

  ActivitySession _buildSession({
    required DateTime? endTime,
    String? targetType,
    double? targetValue,
    bool targetAchieved = false,
  }) {
    final s = state;
    final elapsed = _activeClock.elapsed;
    final distance = switch (s) {
      TrackingInProgress() => s.distanceMeters,
      TrackingPaused() => s.distanceMeters,
      _ => 0.0,
    };
    final steps = switch (s) {
      TrackingInProgress() => s.steps,
      TrackingPaused() => s.steps,
      _ => 0,
    };
    final reliable = switch (s) {
      TrackingInProgress() => s.stepCountReliable,
      TrackingPaused() => s.stepCountReliable,
      _ => false,
    };
    final points = switch (s) {
      TrackingInProgress() => s.routePoints,
      TrackingPaused() => s.routePoints,
      _ => const <TrackPoint>[],
    };

    return ActivitySession(
      id: _currentSessionId ??= const Uuid().v4(),
      activityType: s.activityType,
      startTime: _startedAt ?? DateTime.now(),
      endTime: endTime,
      totalDistanceMeters: distance,
      totalDurationSeconds: elapsed.inSeconds,
      avgPaceSecondsPerKm: _calculateOverallPace(elapsed, distance),
      calories: _calculateCalories(s.activityType, elapsed, distance),
      steps: steps,
      stepCountReliable: reliable && _stepCountReliable,
      points: points,
      targetType: targetType,
      targetValue: targetValue,
      targetAchieved: targetAchieved,
    );
  }

  /// Saves the running workout with no end time. Writes are chained so
  /// they land in order and the final save can wait for them.
  void _checkpoint(ActivityTrackingState s) {
    if (_isStopping || _currentSessionId == null) return;
    _lastCheckpointAt = _sessionClock.elapsed;
    final session = _buildSession(endTime: null);
    _pendingSave = _pendingSave.then((_) async {
      try {
        await stopAndSaveSession(session);
      } catch (e) {
        debugPrint('Activity checkpoint failed: $e');
      }
    });
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  void _onResetTracking(ResetTracking event, Emitter<ActivityTrackingState> emit) {
    if (_isTracking || _isStopping) return;
    final activityType = state.activityType;
    _currentSessionId = null;
    _startedAt = null;
    _activeClock
      ..stop()
      ..reset();
    _sessionClock
      ..stop()
      ..reset();
    _lastFixAt = null;
    _currentSteps = 0;
    _lastRawSteps = 0;
    _rawStepsAtPause = 0;
    _ignoredPausedSteps = 0;
    _stepCountReliable = true;
    _skipDistanceForNextPoint = false;
    _stationarySince = null;
    _elevationGain = 0.0;
    _elevationReference = null;
    _lastCheckpointAt = Duration.zero;
    emit(TrackingIdle(activityType: activityType));
  }

  @override
  Future<void> close() async {
    _timer?.cancel();
    _gpsRetryTimer?.cancel();
    await _locationSubscription?.cancel();
    await _stepSubscription?.cancel();
    if (_isTracking) {
      // Leaving mid-workout (e.g. the route is torn down): keep what was
      // recorded and release the foreground service.
      _checkpoint(state);
      await ForegroundServiceManager.stop();
    }
    await _pendingSave;
    return super.close();
  }
}
