import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart' hide ActivityType;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;
import 'package:vital_up/core/config/supabase_config.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/preferences/distance_unit_notifier.dart';

import 'package:vital_up/core/preferences/workout_prefs_notifier.dart';
import 'package:vital_up/features/activity_tracking/data/services/workout_recovery_service.dart';
import 'package:vital_up/features/activity_tracking/domain/repositories/map_tile_repository.dart';
import 'package:vital_up/features/activity_tracking/domain/services/workout_checkpoint.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/track_point.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
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
import 'package:isar_community/isar.dart';
import 'package:vital_up/core/database/isar_service.dart';
import 'package:vital_up/core/database/collections/favorite_audio.dart';
import 'package:vital_up/core/database/collections/downloaded_track.dart';
import 'package:vital_up/features/activity_tracking/presentation/widgets/workout_music_player.dart';
import 'package:vital_up/features/activity_tracking/presentation/pages/workout_audio_page.dart';
import 'package:vital_up/features/activity_tracking/services/voice_coach_service.dart';
import 'package:vital_up/features/activity_tracking/services/workout_audio_service.dart';
import 'package:vital_up/features/activity_tracking/services/local_audio_query_service.dart';

const String kOfflineRegionId = 'local_workout_region_10k';

class ActivityTrackingPage extends StatelessWidget {
  const ActivityTrackingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ActivityTrackingBloc>(),
      child: const _ActivityTrackingView(),
    );
  }
}

class _ActivityTrackingView extends StatefulWidget {
  const _ActivityTrackingView();

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
  bool _isCurrentTrackFavorited = false;
  bool _isPlayerMinimized = false;

  mbx.MapboxMap? _mapboxMap;
  mbx.PolylineAnnotationManager? _polylineAnnotationManager;
  mbx.CircleAnnotationManager? _circleAnnotationManager;
  mbx.CircleAnnotationManager? _startPointAnnotationManager;

  TrackPoint? _currentPosition;
  TrackPoint? _startPoint;

  /// Map-preview position feed while no workout is running. It must be
  /// cancelled before a workout starts: geolocator shares one native stream
  /// and would hand the workout this low-precision, foreground-only feed.
  StreamSubscription<Position>? _positionSubscription;
  late final AppLifecycleListener _lifecycleListener;

  /// Set once Start or Resume is tapped, so the map preview never
  /// subscribes while the workout's own GPS stream is starting.
  bool _workoutRequested = false;

  /// A choice about an interrupted workout is being carried out.
  bool _recoveryBusy = false;

  late final Future<void> _prefsLoaded;

  @override
  void initState() {
    super.initState();
    _unitNotifier.load();
    _prefsLoaded = _prefsNotifier.load().then((_) {
      _checkIfCurrentTrackFavorited();
    });
    _prefsNotifier.addListener(_onPrefsChanged);
    _voiceCoach.init();
    _hrSubscription = _hrManager.bpmStream.listen((bpm) {
      if (mounted) setState(() => _liveHeartRate = bpm);
    });
    // Settle an interrupted workout first: its resume needs the GPS stream
    // and the location prompt to itself.
    _checkInterruptedWorkout().whenComplete(() {
      if (mounted) _startLocationUpdates();
    });
    // Checkpoint the workout whenever the app leaves the foreground — the
    // OS may kill a backgrounded app without further notice.
    _lifecycleListener = AppLifecycleListener(
      onHide: () {
        if (mounted) context.read<ActivityTrackingBloc>().add(PersistProgress());
      },
    );
  }

  void _onPrefsChanged() {
    if (mounted) {
      _checkIfCurrentTrackFavorited();
      final defaultType = _prefsNotifier.value.defaultActivityType;
      final bloc = context.read<ActivityTrackingBloc>();
      if (bloc.state is TrackingIdle) {
        bloc.add(SelectActivityType(defaultType));
      }
    }
  }

  Future<void> _checkIfCurrentTrackFavorited() async {
    final track = _prefsNotifier.value.backgroundAudioTrack;
    final isar = sl<IsarService>().isar;
    final FavoriteAudio? existing;
    try {
      existing = await isar.favoriteAudios
          .filter()
          .trackIdEqualTo(track)
          .findFirst();
    } catch (e) {
      debugPrint('Reading favourite tracks failed: $e');
      return;
    }
    if (mounted) {
      setState(() {
        _isCurrentTrackFavorited = existing != null;
      });
    }
  }

  static const _audioChannel = MethodChannel(
    'com.example.vital_up/audio_intent',
  );

