import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vital_up/core/permissions/permission_card.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart' hide ActivityType;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/preferences/distance_unit_notifier.dart';

import 'package:vital_up/core/preferences/workout_prefs_notifier.dart';
import 'package:vital_up/features/activity_tracking/presentation/bloc/foreground_service_manager.dart';
import 'package:vital_up/features/activity_tracking/presentation/pages/workout_timer_page.dart';
import 'package:vital_up/features/activity_tracking/data/services/workout_recovery_service.dart';
import 'package:vital_up/features/activity_tracking/data/services/workout_timer_store.dart';
import 'package:vital_up/core/network/connectivity_service.dart';
import 'package:vital_up/features/activity_tracking/data/services/offline_map_service.dart';
import 'package:vital_up/features/activity_tracking/presentation/widgets/offline_map_note.dart';
import 'package:vital_up/core/widgets/feature_tip_card.dart';
import 'package:vital_up/features/feature_tips/presentation/feature_tip_keys.dart';
import 'package:vital_up/features/activity_tracking/domain/services/workout_checkpoint.dart';
import 'package:vital_up/features/activity_goals/domain/repositories/activity_goals_repository.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/domain/usecases/get_activity_history.dart';
import 'package:vital_up/features/dashboard/domain/entities/trend_series.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/track_point.dart';
import 'package:vital_up/features/activity_tracking/presentation/bloc/activity_tracking_bloc.dart';
import 'package:vital_up/features/activity_tracking/presentation/bloc/activity_tracking_event.dart';
import 'package:vital_up/features/activity_tracking/presentation/bloc/activity_tracking_state.dart';
import 'package:vital_up/features/activity_tracking/presentation/pages/activity_completion_page.dart';
import 'package:vital_up/features/activity_tracking/presentation/pages/activity_settings_page.dart';
import 'package:vital_up/features/activity_tracking/presentation/widgets/activity_tracking_common_widgets.dart';
import 'package:vital_up/features/activity_tracking/presentation/widgets/activity_tracking_controls.dart';
import 'package:vital_up/features/activity_tracking/presentation/widgets/activity_tracking_stats.dart';
import 'package:vital_up/features/activity_tracking/presentation/widgets/countdown_overlay.dart';
import 'package:vital_up/features/activity_tracking/presentation/widgets/hr_device_sheet.dart';
import 'package:vital_up/features/activity_tracking/presentation/widgets/interrupted_workout_dialog.dart';
import 'package:vital_up/features/activity_tracking/presentation/utils/activity_target_rules.dart';
import 'package:vital_up/features/activity_tracking/presentation/widgets/workout_music.dart';
import 'package:vital_up/features/activity_tracking/services/voice_coach_service.dart';

/// The one screen for every activity. Outdoor types use the GPS view (map,
/// location service, recovery); workouts without a route use the workout
/// timer, on the same screen: picking a type switches between them while
/// nothing is running. A workout being timed always opens the timer.
class ActivityTrackingPage extends StatelessWidget {
  /// Open on the workout timer with this type (the `workout-timer` route).
  final ActivityType? workout;

  const ActivityTrackingPage({super.key, this.workout});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ActivityTrackingBloc>(),
      child: _ActivityModes(workout: workout),
    );
  }
}

class _ActivityModes extends StatefulWidget {
  final ActivityType? workout;

  const _ActivityModes({this.workout});

  @override
  State<_ActivityModes> createState() => _ActivityModesState();
}

class _ActivityModesState extends State<_ActivityModes> {
  /// Non-null: the timer for this workout; null: the GPS view.
  ActivityType? _workout;

  /// The outdoor type picked on the timer, for the GPS view to open with.
  ActivityType? _outdoor;

  @override
  void initState() {
    super.initState();
    _workout = sl<WorkoutTimerStore>().read()?.type ?? widget.workout;
  }

  @override
  Widget build(BuildContext context) {
    final workout = _workout;
    if (workout != null) {
      return WorkoutTimerPage(
        key: const ValueKey('timer'),
        type: workout,
        onOutdoorSelected: (type) => setState(() {
          _workout = null;
          _outdoor = type;
        }),
      );
    }
    return _ActivityTrackingView(
      key: const ValueKey('gps'),
      initialType: _outdoor,
      onWorkoutSelected: (type) => setState(() => _workout = type),
    );
  }
}

class _ActivityTrackingView extends StatefulWidget {
  /// Picked on the timer before switching here; wins over the goal's pick.
  final ActivityType? initialType;

  /// A workout without a route was picked: the page shows the timer.
  final ValueChanged<ActivityType> onWorkoutSelected;

  const _ActivityTrackingView({
    super.key,
    this.initialType,
    required this.onWorkoutSelected,
  });

  @override
  State<_ActivityTrackingView> createState() => _ActivityTrackingViewState();
}

class _ActivityTrackingViewState extends State<_ActivityTrackingView> {
  bool _offlineMapChecked = false;
  bool _isUiVisible = true;
  bool _isLocked = true;
  bool _isCountingDown = false;
  bool _hasCenteredCamera = false;

