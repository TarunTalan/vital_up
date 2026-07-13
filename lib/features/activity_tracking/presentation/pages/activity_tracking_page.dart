import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart' hide ActivityType;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;
import 'package:vital_up/core/config/supabase_config.dart';
import 'package:vital_up/core/di/injection_container.dart';
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
import 'package:vital_up/features/activity_tracking/presentation/widgets/workout_music_player.dart';
import 'package:vital_up/features/activity_tracking/services/voice_coach_service.dart';

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

  final DistanceUnitNotifier _unitNotifier = DistanceUnitNotifier();
  final WorkoutPrefsNotifier _prefsNotifier = WorkoutPrefsNotifier();
  final VoiceCoachService _voiceCoach = VoiceCoachService();
  final HeartRateManager _hrManager = HeartRateManager();
  int? _liveHeartRate;
  StreamSubscription<int?>? _hrSubscription;
  bool _isAudioPlaying = true;

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
    _prefsNotifier.load();
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
      final defaultType = _prefsNotifier.value.defaultActivityType;
      final bloc = context.read<ActivityTrackingBloc>();
      if (bloc.state is TrackingIdle) {
        bloc.add(SelectActivityType(defaultType));
      }
    }
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download offline tiles: ${e.toString()}')),
        );
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
    if (_polylineAnnotationManager == null || points.length < 2) return;

    _polylineAnnotationManager!.deleteAll();

    final coordinates = points.map((p) => [p.longitude, p.latitude]).toList();

    _polylineAnnotationManager!.create(mbx.PolylineAnnotationOptions(
      geometry: mbx.LineString(coordinates: coordinates.map((c) => mbx.Position(c[0], c[1])).toList()),
      lineColor: const Color(0xFF2BC7D8).toARGB32(),
      lineWidth: 5.0,
    ));
  }

  void _updateStartPoint(TrackPoint? point) {
    if (_startPointAnnotationManager == null || point == null) return;

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
    if (_circleAnnotationManager == null || point == null) return;

    _circleAnnotationManager!.deleteAll();

    _circleAnnotationManager!.create(mbx.CircleAnnotationOptions(
      geometry: mbx.Point(coordinates: mbx.Position(point.longitude, point.latitude)),
      circleRadius: 8.0,
      circleColor: const Color(0xFF3BB5C8).toARGB32(),
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
    return BlocConsumer<ActivityTrackingBloc, ActivityTrackingState>(
      listener: (context, state) {
        if (state is TrackingPermissionDenied) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        } else if (state is TrackingInProgress) {
          // Voice coach milestone check
          if (_prefsNotifier.value.voiceCoachEnabled) {
            _voiceCoach.checkMilestone(
              distanceMeters: state.distanceMeters,
              avgPaceSecondsPerKm: state.avgPaceSecondsPerKm,
              unit: _unitNotifier.value,
            );
            // Target reached check
            final prefs = _prefsNotifier.value;
            if (prefs.targetType == WorkoutTargetType.distance &&
                state.distanceMeters >= prefs.targetValue * 1000 &&
                state.distanceMeters - (state.routePoints.length > 1 ? 0 : 0) >=
                    prefs.targetValue * 1000) {
              // fire once — voice coach handles dedup
            }
          }
          // Voice coach background story check
          if (_isAudioPlaying && _prefsNotifier.value.backgroundAudioTrack != 'None') {
            _voiceCoach.checkStoryNarrative(_prefsNotifier.value.backgroundAudioTrack);
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Stop the activity to exit')),
              );
            }
          },
          child: Scaffold(
            backgroundColor: Colors.white,
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
                          opacity: _isUiVisible ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          child: IgnorePointer(
                            ignoring: !_isUiVisible,
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
                          opacity: _isUiVisible ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          child: IgnorePointer(
                            ignoring: !_isUiVisible,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (state is TrackingInProgress || state is TrackingPaused)
                                    ValueListenableBuilder<WorkoutPrefs>(
                                      valueListenable: _prefsNotifier,
                                      builder: (_, prefs, __) {
                                        return WorkoutMusicPlayer(
                                          trackName: prefs.backgroundAudioTrack,
                                          isPlaying: _isAudioPlaying,
                                          onPlayPause: () {
                                            setState(() {
                                              _isAudioPlaying = !_isAudioPlaying;
                                            });
                                          },
                                          onNext: () {
                                            final nextTrack = switch (prefs.backgroundAudioTrack) {
                                              'Story: Rise & Grind' => 'Story: The Ascent',
                                              'Story: The Ascent' => 'Music: Synthwave Cardio Energy',
                                              'Music: Synthwave Cardio Energy' => 'Music: Lo-Fi Jogging Beats',
                                              _ => 'Story: Rise & Grind',
                                            };
                                            _prefsNotifier.setBackgroundAudioTrack(nextTrack);
                                            _voiceCoach.resetStory();
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
                                    onLockToggle: (locked) {
                                      setState(() {
                                        _isLocked = locked;
                                      });
                                    },
                                    onStart: () async {
                                      _voiceCoach.resetStory();
                                      setState(() {
                                        _isAudioPlaying = true;
                                      });
                                      if (_prefsNotifier.value.countdownEnabled) {
                                        await CountdownOverlay.show(context);
                                      }
                                      bloc.add(StartTracking());
                                      if (_prefsNotifier.value.voiceCoachEnabled) {
                                        _voiceCoach.announceStart();
                                      }
                                    },
                                    onPause: () {
                                      bloc.add(PauseTracking());
                                      setState(() {
                                        _isAudioPlaying = false;
                                      });
                                    },
                                    onResume: () {
                                      bloc.add(ResumeTracking());
                                      setState(() {
                                        _isAudioPlaying = true;
                                      });
                                    },
                                    onStop: () => bloc.add(StopAndSaveTracking()),
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
              ],
            ),
          ),
        );
      },
    );
  }
}