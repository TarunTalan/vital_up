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

class ActivityTrackingBloc extends Bloc<ActivityTrackingEvent, ActivityTrackingState> {
  final GetLiveLocationStream getLiveLocationStream;
  final GetLiveStepsStream getLiveStepsStream;
  final StopAndSaveSession stopAndSaveSession;

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

  DateTime? _lastSavedAt;
  DateTime? _stationarySince;

  ActivityTrackingBloc({
    required this.getLiveLocationStream,
    required this.getLiveStepsStream,
    required this.stopAndSaveSession,
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
    );

    await stopAndSaveSession(session);

    emit(TrackingCompleted(
      activityType: s.activityType,
      session: session,
    ));
  }

  void _onTickTimer(TickTimer event, Emitter<ActivityTrackingState> emit) {
    final s = state;
    if (s is! TrackingInProgress) return;

    final start = _startedAt;
    if (start == null) return;

    final elapsed = DateTime.now().difference(start) - _pausedDuration;
    final calories = _calculateCalories(s.activityType, elapsed);
    
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

  void _onUpdateTrackPoint(UpdateTrackPoint event, Emitter<ActivityTrackingState> emit) {
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

    final pace = _calculateRollingPace(points);

    emit(TrackingInProgress(
      activityType: s.activityType,
      elapsed: s.elapsed,
      distanceMeters: distance,
      avgPaceSecondsPerKm: pace,
      calories: s.calories,
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

  int _calculateCalories(ActivityType type, Duration elapsed) {
    const weightKg = 70.0;
    final hours = elapsed.inSeconds / 3600.0;
    return (type.met * weightKg * hours).round();
  }

  int _calculateRollingPace(List<TrackPoint> points) {
    if (points.length < 2) return 0;

    final now = points.last.timestamp;
    final threshold = now.subtract(const Duration(seconds: 30));
    final recentPoints = points.where((p) => p.timestamp.isAfter(threshold)).toList();

    if (recentPoints.length < 2) {
      return 0;
    }

    final first = recentPoints.first;
    final last = recentPoints.last;
    final durationSeconds = last.timestamp.difference(first.timestamp).inSeconds;
    if (durationSeconds <= 0) return 0;

    double dist = 0.0;
    for (int i = 0; i < recentPoints.length - 1; i++) {
      dist += haversineMeters(recentPoints[i], recentPoints[i + 1]);
    }

    if (dist < 1.0) return 0;
    final km = dist / 1000.0;
    return (durationSeconds / km).round();
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