  /// Whether the "GPS signal lost" message is showing for this outage, so
  /// it is shown once per outage rather than on every tick.
  bool _gpsLostNotified = false;

  final DistanceUnitNotifier _unitNotifier = DistanceUnitNotifier();
  final WorkoutPrefsNotifier _prefsNotifier = WorkoutPrefsNotifier();
  final VoiceCoachService _voiceCoach = sl<VoiceCoachService>();
  final HeartRateManager _hrManager = HeartRateManager();
  int? _liveHeartRate;
  StreamSubscription<int?>? _hrSubscription;
  late final WorkoutMusic _music = WorkoutMusic(
    _prefsNotifier,
    onError: (message) {
      if (mounted) showErrorSnackBar(context, message);
    },
  );

  mbx.MapboxMap? _mapboxMap;
  mbx.PolylineAnnotationManager? _polylineAnnotationManager;
  mbx.CircleAnnotationManager? _circleAnnotationManager;
  mbx.CircleAnnotationManager? _startPointAnnotationManager;

  TrackPoint? _currentPosition;
  TrackPoint? _startPoint;

  /// The drawn route and puck, updated in place: re-creating them sent the
  /// whole route over the platform channel on every tick.
  mbx.PolylineAnnotation? _routeLine;
  Future<void>? _routeCreating;
  int _drawnRouteLength = 0;
  mbx.CircleAnnotation? _puck;
  Future<void>? _puckCreating;

  /// No map calls while the app is hidden; [_onShown] redraws once.
  bool _appHidden = false;
  List<TrackPoint>? _hiddenRoute;
  TrackPoint? _hiddenPuck;

  /// Built once: the map must not be rebuilt by the per-second ticks.
  late final Widget _mapLayer = Positioned.fill(
    child: mbx.MapWidget(
      key: const ValueKey("mapWidget"),
      // The style in the offline pack. Left out, the widget first loads
      // the heavy Standard style (not saved offline) and then swaps.
      styleUri: mbx.MapboxStyles.MAPBOX_STREETS,
      onMapCreated: _onMapCreated,
      onTapListener: (context) {
        if (mounted) {
          setState(() {
            _isUiVisible = !_isUiVisible;
          });
        }
      },
    ),
  );

  /// Map-preview position feed while no workout is running. It must be
  /// cancelled before a workout starts: geolocator shares one native stream
  /// and would hand the workout this low-precision, foreground-only feed.
  StreamSubscription<Position>? _positionSubscription;
  late final AppLifecycleListener _lifecycleListener;

  /// Pause / Resume tapped on the workout notification.
  StreamSubscription<String>? _notificationButtons;

  /// Set once Start or Resume is tapped, so the map preview never
  /// subscribes while the workout's own GPS stream is starting.
  bool _workoutRequested = false;

  /// A choice about an interrupted workout is being carried out.
  bool _recoveryBusy = false;

  late final Future<void> _prefsLoaded;

  @override
  void initState() {
    super.initState();
    final picked = widget.initialType;
    if (picked != null) {
      _typePicked = true;
      context.read<ActivityTrackingBloc>().add(SelectActivityType(picked));
    }
    _unitNotifier.load();
    _prefsLoaded = _prefsNotifier.load().then((_) {
      _checkIfCurrentTrackFavorited();
    });
    _prefsNotifier.addListener(_onPrefsChanged);
    _voiceCoach.init();
    // The offline maps tip needs the saved areas read; Home's startup check
    // may not have run yet (opened from a shortcut or straight away).
    sl<OfflineMapService>().refresh();
    _hrSubscription = _hrManager.bpmStream.listen((bpm) {
      if (mounted) setState(() => _liveHeartRate = bpm);
    });
    _notificationButtons = ForegroundServiceManager.buttonPresses.listen(
      _onNotificationButton,
    );
    // Settle an interrupted workout first: its resume needs the GPS stream
    // and the location prompt to itself.
    _checkInterruptedWorkout().whenComplete(() {
      if (!mounted) return;
      _selectActivityForGoals();
      _loadGoalTarget();
      _startLocationUpdates();
      _askOnFirstOpen();
    });
    // Checkpoint the workout whenever the app leaves the foreground — the
    // OS may kill a backgrounded app without further notice.
    _lifecycleListener = AppLifecycleListener(
      onHide: () {
        _appHidden = true;
        if (mounted)
          context.read<ActivityTrackingBloc>().add(PersistProgress());
      },
      onShow: _onShown,
    );
  }

  void _onPrefsChanged() {
    if (mounted) _checkIfCurrentTrackFavorited();
  }

  /// A type was picked on this screen: the goal's pick doesn't override it.
  bool _typePicked = false;

  /// What's left of today's distance or calories goal, used as the target
  /// of a workout started without one set by hand.
  ({WorkoutTargetType type, double value})? _goalTarget;

