import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart' hide ActivityType;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;
import 'package:vital_up/core/config/supabase_config.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/preferences/distance_unit_notifier.dart';

import 'package:vital_up/core/preferences/workout_prefs_notifier.dart';
import 'package:vital_up/features/activity_tracking/domain/repositories/map_tile_repository.dart';
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
  bool _isOfflineMapReady = false;
  bool _isDownloadingMap = false;
  double _mapDownloadProgress = 0.0;
  bool _isUiVisible = true;
  bool _isLocked = true;
  bool _isCountingDown = false;

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
  StreamSubscription<Position>? _positionSubscription;

  @override
  void initState() {
    super.initState();
    _unitNotifier.load();
    _prefsNotifier.load().then((_) {
      _checkIfCurrentTrackFavorited();
    });
    _prefsNotifier.addListener(_onPrefsChanged);
    _voiceCoach.init();
    _hrSubscription = _hrManager.bpmStream.listen((bpm) {
      if (mounted) setState(() => _liveHeartRate = bpm);
    });
    _checkOfflineMap();
    _startLocationUpdates();
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
    final existing = await isar.favoriteAudios.filter().trackIdEqualTo(track).findFirst();
    if (mounted) {
      setState(() {
        _isCurrentTrackFavorited = existing != null;
      });
    }
  }

  static const _audioChannel = MethodChannel('com.example.vital_up/audio_intent');

  void _playWorkoutAudio({bool play = true}) {
    final prefs = _prefsNotifier.value;
    if (prefs.preferredPlayerPackage != 'builtIn') {
      _audioChannel.invokeMethod('launchAudioApp', {'packageName': prefs.preferredPlayerPackage});
    } else {
      sl<IsarService>().isar.downloadedTracks
          .filter()
          .trackIdEqualTo(prefs.backgroundAudioTrack)
          .findFirst()
          .then((downloaded) {
        final localPath = downloaded?.localFilePath;
        final source = downloaded != null
            ? 'download'
            : (prefs.backgroundAudioTrack.startsWith('Local:') ? 'local' : 'preset');
        sl<WorkoutAudioService>().playTrack(
          prefs.backgroundAudioTrack,
          source: source,
          localPath: localPath,
          play: play,
        );
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
      _audioChannel.invokeMethod('launchAudioApp', {'packageName': prefs.preferredPlayerPackage});
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
      final favs = await sl<IsarService>().isar.favoriteAudios.where().findAll();
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
    await _prefsNotifier.setBackgroundAudioTrack(targetTrack, queueType: queueType);

    _voiceCoach.stop();

    _playWorkoutAudio();
  }

  Future<void> _checkOfflineMap() async {
    final mapRepo = sl<MapTileRepository>();
    final exists = await mapRepo.checkRegionDownloaded(kOfflineRegionId);
    if (mounted) {
      setState(() {
        _isOfflineMapReady = exists;
      });
    }
  }

  @override
  void dispose() {
    // Reset selected track to None, stop playback, and reset TTS/voice coach on exit
    _prefsNotifier.setBackgroundAudioTrack('None');
    _stopWorkoutAudio();
    _voiceCoach.stop();

    _prefsNotifier.removeListener(_onPrefsChanged);
    _positionSubscription?.cancel();
    _hrSubscription?.cancel();
    _hrManager.dispose();
    _voiceCoach.dispose();
    _unitNotifier.dispose();
    _prefsNotifier.dispose();
    super.dispose();
  }

  Future<void> _startLocationUpdates() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      return;
    }

    _positionSubscription = Geolocator.getPositionStream(
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
      }
    });
  }

  Future<void> _downloadOfflineMap() async {
    setState(() {
      _isDownloadingMap = true;
      _mapDownloadProgress = 0.0;
    });

    try {
      if (!SupabaseConfig.mapboxAccessToken.startsWith('pk.')) {
        throw Exception(
          'A valid Mapbox public access token is required before offline maps can be downloaded.',
        );
      }

      // 1. Fetch current GPS position
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied.');
        }
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      // 2. Start Mapbox tile download (10km radius)
      final mapRepo = sl<MapTileRepository>();
      final downloadStream = mapRepo.downloadRegion(
        kOfflineRegionId,
        position.latitude,
        position.longitude,
        10.0,
      );

      await for (final progress in downloadStream) {
        if (mounted) {
          setState(() {
            _mapDownloadProgress = progress;
          });
        }
      }

      if (mounted) {
        setState(() {
          _isOfflineMapReady = true;
          _isDownloadingMap = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloadingMap = false;
        });
        showErrorSnackBar(context, 'Failed to download offline tiles: ${e.toString()}');
      }
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

  void _onMapCreated(mbx.MapboxMap map) async {
    _mapboxMap = map;

    // Set map style
    await map.loadStyleURI(mbx.MapboxStyles.MAPBOX_STREETS);

    // Move compass to top right, at roughly 60% height of screen
    final screenHeight = MediaQuery.sizeOf(context).height;
    await map.compass.updateSettings(mbx.CompassSettings(
      position: mbx.OrnamentPosition.TOP_RIGHT,
      marginTop: screenHeight * 0.6,
      marginRight: 12,
    ));

    // Hide scale bar
    await map.scaleBar.updateSettings(mbx.ScaleBarSettings(enabled: false));

    // Create annotation managers
    _polylineAnnotationManager = await map.annotations.createPolylineAnnotationManager();
    _circleAnnotationManager = await map.annotations.createCircleAnnotationManager();
    _startPointAnnotationManager = await map.annotations.createCircleAnnotationManager();

    // Center camera on user's current location initially with appropriate zoom
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      _centerCamera(position.latitude, position.longitude, zoom: 16.0);

      // Update initial position puck
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
    } catch (_) {}
  }

  void _updateRoute(List<TrackPoint> points) {
    if (_polylineAnnotationManager == null || points.length < 2 || !mounted) return;

    _polylineAnnotationManager!.deleteAll();

    final coordinates = points.map((p) => [p.longitude, p.latitude]).toList();
    final primaryColor = Theme.of(context).colorScheme.primary;

    _polylineAnnotationManager!.create(mbx.PolylineAnnotationOptions(
      geometry: mbx.LineString(coordinates: coordinates.map((c) => mbx.Position(c[0], c[1])).toList()),
      lineColor: primaryColor.toARGB32(),
      lineWidth: 5.0,
    ));
  }

  void _updateStartPoint(TrackPoint? point) {
    if (_startPointAnnotationManager == null || point == null || !mounted) return;

    _startPointAnnotationManager!.deleteAll();

    _startPointAnnotationManager!.create(mbx.CircleAnnotationOptions(
      geometry: mbx.Point(coordinates: mbx.Position(point.longitude, point.latitude)),
      circleRadius: 10.0,
      circleColor: const Color(0xFFFF5722).toARGB32(),
      circleStrokeWidth: 3.0,
      circleStrokeColor: const Color(0xFFFFFFFF).toARGB32(),
    ));
  }

  void _updatePuck(TrackPoint? point) {
    if (_circleAnnotationManager == null || point == null || !mounted) return;

    _circleAnnotationManager!.deleteAll();
    final primaryColor = Theme.of(context).colorScheme.primary;

    _circleAnnotationManager!.create(mbx.CircleAnnotationOptions(
      geometry: mbx.Point(coordinates: mbx.Position(point.longitude, point.latitude)),
      circleRadius: 8.0,
      circleColor: primaryColor.toARGB32(),
      circleStrokeWidth: 2.0,
      circleStrokeColor: const Color(0xFFFFFFFF).toARGB32(),
    ));
  }

  void _centerCamera(double lat, double lng, {double? zoom}) {
    _mapboxMap?.setCamera(mbx.CameraOptions(
      center: mbx.Point(coordinates: mbx.Position(lng, lat)),
      zoom: zoom,
    ));
  }

  void _clearMapAnnotations() {
    _polylineAnnotationManager?.deleteAll();
    _circleAnnotationManager?.deleteAll();
    _startPointAnnotationManager?.deleteAll();
    setState(() {
      _startPoint = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocConsumer<ActivityTrackingBloc, ActivityTrackingState>(
      listener: (context, state) {
        if (state is TrackingPermissionDenied) {
          showErrorSnackBar(context, state.message);
        } else if (state is TrackingInProgress) {
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
          if (state.routePoints.isNotEmpty) {
            _updatePuck(state.routePoints.last);
          }
        } else if (state is TrackingPaused) {
          if (_prefsNotifier.value.voiceCoachEnabled) _voiceCoach.announcePause();
          // Stay unlocked or locked as per user preference
          _updateRoute(state.routePoints);
          if (state.routePoints.isNotEmpty) {
            _updatePuck(state.routePoints.last);
          }
        } else if (state is TrackingCompleted) {
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
                  Navigator.of(context).pop();
                  context.pushReplacementNamed('activity-history');
                },
              ),
            ),
          );
        } else if (state is TrackingIdle) {
          // Clear map annotations when reset
          _clearMapAnnotations();
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
          if (state.routePoints.isNotEmpty) {
            currentSpeed = state.routePoints.last.speed;
            double cumulativeElevation = 0.0;
            for (int i = 1; i < state.routePoints.length; i++) {
              final diff = state.routePoints[i].altitude - state.routePoints[i - 1].altitude;
              if (diff > 0) cumulativeElevation += diff;
            }
            elevationGain = cumulativeElevation;
          }
        } else if (state is TrackingPaused) {
          elapsed = state.elapsed;
          distanceMeters = state.distanceMeters;
          calories = state.calories;
          avgPace = state.avgPaceSecondsPerKm;
          steps = state.steps;
          if (state.routePoints.isNotEmpty) {
            currentSpeed = 0.0;
            double cumulativeElevation = 0.0;
            for (int i = 1; i < state.routePoints.length; i++) {
              final diff = state.routePoints[i].altitude - state.routePoints[i - 1].altitude;
              if (diff > 0) cumulativeElevation += diff;
            }
            elevationGain = cumulativeElevation;
          }
        } else if (state is TrackingCompleted) {
          elapsed = Duration(seconds: state.session.totalDurationSeconds);
          distanceMeters = state.session.totalDistanceMeters;
          calories = state.session.calories;
          avgPace = state.session.avgPaceSecondsPerKm;
          steps = state.session.steps;
          if (state.session.points.isNotEmpty) {
            currentSpeed = 0.0;
            double cumulativeElevation = 0.0;
            for (int i = 1; i < state.session.points.length; i++) {
              final diff = state.session.points[i].altitude - state.session.points[i - 1].altitude;
              if (diff > 0) cumulativeElevation += diff;
            }
            elevationGain = cumulativeElevation;
          }
        }

        return PopScope(
          canPop: state is TrackingIdle || state is TrackingCompleted,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) {
              showErrorSnackBar(context, 'Stop the activity to exit');
            }
          },
          child: Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
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
                        padding: const EdgeInsets.all(12),
                        child: RoundIconButton(
                          icon: Icons.arrow_back_rounded,
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
                        padding: const EdgeInsets.all(12),
                        child: RoundIconButton(
                          icon: Icons.history_rounded,
                          onPressed: () => context.pushNamed('activity-history'),
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
                        top: state is TrackingIdle ? 56 : 12,
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
                          opacity: (_isUiVisible && !_isCountingDown) ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          child: IgnorePointer(
                            ignoring: !(_isUiVisible && !_isCountingDown),
                            child: Padding(
                              padding: const EdgeInsets.only(right: 12, bottom: 12),
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
                          opacity: (_isUiVisible && !_isCountingDown) ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          child: IgnorePointer(
                            ignoring: !(_isUiVisible && !_isCountingDown),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),

                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ValueListenableBuilder<WorkoutPrefs>(
                                    valueListenable: _prefsNotifier,
                                    builder: (context, prefs, __) {
                                      final isExternal = prefs.preferredPlayerPackage != 'builtIn';
                                      final displayTrack = isExternal
                                          ? 'Player: ${prefs.preferredPlayerPackage.split('.').last.toUpperCase()}'
                                          : prefs.backgroundAudioTrack;

                                      return StreamBuilder<bool>(
                                        stream: sl<WorkoutAudioService>().playingStream,
                                        initialData: sl<WorkoutAudioService>().isPlaying,
                                        builder: (context, playingSnapshot) {
                                          final isPlaying = playingSnapshot.data ?? false;
                                           return WorkoutMusicPlayer(
                                             trackName: displayTrack,
                                             isPlaying: isExternal ? false : isPlaying,
                                             isFavorited: isExternal ? false : _isCurrentTrackFavorited,
                                             isMinimized: _isPlayerMinimized,
                                             onMinimizeToggle: () {
                                               setState(() {
                                                 _isPlayerMinimized = !_isPlayerMinimized;
                                               });
                                             },
                                             onTap: () {
                                               Navigator.of(context).push(
                                                 MaterialPageRoute(
                                                   builder: (_) => WorkoutAudioPage(
                                                     current: prefs,
                                                     notifier: _prefsNotifier,
                                                   ),
                                                 ),
                                               ).then((_) {
                                                 _checkIfCurrentTrackFavorited();
                                               });
                                             },
                                             onDiscard: () {
                                               _prefsNotifier.setBackgroundAudioTrack('None');
                                               _stopWorkoutAudio();
                                               _voiceCoach.stop();
                                             },
                                             onPlayPause: () {
                                               if (isExternal) {
                                                  _playWorkoutAudio();
                                               } else {
                                                 final audioService = sl<WorkoutAudioService>();
                                                 if (audioService.isPlaying) {
                                                   _pauseWorkoutAudio();
                                                   sl<VoiceCoachService>().stop();
                                                 } else {
                                                   _playWorkoutAudio();
                                                 }
                                               }
                                             },
                                             onNext: isExternal ? () {} : () => _cycleTrack(next: true),
                                             onPrevious: isExternal ? () {} : () => _cycleTrack(next: false),
                                             onFavoriteToggle: isExternal ? () {} : () async {
                                               final track = prefs.backgroundAudioTrack;
                                               final isar = sl<IsarService>().isar;
                                               final existing = await isar.favoriteAudios.filter().trackIdEqualTo(track).findFirst();
                                               await isar.writeTxn(() async {
                                                 if (existing != null) {
                                                   await isar.favoriteAudios.delete(existing.id);
                                                 } else {
                                                   final title = track.replaceFirst('Story: ', '').replaceFirst('Music: ', '');
                                                   final source = track.startsWith('Local:') ? 'local' : 'preset';
                                                   final fav = FavoriteAudio()
                                                     ..trackId = track
                                                     ..title = title
                                                     ..subtitle = source == 'local' ? 'Local Track' : 'Curated Audio'
                                                     ..audioSource = source
                                                     ..favoritedAt = DateTime.now();
                                                   await isar.favoriteAudios.put(fav);
                                                 }
                                               });
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
                                      onSelected: (type) => bloc.add(SelectActivityType(type)),
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                  StartPauseControl(
                                    state: state,
                                    isLocked: _isLocked,
                                    onMusicTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => WorkoutAudioPage(
                                            current: _prefsNotifier.value,
                                            notifier: _prefsNotifier,
                                          ),
                                        ),
                                      ).then((_) {
                                        _checkIfCurrentTrackFavorited();
                                      });
                                    },
                                    onLockToggle: (locked) {
                                      setState(() {
                                        _isLocked = locked;
                                      });
                                    },
                                    onStart: () async {
                                      final duration = _prefsNotifier.value.countdownDurationSeconds;
                                      if (duration > 0) {
                                        setState(() {
                                          _isCountingDown = true;
                                        });
                                      } else {
                                        _prefsNotifier.applyDailyTargetIfEnabled();
                                        bloc.add(StartTracking());
                                        if (_prefsNotifier.value.voiceCoachEnabled) {
                                          _voiceCoach.announceStart();
                                        }
                                        _playWorkoutAudio();
                                      }
                                    },
                                     onPause: () {
                                       bloc.add(PauseTracking());
                                       _pauseWorkoutAudio();
                                     },
                                     onResume: () {
                                       bloc.add(ResumeTracking());

                                       if (_prefsNotifier.value.voiceCoachEnabled) {
                                         _voiceCoach.announceResume();
                                       }
                                       _resumeWorkoutAudio();
                                     },
                                    onStop: () {
                                      final prefs = _prefsNotifier.value;
                                      String? tType;
                                      double? tValue;
                                      bool tAchieved = false;
                                      if (prefs.targetType != WorkoutTargetType.none && prefs.targetValue > 0) {
                                        tType = prefs.targetType.name;
                                        tValue = prefs.targetValue;
                                        // Compute achievement from current bloc state
                                        final s = context.read<ActivityTrackingBloc>().state;
                                        if (prefs.targetType == WorkoutTargetType.distance) {
                                          final targetMeters = prefs.targetValue * 1000;
                                          if (s is TrackingInProgress) {
                                            tAchieved = s.distanceMeters >= targetMeters;
                                          } else if (s is TrackingPaused) {
                                            tAchieved = s.distanceMeters >= targetMeters;
                                          }
                                        } else if (prefs.targetType == WorkoutTargetType.calories) {
                                          if (s is TrackingInProgress) {
                                            tAchieved = s.calories >= prefs.targetValue;
                                          } else if (s is TrackingPaused) {
                                            tAchieved = s.calories >= prefs.targetValue;
                                          }
                                        }
                                      }
                                      bloc.add(StopAndSaveTracking(
                                        targetType: tType,
                                        targetValue: tValue,
                                        targetAchieved: tAchieved,
                                      ));
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
                      ],
                    ),
                  ),
                ),
                if (_isCountingDown)
                  Positioned.fill(
                    child: CountdownOverlay(
                      durationSeconds: _prefsNotifier.value.countdownDurationSeconds,
                      voiceCoachEnabled: _prefsNotifier.value.voiceCoachEnabled,
                      onFinished: () {
                        setState(() {
                          _isCountingDown = false;
                        });
                        bloc.add(StartTracking());
                        _prefsNotifier.applyDailyTargetIfEnabled();
                        if (_prefsNotifier.value.voiceCoachEnabled) {
                          _voiceCoach.announceStart();
                        }
                        _playWorkoutAudio();
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