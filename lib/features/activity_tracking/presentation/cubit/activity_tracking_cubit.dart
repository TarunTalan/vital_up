import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/features/activity_tracking/data/repositories/location_tracking_repository_impl.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/track_point.dart';
import 'package:vital_up/features/activity_tracking/domain/usecases/get_live_location_stream.dart';
import 'package:vital_up/features/activity_tracking/domain/usecases/get_live_steps_stream.dart';
import 'package:vital_up/features/activity_tracking/presentation/cubit/activity_tracking_state.dart';

class ActivityTrackingCubit extends Cubit<ActivityTrackingState> {
  final GetLiveLocationStream getLiveLocationStream;
  final GetLiveStepsStream getLiveStepsStream;

  StreamSubscription<TrackPoint>? _locationSubscription;
  StreamSubscription<int>? _stepSubscription;
  Timer? _timer;
  DateTime? _startedAt;
  DateTime? _pauseStartedAt;
  Duration _pausedDuration = Duration.zero;
  int _baselineSteps = 0;
  final List<TrackPoint> _recentTrackPoints = [];
  DateTime? _lastMovementTime;
  static const Duration _pauseDetectionThreshold = Duration(seconds: 30);

  ActivityTrackingCubit({
    required this.getLiveLocationStream,
    required this.getLiveStepsStream,
  }) : super(ActivityTrackingState.initial());

  void selectActivityType(ActivityType type) {
    if (state.isActive) return;
    emit(state.copyWith(activityType: type));
  }

  Future<void> start() async {
    if (state.isActive) return;

    emit(state.copyWith(status: TrackingStatus.starting));
    final hasPermission = await getLiveLocationStream.ensurePermission();
    if (!hasPermission) {
      emit(state.copyWith(
        status: TrackingStatus.permissionDenied,
        message: 'Location permission is required to track activity.',
      ));
      return;
    }

    _startedAt = DateTime.now();
    _pauseStartedAt = null;
    _pausedDuration = Duration.zero;
    _baselineSteps = 0;
    _recentTrackPoints.clear();
    _lastMovementTime = DateTime.now();

    emit(ActivityTrackingState.initial().copyWith(
      status: TrackingStatus.inProgress,
      activityType: state.activityType,
      controlsLocked: true,
    ));

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());

    await _locationSubscription?.cancel();
    _locationSubscription =
        getLiveLocationStream(state.activityType).listen(_onTrackPoint);

    await _stepSubscription?.cancel();
    _stepSubscription = getLiveStepsStream().listen((steps) {
      _baselineSteps = steps;
      emit(state.copyWith(steps: steps));
    }, onError: (_) {});
  }

  void pause() {
    if (!state.isActive) return;
    _pauseStartedAt = DateTime.now();
    _timer?.cancel();
    emit(state.copyWith(status: TrackingStatus.paused));
  }

  void resume() {
    if (!state.isPaused) return;
    final pausedAt = _pauseStartedAt;
    if (pausedAt != null) {
      _pausedDuration += DateTime.now().difference(pausedAt);
    }
    _pauseStartedAt = null;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    emit(state.copyWith(status: TrackingStatus.inProgress));
  }

  void stop() {
    _timer?.cancel();
    _locationSubscription?.cancel();
    _stepSubscription?.cancel();
    emit(state.copyWith(status: TrackingStatus.completed));
  }

  void reset() {
    _timer?.cancel();
    _locationSubscription?.cancel();
    _stepSubscription?.cancel();
    emit(ActivityTrackingState.initial());
  }

  void toggleControlsLock() {
    emit(state.copyWith(controlsLocked: !state.controlsLocked));
  }

  void _tick() {
    final start = _startedAt;
    if (start == null || !state.isActive) return;

    final elapsed = DateTime.now().difference(start) - _pausedDuration;
    emit(state.copyWith(
      elapsed: elapsed,
      calories: _calculateCalories(elapsed),
      avgPaceSecondsPerKm: _calculatePaceSecondsPerKm(
        state.distanceMeters,
        elapsed,
      ),
    ));
  }

  void _onTrackPoint(TrackPoint point) {
    if (!state.isActive) return;

    // Detect if user is moving (speed > 0.3 m/s)
    if (point.speed > 0.3) {
      _lastMovementTime = point.timestamp;
    }

    // Auto-pause if no movement for threshold duration
    final lastMovement = _lastMovementTime;
    if (lastMovement != null && 
        point.timestamp.difference(lastMovement) > _pauseDetectionThreshold) {
      pause();
      return;
    }

    final points = [...state.routePoints];
    double distance = state.distanceMeters;

    if (points.isNotEmpty) {
      distance += haversineMeters(points.last, point);
    }
    points.add(point);

    // Add to recent track points for rolling pace calculation (last 30 seconds)
    _recentTrackPoints.add(point);
    final thirtySecondsAgo = point.timestamp.subtract(const Duration(seconds: 30));
    _recentTrackPoints.removeWhere((p) => p.timestamp.isBefore(thirtySecondsAgo));

    emit(state.copyWith(
      routePoints: points,
      distanceMeters: distance,
      currentSpeedMetersPerSecond: point.speed,
      calories: _calculateCalories(state.elapsed),
      avgPaceSecondsPerKm: _calculatePaceSecondsPerKm(distance, state.elapsed),
      currentPaceSecondsPerKm: _calculateRollingPaceSecondsPerKm(),
      steps: _baselineSteps,
    ));
  }

  int _calculateCalories(Duration elapsed) {
    const weightKg = 70.0;
    final hours = elapsed.inSeconds / 3600.0;
    
    // Dynamic MET based on current speed for more accurate calorie calculation
    double met = state.activityType.met;
    final speed = state.currentSpeedMetersPerSecond;
    
    if (speed > 0) {
      // Adjust MET based on speed relative to activity type
      switch (state.activityType) {
        case ActivityType.walk:
          // Walking: 3.8 MET at ~1.4 m/s, scales with speed
          met = 2.0 + (speed * 1.3);
          break;
        case ActivityType.run:
          // Running: 9.8 MET at ~3.3 m/s, scales with speed
          met = 5.0 + (speed * 1.5);
          break;
        case ActivityType.cycle:
          // Cycling: 7.5 MET at ~5.6 m/s, scales with speed
          met = 4.0 + (speed * 0.6);
          break;
      }
      // Clamp MET to reasonable range
      met = met.clamp(2.0, 18.0);
    }
    
    return (met * weightKg * hours).round();
  }

  int _calculatePaceSecondsPerKm(double distanceMeters, Duration elapsed) {
    if (distanceMeters < 1 || elapsed.inSeconds <= 0) return 0;
    final km = distanceMeters / 1000.0;
    return (elapsed.inSeconds / km).round();
  }

  int _calculateRollingPaceSecondsPerKm() {
    if (_recentTrackPoints.length < 2) return 0;
    
    final first = _recentTrackPoints.first;
    final last = _recentTrackPoints.last;
    
    final elapsedSeconds = last.timestamp.difference(first.timestamp).inSeconds;
    if (elapsedSeconds <= 0) return 0;
    
    double distance = 0;
    for (int i = 1; i < _recentTrackPoints.length; i++) {
      distance += haversineMeters(_recentTrackPoints[i - 1], _recentTrackPoints[i]);
    }
    
    if (distance < 1) return 0;
    final km = distance / 1000.0;
    return (elapsedSeconds / km).round();
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    _locationSubscription?.cancel();
    _stepSubscription?.cancel();
    return super.close();
  }
}