  /// Opens with the activity the user's goals point to (steps: walk;
  /// distance or calories: run), else their last GPS activity.
  Future<void> _selectActivityForGoals() async {
    final goals = sl<ActivityGoalsRepository>().getGoals();
    ActivityType? last;
    try {
      final history = await sl<GetActivityHistory>()(
        since: DateTime.now().subtract(const Duration(days: 90)),
      );
      last = history
          .map((e) => e.session.activityType)
          .where((t) => t.isGpsBased)
          .firstOrNull;
    } catch (e) {
      debugPrint('Reading the last activity failed: $e');
    }
    if (!mounted || _typePicked) return;
    final bloc = context.read<ActivityTrackingBloc>();
    if (bloc.state is! TrackingIdle) return;
    bloc.add(SelectActivityType(activityForGoals(goals, lastOutdoor: last)));
  }

  Future<void> _loadGoalTarget() async {
    try {
      final snapshot = await sl<ActivityGoalsRepository>().getProgress(
        TrendRange.week,
      );
      if (mounted) _goalTarget = targetFromGoals(snapshot.goals);
    } catch (e) {
      debugPrint('Reading activity goals failed: $e');
    }
  }

  void _checkIfCurrentTrackFavorited() => _music.refreshFavorite();
  void _playWorkoutAudio() => _music.play();
  void _pauseWorkoutAudio() => _music.pause();
  void _resumeWorkoutAudio() => _music.resume();
  void _stopWorkoutAudio() => _music.stop();

  /// Pause / Resume, from the controls or the workout notification.
  void _pauseTracking() {
    final bloc = context.read<ActivityTrackingBloc>();
    if (bloc.state is! TrackingInProgress) return;
    bloc.add(PauseTracking());
    _pauseWorkoutAudio();
  }

  void _resumeTracking() {
    final bloc = context.read<ActivityTrackingBloc>();
    if (bloc.state is! TrackingPaused) return;
    bloc.add(ResumeTracking());
    if (_prefsNotifier.value.voiceCoachEnabled) {
      _voiceCoach.announceResume();
    }
    _resumeWorkoutAudio();
  }

  void _onNotificationButton(String id) {
    if (!mounted) return;
    if (id == ForegroundServiceManager.pauseButton) {
      _pauseTracking();
    } else if (id == ForegroundServiceManager.resumeButton) {
      _resumeTracking();
    }
  }

  @override
  void dispose() {
    _prefsNotifier.removeListener(_onPrefsChanged);

    // Reset selected track to None, stop playback, and reset TTS/voice coach on exit
    _prefsNotifier.setBackgroundAudioTrack('None');
    _stopWorkoutAudio();
    _voiceCoach.stop();

    _lifecycleListener.dispose();
    _positionSubscription?.cancel();
    _hrSubscription?.cancel();
    _notificationButtons?.cancel();
    _hrManager.dispose();
    _music.dispose();
    _unitNotifier.dispose();
    _prefsNotifier.dispose();
    super.dispose();
  }