  /// Opens the user's chosen music app. The app may have been uninstalled
  /// since it was picked, so failures are logged rather than thrown.
  void _launchExternalPlayer(String packageName) {
    _audioChannel
        .invokeMethod('launchAudioApp', {'packageName': packageName})
        .catchError((Object e) {
          debugPrint('Launching music app failed: $e');
          if (mounted) {
            showErrorSnackBar(context, "Couldn't open your music app.");
          }
          return null;
        });
  }

  void _playWorkoutAudio({bool play = true}) {
    final prefs = _prefsNotifier.value;
    if (prefs.preferredPlayerPackage != 'builtIn') {
      _launchExternalPlayer(prefs.preferredPlayerPackage);
    } else {
      sl<IsarService>().isar.downloadedTracks
          .filter()
          .trackIdEqualTo(prefs.backgroundAudioTrack)
          .findFirst()
          .then((downloaded) {
            final localPath = downloaded?.localFilePath;
            final source = downloaded != null
                ? 'download'
                : (prefs.backgroundAudioTrack.startsWith('Local:')
                      ? 'local'
                      : 'preset');
            sl<WorkoutAudioService>().playTrack(
              prefs.backgroundAudioTrack,
              source: source,
              localPath: localPath,
              play: play,
            );
          })
          .catchError((Object e) {
            debugPrint('Starting workout audio failed: $e');
          });
    }
  }

  void _pauseWorkoutAudio() {
    final prefs = _prefsNotifier.value;
    if (prefs.preferredPlayerPackage == 'builtIn') {
      sl<WorkoutAudioService>().pause();
    }
    _voiceCoach.stop();
  }

  void _resumeWorkoutAudio() {
    final prefs = _prefsNotifier.value;
    if (prefs.preferredPlayerPackage != 'builtIn') {
      _launchExternalPlayer(prefs.preferredPlayerPackage);
    } else {
      sl<WorkoutAudioService>().resume();
    }
  }

  void _stopWorkoutAudio() {
    final prefs = _prefsNotifier.value;
    if (prefs.preferredPlayerPackage == 'builtIn') {
      sl<WorkoutAudioService>().stop();
    }
  }

