import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart' hide ActivityType;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;
import 'package:vital_up/core/config/supabase_config.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/features/activity_tracking/domain/repositories/map_tile_repository.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/track_point.dart';
import 'package:vital_up/features/activity_tracking/presentation/bloc/activity_tracking_bloc.dart';
import 'package:vital_up/features/activity_tracking/presentation/bloc/activity_tracking_event.dart';
import 'package:vital_up/features/activity_tracking/presentation/bloc/activity_tracking_state.dart';
import 'package:vital_up/features/activity_tracking/presentation/pages/activity_completion_page.dart';
import 'package:vital_up/features/activity_tracking/presentation/widgets/activity_tracking_common_widgets.dart';
import 'package:vital_up/features/activity_tracking/presentation/widgets/activity_tracking_controls.dart';
import 'package:vital_up/features/activity_tracking/presentation/widgets/activity_tracking_stats.dart';

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
    _checkOfflineMap();
    _startLocationUpdates();
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
    _positionSubscription?.cancel();
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

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SETTINGS',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2),
              ),
              const SizedBox(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: OfflineMapIcon(
                  isReady: _isOfflineMapReady,
                  isDownloading: _isDownloadingMap,
                  progress: _mapDownloadProgress,
                  onTap: () {},
                ),
                title: Text(
                  _isOfflineMapReady
                      ? 'Offline map ready'
                      : _isDownloadingMap
                      ? 'Downloading offline map…'
                      : 'Download offline map',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: _isOfflineMapReady
                    ? null
                    : const Text('Keep tracking your route without signal'),
                onTap: _isOfflineMapReady || _isDownloadingMap
                    ? null
                    : () {
                  Navigator.of(sheetContext).pop();
                  _downloadOfflineMap();
                },
              ),
            ],
          ),
        );
      },
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

        if (state is TrackingInProgress) {
          elapsed = state.elapsed;
          distanceMeters = state.distanceMeters;
          calories = state.calories;
          avgPace = state.avgPaceSecondsPerKm;
        } else if (state is TrackingPaused) {
          elapsed = state.elapsed;
          distanceMeters = state.distanceMeters;
          calories = state.calories;
          avgPace = state.avgPaceSecondsPerKm;
        } else if (state is TrackingCompleted) {
          elapsed = Duration(seconds: state.session.totalDurationSeconds);
          distanceMeters = state.session.totalDistanceMeters;
          calories = state.session.calories;
          avgPace = state.session.avgPaceSecondsPerKm;
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
                      child: TopStats(
                        elapsed: elapsed,
                        distanceMeters: distanceMeters,
                        calories: calories,
                        avgPace: avgPace,
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
                                    onStart: () => bloc.add(StartTracking()),
                                    onPause: () => bloc.add(PauseTracking()),
                                    onResume: () => bloc.add(ResumeTracking()),
                                    onStop: () => bloc.add(StopAndSaveTracking()),
                                    onSettingsTap: () => _showSettingsSheet(),
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