  Future<void> _startLocationUpdates() async {
    if (_positionSubscription != null || _workoutRequested) return;
    LocationPermission permission;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      // Only checks: the card asks (first open, then Start).
      permission = await Geolocator.checkPermission();
    } catch (e) {
      // e.g. a permission request already in progress from the workout.
      debugPrint('Map preview location unavailable: $e');
      return;
    }
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      return;
    }
    // A workout may have started while we were awaiting permission.
    if (!mounted ||
        _positionSubscription != null ||
        _workoutRequested ||
        context.read<ActivityTrackingBloc>().state is! TrackingIdle) {
      return;
    }

    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen((position) {
          if (mounted) {
            final point = TrackPoint(
              latitude: position.latitude,
              longitude: position.longitude,
              timestamp: position.timestamp,
              accuracy: position.accuracy,
              speed: position.speed.isFinite ? position.speed : 0,
              altitude: position.altitude.isFinite ? position.altitude : 0,
            );
            setState(() {
              _currentPosition = point;
            });
            _updatePuck(point);
            _initialCenterCamera(position.latitude, position.longitude);
            _ensureOfflineMap(position.latitude, position.longitude);
          }
        }, onError: (Object e) => debugPrint('Map preview location error: $e'));
  }

  void _stopLocationUpdates() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  /// Location (needed), steps and notifications (asked with it when
  /// missing), with the permission card before the countdown starts.
  /// Location for the route, steps and the workout notification, asked
  /// with the permission card. [onceKey]: asked only once from there.
  static PermissionAsk _trackingAsk({String? onceKey}) => PermissionAsk(
    main: AppPermission.location,
    also: const [AppPermission.activity, AppPermission.notifications],
    alsoOnceKey: 'workout_extras',
    onceKey: onceKey,
    title: 'Map your workout',
    message:
        'VitalUp follows your route while you track, so your distance '
        'and pace are right.',
  );

  Future<bool> _allowTracking() async {
    final allowed = await ensurePermission(context, _trackingAsk());
    // Allowed just now: show where they are before the countdown ends.
    if (allowed && mounted) _startLocationUpdates();
    return allowed;
  }

  /// The first time the screen opens: the map is about where you are, so
  /// the card asks then rather than only at Start. Once only (declined, it
  /// waits for Start); after an interrupted workout's choice, which has
  /// the screen first.
  Future<void> _askOnFirstOpen() async {
    if (!mounted ||
        _workoutRequested ||
        context.read<ActivityTrackingBloc>().state is! TrackingIdle) {
      return;
    }
    final allowed = await ensurePermission(
      context,
      _trackingAsk(onceKey: 'workout_screen_open'),
    );
    if (allowed && mounted) _startLocationUpdates();
  }

  /// Starts the workout. Shared by the instant start and the countdown.
  void _beginTracking() {
    _workoutRequested = true;
    _stopLocationUpdates();
    // Today's goal is the target unless one was set by hand.
    final goal = _goalTarget;
    if (goal != null &&
        _prefsNotifier.value.targetType == WorkoutTargetType.none) {
      _prefsNotifier.setTarget(goal.type, goal.value);
    }
    context.read<ActivityTrackingBloc>().add(StartTracking());
    if (_prefsNotifier.value.voiceCoachEnabled) {
      _voiceCoach.announceStart();
    }
    _playWorkoutAudio();
  }

  /// Offers to carry on a workout the app was closed in the middle of. One
  /// too old to resume is saved to history as it was.
  Future<void> _checkInterruptedWorkout() async {
    final recovery = sl<WorkoutRecoveryService>();
    final InterruptedWorkout? workout;
    try {
      workout = await recovery.pending();
    } catch (e) {
      debugPrint('Reading the interrupted workout failed: $e');
      return;
    }
    if (workout == null || !mounted) return;
    if (context.read<ActivityTrackingBloc>().state is! TrackingIdle) return;

    if (workout.action == InterruptedWorkoutAction.saveOnly) {
      await _finishInterrupted(workout, announceOld: true);
      return;
    }

    final choice = await showSmoothDialog<InterruptedWorkoutChoice>(
      context: context,
      barrierDismissible: false,
      builder: (_) => InterruptedWorkoutDialog(
        session: workout!.session,
        unit: _unitNotifier.value,
      ),
    );
    if (!mounted || choice == null || _recoveryBusy) return;
    switch (choice) {
      case InterruptedWorkoutChoice.resume:
        // Without location it can't go on; the checkpoint stays.
        if (await _allowTracking() && mounted) _resumeInterrupted(workout);
      case InterruptedWorkoutChoice.save:
        await _finishInterrupted(workout);
      case InterruptedWorkoutChoice.discard:
        await _discardInterrupted(workout);
    }
  }

  void _resumeInterrupted(InterruptedWorkout workout) {
    final bloc = context.read<ActivityTrackingBloc>();
    if (bloc.state is! TrackingIdle) return;
    _workoutRequested = true;
    // geolocator has one native stream: the preview must let go of it
    // before the workout subscribes.
    _stopLocationUpdates();
    bloc.add(
      RestoreTracking(checkpoint: workout.checkpoint, session: workout.session),
    );
  }

  Future<void> _finishInterrupted(
    InterruptedWorkout workout, {
    bool announceOld = false,
  }) async {
    if (_recoveryBusy) return;
    _recoveryBusy = true;
    try {
      await _prefsLoaded;
      final prefs = _prefsNotifier.value;
      final hasTarget =
          prefs.targetType != WorkoutTargetType.none && prefs.targetValue > 0;
      final session = workout.session;
      final outcome = await sl<WorkoutRecoveryService>().finish(
        workout,
        targetType: hasTarget ? prefs.targetType.name : null,
        targetValue: hasTarget ? prefs.targetValue : null,
        targetAchieved:
            hasTarget &&
            isActivityTargetMet(
              prefs.targetType,
              prefs.targetValue,
              distanceMeters: session.totalDistanceMeters,
              calories: session.calories,
            ),
      );
      if (outcome != InterruptedWorkoutOutcome.failed) {
        await _prefsNotifier.clearSessionTarget();
      }
      if (!mounted) return;
      switch (outcome) {
        case InterruptedWorkoutOutcome.saved:
          showSuccessSnackBar(
            context,
            announceOld
                ? 'Your last workout was saved to history.'
                : 'Workout saved to your history.',
          );
        case InterruptedWorkoutOutcome.discarded:
          // An accidental start nobody needs to hear about later on.
          if (!announceOld) {
            showErrorSnackBar(context, 'Workout too short to save.');
          }
        case InterruptedWorkoutOutcome.failed:
          showErrorSnackBar(context, "Couldn't save your workout. Try again.");
      }
    } finally {
      _recoveryBusy = false;
    }
  }

  Future<void> _discardInterrupted(InterruptedWorkout workout) async {
    if (_recoveryBusy) return;
    _recoveryBusy = true;
    try {
      final ok = await sl<WorkoutRecoveryService>().discard(workout);
      if (ok) await _prefsNotifier.clearSessionTarget();
      if (!mounted) return;
      if (ok) {
        showSuccessSnackBar(context, 'Workout discarded.');
      } else {
        showErrorSnackBar(context, "Couldn't discard your workout. Try again.");
      }
    } finally {
      _recoveryBusy = false;
    }
  }

  /// Once, before a GPS workout, to users with no saved area: the moment
  /// someone plans a route is when offline maps make sense.
  Widget _offlineMapsTip() {
    final tips = featureTipsOrNull();
    if (tips == null || tips.isDismissed(FeatureTipKeys.offlineMaps)) {
      return const SizedBox.shrink();
    }
    return ValueListenableBuilder<OfflineMapsState>(
      valueListenable: sl<OfflineMapService>().state,
      builder: (context, maps, _) {
        if (!maps.loaded || maps.saved.isNotEmpty) {
          return const SizedBox.shrink();
        }
        void answer() {
          tips.dismiss(FeatureTipKeys.offlineMaps);
          if (mounted) setState(() {});
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: AppDimens.space8),
          child: FeatureTipCard(
            icon: Icons.download_for_offline_rounded,
            title: 'Going somewhere without signal?',
            message: 'Save the map before you go. Workouts record anywhere.',
            actionLabel: 'Offline maps',
            onAction: () {
              answer();
              context.pushNamed('offline-maps');
            },
            onDismiss: answer,
            overlay: true,
          ),
        );
      },
    );
  }

  /// The app downloads the offline map at start; this catches a user who
  /// has just allowed location or moved out of it since. Once per visit.
  void _ensureOfflineMap(double latitude, double longitude) {
    if (_offlineMapChecked) return;
    _offlineMapChecked = true;
    sl<OfflineMapService>().ensureAround(latitude, longitude);
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActivitySettingsPage(
          unitNotifier: _unitNotifier,
          prefsNotifier: _prefsNotifier,
          hrManager: _hrManager,
          liveHeartRate: _liveHeartRate,
        ),
      ),
    );
  }

  void _initialCenterCamera(double lat, double lng) {
    if (_hasCenteredCamera || _mapboxMap == null) return;
    _hasCenteredCamera = true;
    _centerCamera(lat, lng, zoom: 16.0);
  }

  void _onMapCreated(mbx.MapboxMap map) async {
    _mapboxMap = map;

    // Move compass to top right, at roughly 60% height of screen
    final screenHeight = MediaQuery.sizeOf(context).height;
    await map.compass.updateSettings(
      mbx.CompassSettings(
        position: mbx.OrnamentPosition.TOP_RIGHT,
        marginTop: screenHeight * 0.6,
        marginRight: AppDimens.gutter,
      ),
    );

    // Hide scale bar
    await map.scaleBar.updateSettings(mbx.ScaleBarSettings(enabled: false));

    // Create annotation managers
    _polylineAnnotationManager = await map.annotations
        .createPolylineAnnotationManager();
    _circleAnnotationManager = await map.annotations
        .createCircleAnnotationManager();
    _startPointAnnotationManager = await map.annotations
        .createCircleAnnotationManager();

    // Center camera immediately if we already have a position from the stream
    if (_currentPosition != null) {
      _initialCenterCamera(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
      _updatePuck(_currentPosition);
    }

    // Center camera on user's current location initially with appropriate zoom
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      _initialCenterCamera(position.latitude, position.longitude);

      // Update initial position puck
      final point = TrackPoint(
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: position.timestamp,
        accuracy: position.accuracy,
        speed: position.speed.isFinite ? position.speed : 0,
        altitude: position.altitude.isFinite ? position.altitude : 0,
      );
      if (!mounted) return;
      setState(() {
        _currentPosition = point;
      });
      _updatePuck(point);
    } catch (_) {}
  }

  void _onShown() {
    _appHidden = false;
    final route = _hiddenRoute;
    final puck = _hiddenPuck;
    _hiddenRoute = null;
    _hiddenPuck = null;
    if (route != null) _updateRoute(route);
    if (puck != null) _updatePuck(puck);
  }

  void _updateRoute(List<TrackPoint> points) {
    final manager = _polylineAnnotationManager;
    if (manager == null || points.length < 2 || !mounted) return;
    if (_appHidden) {
      _hiddenRoute = points;
      return;
    }
    // Ticks and step updates re-emit the same route.
    if (points.length == _drawnRouteLength) return;
    // A create still in flight: the next new point draws the latest route.
    if (_routeCreating != null) return;
    _drawnRouteLength = points.length;

    final geometry = mbx.LineString(
      coordinates: [
        for (final p in points) mbx.Position(p.longitude, p.latitude),
      ],
    );
    final line = _routeLine;
    if (line != null) {
      line.geometry = geometry;
      manager.update(line).ignore();
      return;
    }
    _routeCreating = manager
        .create(
          mbx.PolylineAnnotationOptions(
            geometry: geometry,
            lineColor: context.colors.primary.toARGB32(),
            lineWidth: ActivityMapDimens.routeWidth,
          ),
        )
        .then<void>((created) {
          _routeLine = created;
        })
        .catchError((Object e) {
          _drawnRouteLength = 0;
          debugPrint('Drawing the route failed: $e');
        })
        .whenComplete(() => _routeCreating = null);
  }

  void _updateStartPoint(TrackPoint? point) {
    if (_startPointAnnotationManager == null || point == null || !mounted)
      return;

    _startPointAnnotationManager!.deleteAll();

    _startPointAnnotationManager!.create(
      mbx.CircleAnnotationOptions(
        geometry: mbx.Point(
          coordinates: mbx.Position(point.longitude, point.latitude),
        ),
        circleRadius: ActivityMapDimens.startRadius,
        circleColor: ActivityColors.mapStartPoint.toARGB32(),
        circleStrokeWidth: ActivityMapDimens.startStroke,
        circleStrokeColor: ActivityColors.mapMarkerStroke.toARGB32(),
      ),
    );
  }

  void _updatePuck(TrackPoint? point) {
    final manager = _circleAnnotationManager;
    if (manager == null || point == null || !mounted) return;
    if (_appHidden) {
      _hiddenPuck = point;
      return;
    }
    final geometry = mbx.Point(
      coordinates: mbx.Position(point.longitude, point.latitude),
    );
    final puck = _puck;
    if (puck != null) {
      puck.geometry = geometry;
      manager.update(puck).ignore();
      return;
    }
    if (_puckCreating != null) return;
    _puckCreating = manager
        .create(
          mbx.CircleAnnotationOptions(
            geometry: geometry,
            circleRadius: ActivityMapDimens.puckRadius,
            circleColor: context.colors.primary.toARGB32(),
            circleStrokeWidth: ActivityMapDimens.puckStroke,
            circleStrokeColor: ActivityColors.mapMarkerStroke.toARGB32(),
          ),
        )
        .then<void>((created) {
          _puck = created;
          // A newer fix may have arrived while it was being created.
          final latest = _currentPosition;
          if (latest != null && !identical(latest, point)) {
            _updatePuck(latest);
          }
        })
        .catchError((Object e) => debugPrint('Drawing the position failed: $e'))
        .whenComplete(() => _puckCreating = null);
  }

  void _centerCamera(double lat, double lng, {double? zoom}) {
    _mapboxMap?.setCamera(
      mbx.CameraOptions(
        center: mbx.Point(coordinates: mbx.Position(lng, lat)),
        zoom: zoom,
      ),
    );
  }

  void _clearMapAnnotations() {
    _polylineAnnotationManager?.deleteAll();
    _circleAnnotationManager?.deleteAll();
    _startPointAnnotationManager?.deleteAll();
    _routeLine = null;
    _drawnRouteLength = 0;
    _puck = null;
    _hiddenRoute = null;
    setState(() {
      _startPoint = null;
    });
    _updatePuck(_currentPosition);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ActivityTrackingBloc, ActivityTrackingState>(
      listener: (context, state) {
        if (state is TrackingPermissionDenied) {
          // Audio and the start announcement began with the tap on Start.
          _stopWorkoutAudio();
          _voiceCoach.stop();
          showErrorSnackBar(context, state.message);
        } else if (state is TrackingInProgress) {
          if (state.gpsSignalLost && !_gpsLostNotified) {
            _gpsLostNotified = true;
            showErrorSnackBar(
              context,
              'GPS signal lost. Check location is on.',
            );
          } else if (!state.gpsSignalLost) {
            _gpsLostNotified = false;
          }
          // Voice coach updates
          if (_prefsNotifier.value.voiceCoachEnabled) {
            _voiceCoach.checkMilestone(
              distanceMeters: state.distanceMeters,
              avgPaceSecondsPerKm: state.avgPaceSecondsPerKm,
              unit: _unitNotifier.value,
              calories: state.calories,
              prefs: _prefsNotifier.value,
            );
            _voiceCoach.checkTargetStatus(
              distanceMeters: state.distanceMeters,
              calories: state.calories,
              prefs: _prefsNotifier.value,
              unit: _unitNotifier.value,
            );
          }

          // Set start point on first track point (again if a bad first
          // fix was replaced).
          if (state.routePoints.isNotEmpty &&
              !identical(_startPoint, state.routePoints.first)) {
            final first = _startPoint == null;
            setState(() {
              _startPoint = state.routePoints.first;
              if (first) _isLocked = true; // Lock when tracking begins
            });
            _updateStartPoint(state.routePoints.first);
          }
          _updateRoute(state.routePoints);
          if (state.routePoints.isNotEmpty &&
              !identical(_currentPosition, state.routePoints.last)) {
            _currentPosition = state.routePoints.last;
            _updatePuck(state.routePoints.last);
          }
        } else if (state is TrackingPaused) {
          if (_prefsNotifier.value.voiceCoachEnabled)
            _voiceCoach.announcePause();
          // A workout resumed in its paused state starts here.
          if (_startPoint == null && state.routePoints.isNotEmpty) {
            setState(() => _startPoint = state.routePoints.first);
            _updateStartPoint(state.routePoints.first);
          }
          // Stay unlocked or locked as per user preference
          _updateRoute(state.routePoints);
          if (state.routePoints.isNotEmpty) {
            _updatePuck(state.routePoints.last);
          }
        } else if (state is TrackingCompleted && state.discarded) {
          _gpsLostNotified = false;
          showErrorSnackBar(context, 'Workout too short to save.');
          context.read<ActivityTrackingBloc>().add(ResetTracking());
        } else if (state is TrackingCompleted) {
          _gpsLostNotified = false;
          // The next workout's target is what's left after this one.
          _loadGoalTarget();
          if (!state.saved) {
            showErrorSnackBar(
              context,
              "Couldn't save this activity to your device.",
            );
          }
          if (_prefsNotifier.value.voiceCoachEnabled) {
            _voiceCoach.announceStop(
              distanceMeters: state.session.totalDistanceMeters,
              elapsedSeconds: state.session.totalDurationSeconds,
              unit: _unitNotifier.value,
            );
          }
          final bloc = context.read<ActivityTrackingBloc>();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ActivityCompletionPage(
                session: state.session,
                // Leaving the result cuts the summary cue short.
                onNewActivity: () {
                  _voiceCoach.stop();
                  bloc.add(ResetTracking());
                  Navigator.of(context).pop();
                },
                onBack: () {
                  _voiceCoach.stop();
                  bloc.add(ResetTracking());
                  Navigator.of(context).pop();
                },
                onViewHistory: () {
                  _voiceCoach.stop();
                  bloc.add(ResetTracking());
                  context.pushNamed('activity-history');
                },
              ),
            ),
          );
        } else if (state is TrackingIdle) {
          // Clear map annotations when reset
          _workoutRequested = false;
          _clearMapAnnotations();
          _startLocationUpdates();
        }
      },
      builder: (context, state) {
        final bloc = context.read<ActivityTrackingBloc>();

        Duration elapsed = Duration.zero;
        double distanceMeters = 0.0;
        int calories = 0;
        int avgPace = 0;
        int steps = 0;
        double currentSpeed = 0.0;
        double elevationGain = 0.0;

        if (state is TrackingInProgress) {
          elapsed = state.elapsed;
          distanceMeters = state.distanceMeters;
          calories = state.calories;
          avgPace = state.avgPaceSecondsPerKm;
          steps = state.steps;
          currentSpeed = state.currentSpeedMps;
          elevationGain = state.elevationGainMeters;
        } else if (state is TrackingPaused) {
          elapsed = state.elapsed;
          distanceMeters = state.distanceMeters;
          calories = state.calories;
          avgPace = state.avgPaceSecondsPerKm;
          steps = state.steps;
          elevationGain = state.elevationGainMeters;
        } else if (state is TrackingCompleted) {
          elapsed = Duration(seconds: state.session.totalDurationSeconds);
          distanceMeters = state.session.totalDistanceMeters;
          calories = state.session.calories;
          avgPace = state.session.avgPaceSecondsPerKm;
          steps = state.session.steps;
          elevationGain = state.elevationGainMeters;
        }

        return PopScope(
          canPop: state is TrackingIdle || state is TrackingCompleted,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) {
              showErrorSnackBar(context, 'Stop the workout before leaving.');
            }
          },
          child: Scaffold(
            backgroundColor: context.colors.surface,
            body: Stack(
              children: [
                // Map fills the background
                _mapLayer,

                // Back Button (only in Idle)
                if (state is TrackingIdle)
                  Positioned(
                    top: 0,
                    left: 0,
                    child: SafeArea(
                      child: Padding(
                        padding: EdgeInsets.all(context.gutter),
                        child: RoundIconButton(
                          icon: Icons.arrow_back_rounded,
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).backButtonTooltip,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ),
                  ),

                // History Button (only in Idle) — top-right
                if (state is TrackingIdle)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: SafeArea(
                      child: Padding(
                        padding: EdgeInsets.all(context.gutter),
                        child: RoundIconButton(
                          icon: Icons.history_rounded,
                          tooltip: 'History',
                          onPressed: () =>
                              context.pushNamed('activity-history'),
                        ),
                      ),
                    ),
                  ),

                // Top Stats Overlay
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: state is TrackingIdle
                            ? AppDimens.backButtonSize + context.gutter * 2
                            : AppDimens.space12,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ValueListenableBuilder<DistanceUnit>(
                            valueListenable: _unitNotifier,
                            builder: (_, unit, __) {
                              return ValueListenableBuilder<WorkoutPrefs>(
                                valueListenable: _prefsNotifier,
                                builder: (_, prefs, __) => TopStats(
                                  elapsed: elapsed,
                                  distanceMeters: distanceMeters,
                                  calories: calories,
                                  avgPace: avgPace,
                                  distanceUnit: unit,
                                  heartRateBpm: _liveHeartRate,
                                  workoutPrefs: prefs,
                                  steps: steps,
                                  currentSpeed: currentSpeed,
                                  elevationGain: elevationGain,
                                  activityType: state.activityType,
                                ),
                              );
                            },
                          ),
                          // No signal and no saved map here: the map may be
                          // blank, the workout still records.
                          OfflineMapNote(
                            latitude: _currentPosition?.latitude,
                            longitude: _currentPosition?.longitude,
                            maps: sl<OfflineMapService>(),
                            connectivity: sl<ConnectivityService>(),
                            onTap: state is TrackingIdle
                                ? () => context.pushNamed('offline-maps')
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom controls and Zoom Reset Button
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        AnimatedOpacity(
                          opacity: (_isUiVisible && !_isCountingDown)
                              ? 1.0
                              : 0.0,
                          duration: AppDurations.medium,
                          child: IgnorePointer(
                            ignoring: !(_isUiVisible && !_isCountingDown),
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: context.gutter,
                                bottom: AppDimens.space12,
                              ),
                              child: ZoomResetButton(
                                onPressed: () {
                                  if (_currentPosition != null) {
                                    _centerCamera(
                                      _currentPosition!.latitude,
                                      _currentPosition!.longitude,
                                      zoom: 16.0,
                                    );
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                        AnimatedOpacity(
                          opacity: (_isUiVisible && !_isCountingDown)
                              ? 1.0
                              : 0.0,
                          duration: AppDurations.medium,
                          child: IgnorePointer(
                            ignoring: !(_isUiVisible && !_isCountingDown),
                            child: ResponsiveCenter(
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  context.gutter,
                                  AppDimens.space8,
                                  context.gutter,
                                  AppDimens.space12,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    WorkoutMusicBar(music: _music),
                                    if (state is TrackingIdle) ...[
                                      _offlineMapsTip(),
                                      ActivitySelector(
                                        selected: state.activityType,
                                        enabled: true,
                                        onSelected: (type) {
                                          if (!type.isGpsBased) {
                                            widget.onWorkoutSelected(type);
                                            return;
                                          }
                                          _typePicked = true;
                                          bloc.add(SelectActivityType(type));
                                        },
                                      ),
                                      const SizedBox(height: AppDimens.space8),
                                    ],
                                    StartPauseControl(
                                      isIdle:
                                          state is TrackingIdle ||
                                          state is TrackingCompleted,
                                      isRunning: state is TrackingInProgress,
                                      startLabel:
                                          'Start ${state.activityType.label}',
                                      isLocked: _isLocked,
                                      onMusicTap: () =>
                                          _music.openPicker(context),
                                      onLockToggle: (locked) {
                                        setState(() {
                                          _isLocked = locked;
                                        });
                                      },
                                      onStart: () async {
                                        if (!await _allowTracking() ||
                                            !mounted) {
                                          return;
                                        }
                                        final duration = _prefsNotifier
                                            .value
                                            .countdownDurationSeconds;
                                        if (duration > 0) {
                                          setState(() {
                                            _isCountingDown = true;
                                          });
                                        } else {
                                          _beginTracking();
                                        }
                                      },
                                      onPause: _pauseTracking,
                                      onResume: _resumeTracking,
                                      onStop: () {
                                        final prefs = _prefsNotifier.value;
                                        String? tType;
                                        double? tValue;
                                        bool tAchieved = false;
                                        if (prefs.targetType !=
                                                WorkoutTargetType.none &&
                                            prefs.targetValue > 0) {
                                          tType = prefs.targetType.name;
                                          tValue = prefs.targetValue;
                                          // Compute achievement from current bloc state
                                          final s = context
                                              .read<ActivityTrackingBloc>()
                                              .state;
                                          final (meters, kcal) = switch (s) {
                                            TrackingInProgress() => (
                                              s.distanceMeters,
                                              s.calories,
                                            ),
                                            TrackingPaused() => (
                                              s.distanceMeters,
                                              s.calories,
                                            ),
                                            _ => (0.0, 0),
                                          };
                                          tAchieved = isActivityTargetMet(
                                            prefs.targetType,
                                            prefs.targetValue,
                                            distanceMeters: meters,
                                            calories: kcal,
                                          );
                                        }
                                        bloc.add(
                                          StopAndSaveTracking(
                                            targetType: tType,
                                            targetValue: tValue,
                                            targetAchieved: tAchieved,
                                          ),
                                        );
                                        _prefsNotifier.clearSessionTarget();
                                        _stopWorkoutAudio();
                                      },
                                      onSettingsTap: () => _openSettings(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_isCountingDown)
                  Positioned.fill(
                    child: CountdownOverlay(
                      durationSeconds:
                          _prefsNotifier.value.countdownDurationSeconds,
                      voiceCoachEnabled: _prefsNotifier.value.voiceCoachEnabled,
                      onFinished: () {
                        setState(() {
                          _isCountingDown = false;
                        });
                        _beginTracking();
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
