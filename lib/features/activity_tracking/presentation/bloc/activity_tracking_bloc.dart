import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:vital_up/features/activity_tracking/data/repositories/location_tracking_repository_impl.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_session.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/track_point.dart';
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

  StreamSubscription<TrackPoint>? _locationSubscription;
  StreamSubscription<int>? _stepSubscription;
  Timer? _timer;

  String? _currentSessionId;
  DateTime? _startedAt;
  DateTime? _pauseStartedAt;
  Duration _pausedDuration = Duration.zero;
  int _currentSteps = 0;
  int _lastRawSteps = 0;
  int _rawStepsAtPause = 0;
  int _ignoredPausedSteps = 0;
  bool _stepCountReliable = true;
  bool _skipDistanceForNextPoint = false;

  /// User weight cached at session start to avoid hitting the DB on every tick.
  double _cachedWeightKg = 70.0;

  DateTime? _lastSavedAt;
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
  }

  void _onSelectActivityType(SelectActivityType event, Emitter<ActivityTrackingState> emit) {
    if (state is! TrackingIdle) return;
    emit(TrackingIdle(activityType: event.activityType));
  }

  Future<void> _onStartTracking(StartTracking event, Emitter<ActivityTrackingState> emit) async {
    if (state is! TrackingIdle) return;

    final hasPermission = await getLiveLocationStream.ensurePermission();
    if (!hasPermission) {
      emit(const TrackingPermissionDenied('Location permission is required for tracking.'));
      return;
    }

    _currentSessionId = const Uuid().v4();
    _startedAt = DateTime.now();
    _pauseStartedAt = null;
    _pausedDuration = Duration.zero;
    _currentSteps = 0;
    _lastRawSteps = 0;
    _rawStepsAtPause = 0;
    _ignoredPausedSteps = 0;
    _stepCountReliable = true;
    _skipDistanceForNextPoint = false;
    _stationarySince = null;
    _lastSavedAt = DateTime.now();

    // Cache user weight once per session — avoids async DB hit on every tick.
    final userResult = await authRepository.getCurrentUser();
    _cachedWeightKg = userResult.fold(
      (failure) => 70.0,
      (user) => user?.weightKg ?? 70.0,
    );

    final activityType = state.activityType;

    emit(TrackingInProgress(
      activityType: activityType,
      elapsed: Duration.zero,
      distanceMeters: 0.0,
      avgPaceSecondsPerKm: 0,
      calories: 0,
      steps: 0,
      stepCountReliable: true,
      routePoints: const [],
    ));

    // Start Foreground Service
    await ForegroundServiceManager.start(activityName: activityType.label);

    // Subscriptions
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => add(TickTimer()));

    await _locationSubscription?.cancel();
    _locationSubscription = getLiveLocationStream(activityType).listen(
      (point) => add(UpdateTrackPoint(point)),
    );

    await _stepSubscription?.cancel();
    _stepSubscription = getLiveStepsStream().listen(
      (steps) => add(UpdateSteps(steps)),
    );
  }

  void _onPauseTracking(PauseTracking event, Emitter<ActivityTrackingState> emit) {
    final s = state;
    if (s is! TrackingInProgress) return;

    _pauseStartedAt = DateTime.now();
    _rawStepsAtPause = _lastRawSteps;
    _timer?.cancel();

    emit(TrackingPaused(
      activityType: s.activityType,
      elapsed: s.elapsed,
      distanceMeters: s.distanceMeters,
      avgPaceSecondsPerKm: s.avgPaceSecondsPerKm,
      calories: s.calories,
      steps: s.steps,
      stepCountReliable: s.stepCountReliable,
      routePoints: s.routePoints,
    ));

    ForegroundServiceManager.update(
      'Paused\nDistance: ${(s.distanceMeters / 1000).toStringAsFixed(2)} km | Duration: ${_formatDuration(s.elapsed)}',
    );
  }

  void _onResumeTracking(ResumeTracking event, Emitter<ActivityTrackingState> emit) {
    final s = state;
    if (s is! TrackingPaused) return;

    final pausedAt = _pauseStartedAt;
    if (pausedAt != null) {
      _pausedDuration += DateTime.now().difference(pausedAt);
    }
    _ignoredPausedSteps += _lastRawSteps - _rawStepsAtPause;
    _pauseStartedAt = null;
    _skipDistanceForNextPoint = true;

    emit(TrackingInProgress(
      activityType: s.activityType,
      elapsed: s.elapsed,
      distanceMeters: s.distanceMeters,
      avgPaceSecondsPerKm: s.avgPaceSecondsPerKm,
      calories: s.calories,
      steps: s.steps,
      stepCountReliable: s.stepCountReliable,
      routePoints: s.routePoints,
    ));

    _timer = Timer.periodic(const Duration(seconds: 1), (_) => add(TickTimer()));
  }

  Future<void> _onStopAndSaveTracking(StopAndSaveTracking event, Emitter<ActivityTrackingState> emit) async {
    final s = state;
    if (s is! TrackingInProgress && s is! TrackingPaused) return;

    _timer?.cancel();
    _locationSubscription?.cancel();
    _stepSubscription?.cancel();

    await ForegroundServiceManager.stop();

    Duration elapsed = Duration.zero;
    double distance = 0.0;
    int pace = 0;
    int calories = 0;
    int steps = 0;
    List<TrackPoint> points = const [];

    if (s is TrackingInProgress) {
      elapsed = s.elapsed;
      distance = s.distanceMeters;
      pace = s.avgPaceSecondsPerKm;
      calories = s.calories;
      steps = s.steps;
      _stepCountReliable = s.stepCountReliable;
      points = s.routePoints;
    } else if (s is TrackingPaused) {
      elapsed = s.elapsed;
      distance = s.distanceMeters;
      pace = s.avgPaceSecondsPerKm;
      calories = s.calories;
      steps = s.steps;
      _stepCountReliable = s.stepCountReliable;
      points = s.routePoints;
    }

    final session = ActivitySession(
      id: _currentSessionId ?? const Uuid().v4(),
      activityType: s.activityType,
      startTime: _startedAt ?? DateTime.now(),
      endTime: DateTime.now(),
      totalDistanceMeters: distance,
      totalDurationSeconds: elapsed.inSeconds,
      avgPaceSecondsPerKm: pace,
      calories: calories,
      steps: steps,
      stepCountReliable: _stepCountReliable,
      points: points,
      targetType: event.targetType,
      targetValue: event.targetValue,
      targetAchieved: event.targetAchieved,
    );

    await stopAndSaveSession(session);

    emit(TrackingCompleted(
      activityType: s.activityType,
      session: session,
    ));
  }

  Future<void> _onTickTimer(TickTimer event, Emitter<ActivityTrackingState> emit) async {
    final s = state;
    if (s is! TrackingInProgress) return;

    final start = _startedAt;
    if (start == null) return;

    final elapsed = DateTime.now().difference(start) - _pausedDuration;
    final calories = _calculateCalories(s.activityType, elapsed, s.distanceMeters);
    
    emit(TrackingInProgress(
      activityType: s.activityType,
      elapsed: elapsed,
      distanceMeters: s.distanceMeters,
      avgPaceSecondsPerKm: s.avgPaceSecondsPerKm,
      calories: calories,
      steps: s.steps,
      stepCountReliable: s.stepCountReliable,
      routePoints: s.routePoints,
    ));

    ForegroundServiceManager.update(
      'Distance: ${(s.distanceMeters / 1000).toStringAsFixed(2)} km\nDuration: ${_formatDuration(elapsed)}',
    );

    final lastSaved = _lastSavedAt;
    if (lastSaved != null && DateTime.now().difference(lastSaved).inSeconds >= 30) {
      _lastSavedAt = DateTime.now();
      _saveProgressPeriodically(s, elapsed, calories);
    }
  }

  Future<void> _onUpdateTrackPoint(UpdateTrackPoint event, Emitter<ActivityTrackingState> emit) async {
    final s = state;
    if (s is! TrackingInProgress) return;

    final points = [...s.routePoints];
    double distance = s.distanceMeters;

    final segmentDistance = points.isNotEmpty
        ? haversineMeters(points.last, event.point)
        : 0.0;
    if (points.isNotEmpty && !_skipDistanceForNextPoint) {
      distance += segmentDistance;
    }
    _skipDistanceForNextPoint = false;
    points.add(event.point);
    _updateStationaryState(event.point, segmentDistance);

    final pace = _calculateOverallPace(s.elapsed, distance);
    final calories = _calculateCalories(s.activityType, s.elapsed, distance);

    emit(TrackingInProgress(
      activityType: s.activityType,
      elapsed: s.elapsed,
      distanceMeters: distance,
      avgPaceSecondsPerKm: pace,
      calories: calories,
      steps: s.steps,
      stepCountReliable: s.stepCountReliable,
      routePoints: points,
    ));

    ForegroundServiceManager.update(
      'Distance: ${(distance / 1000).toStringAsFixed(2)} km\nDuration: ${_formatDuration(s.elapsed)}',
    );
  }

  void _onUpdateSteps(UpdateSteps event, Emitter<ActivityTrackingState> emit) {
    _lastRawSteps = event.steps;

    final paused = state is TrackingPaused;
    if (paused) {
      return;
    }

    final s = state;
    if (s is! TrackingInProgress) return;

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
    ));
  }

  bool _isStepCountStillReliable({
    required TrackingInProgress state,
    required int previousSteps,
    required int currentSteps,
  }) {
    final elapsedSeconds = state.elapsed.inSeconds;
    if (elapsedSeconds <= 0) return true;

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
      _stationarySince ??= point.timestamp;
    } else {
      _stationarySince = null;
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
    if (elapsed.inSeconds <= 0 || distanceMeters < 1.0) return 0;
    
    final distanceKm = distanceMeters / 1000.0;
    return (elapsed.inSeconds / distanceKm).round();
  }

  Future<void> _saveProgressPeriodically(TrackingInProgress s, Duration elapsed, int calories) async {
    final session = ActivitySession(
      id: _currentSessionId ?? const Uuid().v4(),
      activityType: s.activityType,
      startTime: _startedAt ?? DateTime.now(),
      endTime: null,
      totalDistanceMeters: s.distanceMeters,
      totalDurationSeconds: elapsed.inSeconds,
      avgPaceSecondsPerKm: s.avgPaceSecondsPerKm,
      calories: calories,
      steps: s.steps,
      stepCountReliable: s.stepCountReliable,
      points: s.routePoints,
    );
    await stopAndSaveSession(session);
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  void _onResetTracking(ResetTracking event, Emitter<ActivityTrackingState> emit) {
    _currentSessionId = null;
    _startedAt = null;
    _pauseStartedAt = null;
    _pausedDuration = Duration.zero;
    _currentSteps = 0;
    _lastRawSteps = 0;
    _rawStepsAtPause = 0;
    _ignoredPausedSteps = 0;
    _stepCountReliable = true;
    _skipDistanceForNextPoint = false;
    _stationarySince = null;
    _lastSavedAt = null;
    emit(const TrackingIdle());
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    _locationSubscription?.cancel();
    _stepSubscription?.cancel();
    return super.close();
  }
}