  Future<void> _cycleTrack({required bool next}) async {
    final prefs = _prefsNotifier.value;
    final queueType = prefs.backgroundAudioQueueType;
    final currentTrack = prefs.backgroundAudioTrack;

    List<String> queue = [];

    if (queueType == 'stories' || queueType == 'curated') {
      queue = [
        'Story: It\'s Possible',
        'Story: Goals',
        'Story: Light Up the Darkness',
        'Story: Without Limits',
        'Story: Best Speeches',
      ];
    } else if (queueType == 'favorite') {
      final favs = await sl<IsarService>().isar.favoriteAudios
          .where()
          .findAll();
      queue = favs.map((f) => f.trackId).toList();
    } else if (queueType == 'local') {
      final songs = await sl<LocalAudioQueryService>().getLocalSongs();
      queue = songs.map((s) => 'Local:${s.id}').toList();
    }

    if (queue.isEmpty) {
      queue = [
        'Story: It\'s Possible',
        'Story: Goals',
        'Story: Light Up the Darkness',
        'Story: Without Limits',
        'Story: Best Speeches',
      ];
    }

    int currentIndex = queue.indexOf(currentTrack);
    int targetIndex;

    if (currentIndex == -1) {
      targetIndex = next ? 0 : queue.length - 1;
    } else {
      if (next) {
        targetIndex = (currentIndex + 1) % queue.length;
      } else {
        targetIndex = (currentIndex - 1 + queue.length) % queue.length;
      }
    }

    final targetTrack = queue[targetIndex];
    await _prefsNotifier.setBackgroundAudioTrack(
      targetTrack,
      queueType: queueType,
    );

    _voiceCoach.stop();

    _playWorkoutAudio();
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
    _hrManager.dispose();
    _voiceCoach.dispose();
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

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
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

  /// Starts the workout. Shared by the instant start and the countdown.
  void _beginTracking() {
    _workoutRequested = true;
    _stopLocationUpdates();
    _prefsNotifier.applyDailyTargetIfEnabled();
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
        _resumeInterrupted(workout);
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
    bloc.add(RestoreTracking(
      checkpoint: workout.checkpoint,
      session: workout.session,
    ));
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
        targetAchieved: hasTarget &&
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

  /// Keeps a 10 km offline map around the user so the tracking map still
  /// renders with no connection. Runs once per visit, silently: offline the
  /// download simply fails and is retried on the next visit.
  Future<void> _ensureOfflineMap(double latitude, double longitude) async {
    if (_offlineMapChecked) return;
    _offlineMapChecked = true;
    if (!SupabaseConfig.mapboxAccessToken.startsWith('pk.')) return;

    final mapRepo = sl<MapTileRepository>();
    try {
      if (await mapRepo.regionCovers(kOfflineRegionId, latitude, longitude)) {
        return;
      }
      await mapRepo
          .downloadRegion(kOfflineRegionId, latitude, longitude, 10.0)
          .drain<void>();
    } catch (e) {
      debugPrint('Offline map download skipped: $e');
    }
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

    // Set map style. Offline without a downloaded style pack this fails;
    // carry on so the route and position markers are still created.
    try {
      await map.loadStyleURI(mbx.MapboxStyles.MAPBOX_STREETS);
    } catch (e) {
      debugPrint('Map style failed to load: $e');
    }
    if (!mounted) return;

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

  void _updateRoute(List<TrackPoint> points) {
    if (_polylineAnnotationManager == null || points.length < 2 || !mounted)
      return;

    _polylineAnnotationManager!.deleteAll();

    final coordinates = points.map((p) => [p.longitude, p.latitude]).toList();
    final primaryColor = context.colors.primary;

    _polylineAnnotationManager!.create(
      mbx.PolylineAnnotationOptions(
        geometry: mbx.LineString(
          coordinates: coordinates
              .map((c) => mbx.Position(c[0], c[1]))
              .toList(),
        ),
        lineColor: primaryColor.toARGB32(),
        lineWidth: ActivityMapDimens.routeWidth,
      ),
    );
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
    if (_circleAnnotationManager == null || point == null || !mounted) return;

    _circleAnnotationManager!.deleteAll();
    final primaryColor = context.colors.primary;

    _circleAnnotationManager!.create(
      mbx.CircleAnnotationOptions(
        geometry: mbx.Point(
          coordinates: mbx.Position(point.longitude, point.latitude),
        ),
        circleRadius: ActivityMapDimens.puckRadius,
        circleColor: primaryColor.toARGB32(),
        circleStrokeWidth: ActivityMapDimens.puckStroke,
        circleStrokeColor: ActivityColors.mapMarkerStroke.toARGB32(),
      ),
    );
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

          // Set start point on first track point
          if (_startPoint == null && state.routePoints.isNotEmpty) {
            setState(() {
              _startPoint = state.routePoints.first;
              _isLocked = true; // Lock when tracking actually begins
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
            );
          }
          final bloc = context.read<ActivityTrackingBloc>();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ActivityCompletionPage(
                session: state.session,
                onNewActivity: () {
                  bloc.add(ResetTracking());
                  Navigator.of(context).pop();
                },
                onBack: () {
                  bloc.add(ResetTracking());
                  Navigator.of(context).pop();
                },
                onViewHistory: () {
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
                Positioned.fill(
                  child: mbx.MapWidget(
                    key: const ValueKey("mapWidget"),
                    onMapCreated: _onMapCreated,
                    onTapListener: (context) {
                      if (mounted) {
                        setState(() {
                          _isUiVisible = !_isUiVisible;
                        });
                      }
                    },
                  ),
                ),

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
                      child: ValueListenableBuilder<DistanceUnit>(
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
                              activityTypeName: state.activityType.label,
                            ),
                          );
                        },
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
                                    ValueListenableBuilder<WorkoutPrefs>(
                                      valueListenable: _prefsNotifier,
                                      builder: (context, prefs, __) {
                                        final isExternal =
                                            prefs.preferredPlayerPackage !=
                                            'builtIn';
                                        final displayTrack = isExternal
                                            ? 'Player: ${prefs.preferredPlayerPackage.split('.').last.toUpperCase()}'
                                            : prefs.backgroundAudioTrack;

                                        return StreamBuilder<bool>(
                                          stream: sl<WorkoutAudioService>()
                                              .playingStream,
                                          initialData: sl<WorkoutAudioService>()
                                              .isPlaying,
                                          builder: (context, playingSnapshot) {
                                            final isPlaying =
                                                playingSnapshot.data ?? false;
                                            return WorkoutMusicPlayer(
                                              trackName: displayTrack,
                                              isPlaying: isExternal
                                                  ? false
                                                  : isPlaying,
                                              isFavorited: isExternal
                                                  ? false
                                                  : _isCurrentTrackFavorited,
                                              isMinimized: _isPlayerMinimized,
                                              onMinimizeToggle: () {
                                                setState(() {
                                                  _isPlayerMinimized =
                                                      !_isPlayerMinimized;
                                                });
                                              },
                                              onTap: () {
                                                Navigator.of(context)
                                                    .push(
                                                      MaterialPageRoute(
                                                        builder: (_) =>
                                                            WorkoutAudioPage(
                                                              current: prefs,
                                                              notifier:
                                                                  _prefsNotifier,
                                                            ),
                                                      ),
                                                    )
                                                    .then((_) {
                                                      _checkIfCurrentTrackFavorited();
                                                    });
                                              },
                                              onDiscard: () {
                                                _prefsNotifier
                                                    .setBackgroundAudioTrack(
                                                      'None',
                                                    );
                                                _stopWorkoutAudio();
                                                _voiceCoach.stop();
                                              },
                                              onPlayPause: () {
                                                if (isExternal) {
                                                  _playWorkoutAudio();
                                                } else {
                                                  final audioService =
                                                      sl<WorkoutAudioService>();
                                                  if (audioService.isPlaying) {
                                                    _pauseWorkoutAudio();
                                                    sl<VoiceCoachService>()
                                                        .stop();
                                                  } else {
                                                    _playWorkoutAudio();
                                                  }
                                                }
                                              },
                                              onNext: isExternal
                                                  ? () {}
                                                  : () =>
                                                        _cycleTrack(next: true),
                                              onPrevious: isExternal
                                                  ? () {}
                                                  : () => _cycleTrack(
                                                      next: false,
                                                    ),
                                              onFavoriteToggle: isExternal
                                                  ? () {}
                                                  : () async {
                                                      try {
                                                        final track = prefs
                                                            .backgroundAudioTrack;
                                                        final isar =
                                                            sl<IsarService>()
                                                                .isar;
                                                        final existing =
                                                            await isar
                                                                .favoriteAudios
                                                                .filter()
                                                                .trackIdEqualTo(
                                                                  track,
                                                                )
                                                                .findFirst();
                                                        await isar.writeTxn(() async {
                                                          if (existing != null) {
                                                            await isar
                                                                .favoriteAudios
                                                                .delete(
                                                                  existing.id,
                                                                );
                                                          } else {
                                                            final title = track
                                                                .replaceFirst(
                                                                  'Story: ',
                                                                  '',
                                                                )
                                                                .replaceFirst(
                                                                  'Music: ',
                                                                  '',
                                                                );
                                                            final source =
                                                                track.startsWith(
                                                                  'Local:',
                                                                )
                                                                ? 'local'
                                                                : 'preset';
                                                            final fav = FavoriteAudio()
                                                              ..trackId = track
                                                              ..title = title
                                                              ..subtitle =
                                                                  source ==
                                                                      'local'
                                                                  ? 'Local Track'
                                                                  : 'Curated Audio'
                                                              ..audioSource =
                                                                  source
                                                              ..favoritedAt =
                                                                  DateTime.now();
                                                            await isar
                                                                .favoriteAudios
                                                                .put(fav);
                                                          }
                                                        });
                                                      } catch (e) {
                                                        debugPrint(
                                                          'Updating favourites failed: $e',
                                                        );
                                                        if (context.mounted) {
                                                          showErrorSnackBar(
                                                            context,
                                                            "Couldn't update favourites. Try again.",
                                                          );
                                                        }
                                                      }
                                                      _checkIfCurrentTrackFavorited();
                                                    },
                                            );
                                          },
                                        );
                                      },
                                    ),
                                    if (state is TrackingIdle) ...[
                                      ActivitySelector(
                                        selected: state.activityType,
                                        enabled: true,
                                        onSelected: (type) =>
                                            bloc.add(SelectActivityType(type)),
                                      ),
                                      const SizedBox(height: AppDimens.space8),
                                    ],
                                    StartPauseControl(
                                      state: state,
                                      isLocked: _isLocked,
                                      onMusicTap: () {
                                        Navigator.of(context)
                                            .push(
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    WorkoutAudioPage(
                                                      current:
                                                          _prefsNotifier.value,
                                                      notifier: _prefsNotifier,
                                                    ),
                                              ),
                                            )
                                            .then((_) {
                                              _checkIfCurrentTrackFavorited();
                                            });
                                      },
                                      onLockToggle: (locked) {
                                        setState(() {
                                          _isLocked = locked;
                                        });
                                      },
                                      onStart: () async {
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
                                      onPause: () {
                                        bloc.add(PauseTracking());
                                        _pauseWorkoutAudio();
                                      },
                                      onResume: () {
                                        bloc.add(ResumeTracking());

                                        if (_prefsNotifier
                                            .value
                                            .voiceCoachEnabled) {
                                          _voiceCoach.announceResume();
                                        }
                                        _resumeWorkoutAudio();
                                      },
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
