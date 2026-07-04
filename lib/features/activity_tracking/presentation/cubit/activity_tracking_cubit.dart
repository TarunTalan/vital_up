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

    emit(ActivityTrackingState.initial().copyWith(
      status: TrackingStatus.inProgress,
      activityType: state.activityType,
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

    final points = [...state.routePoints];
    double distance = state.distanceMeters;

    if (points.isNotEmpty) {
      distance += haversineMeters(points.last, point);
    }
    points.add(point);

    emit(state.copyWith(
      routePoints: points,
      distanceMeters: distance,
      currentSpeedMetersPerSecond: point.speed,
      calories: _calculateCalories(state.elapsed),
      avgPaceSecondsPerKm: _calculatePaceSecondsPerKm(distance, state.elapsed),
      steps: _baselineSteps,
    ));
  }

  int _calculateCalories(Duration elapsed) {
    const weightKg = 70.0;
    final hours = elapsed.inSeconds / 3600.0;
    return (state.activityType.met * weightKg * hours).round();
  }

  int _calculatePaceSecondsPerKm(double distanceMeters, Duration elapsed) {
    if (distanceMeters < 1 || elapsed.inSeconds <= 0) return 0;
    final km = distanceMeters / 1000.0;
    return (elapsed.inSeconds / km).round();
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    _locationSubscription?.cancel();
    _stepSubscription?.cancel();
    return super.close();
  }
}
