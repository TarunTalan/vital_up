import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart' hide ActivityType;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;
import 'package:vital_up/core/config/supabase_config.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/features/activity_tracking/domain/repositories/map_tile_repository.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_session.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/track_point.dart';
import 'package:vital_up/features/activity_tracking/presentation/bloc/activity_tracking_bloc.dart';
import 'package:vital_up/features/activity_tracking/presentation/bloc/activity_tracking_event.dart';
import 'package:vital_up/features/activity_tracking/presentation/bloc/activity_tracking_state.dart';

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
                leading: _OfflineMapIcon(
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
                  final navigator = Navigator.of(context);
                  navigator.pop();
                  navigator.pop();
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
                        child: _RoundIconButton(
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
                      child: _TopStats(
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
                            child: _ZoomResetButton(
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
                                  _ActivitySelector(
                                    selected: state.activityType,
                                    enabled: true,
                                    onSelected: (type) => bloc.add(SelectActivityType(type)),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                _StartPauseControl(
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

class _TopStats extends StatelessWidget {
  final Duration elapsed;
  final double distanceMeters;
  final int calories;
  final int avgPace;

  const _TopStats({
    required this.elapsed,
    required this.distanceMeters,
    required this.calories,
    required this.avgPace,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatDuration(elapsed),
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              height: 1.0,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'DURATION',
            style: TextStyle(
              color: Color(0xFF9A9A9A),
              fontSize: 10,
              letterSpacing: 2.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _StatColumn(
                  value: (distanceMeters / 1000).toStringAsFixed(2),
                  label: 'DISTANCE (KM)',
                ),
              ),
              Expanded(
                child: _StatColumn(
                  value: calories.toString(),
                  label: 'CALORIES (CAL)',
                ),
              ),
              Expanded(
                child: _StatColumn(
                  value: _formatPace(avgPace),
                  label: 'AVG. PACE (MIN/KM)',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String value;
  final String label;

  const _StatColumn({
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1.0,
              color: Colors.black,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          maxLines: 2,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF9A9A9A),
            fontSize: 9,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _RoundIconButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 4,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          child: Icon(icon, color: Colors.black, size: 18),
        ),
      ),
    );
  }
}

class _ActivitySelector extends StatelessWidget {
  final ActivityType selected;
  final bool enabled;
  final ValueChanged<ActivityType> onSelected;

  const _ActivitySelector({
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ActivityButton(
          icon: Icons.directions_walk_rounded,
          selected: selected == ActivityType.walk,
          enabled: enabled,
          onTap: () => onSelected(ActivityType.walk),
        ),
        const SizedBox(width: 8),
        _ActivityButton(
          icon: Icons.directions_run_rounded,
          selected: selected == ActivityType.run,
          enabled: enabled,
          onTap: () => onSelected(ActivityType.run),
        ),
        const SizedBox(width: 8),
        _ActivityButton(
          icon: Icons.directions_bike_rounded,
          selected: selected == ActivityType.cycle,
          enabled: enabled,
          onTap: () => onSelected(ActivityType.cycle),
        ),
        const SizedBox(width: 8),
        _MoreActivitiesButton(
          enabled: enabled,
          onSelected: onSelected,
        ),
      ],
    );
  }
}

class _ActivityButton extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _ActivityButton({
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: selected ? Colors.black : const Color(0xFFE3E3E3),
              width: selected ? 2 : 1,
            ),
          ),
          child: Icon(icon, size: 22, color: Colors.black),
        ),
      ),
    );
  }
}

class _MoreActivitiesButton extends StatelessWidget {
  final bool enabled;
  final ValueChanged<ActivityType> onSelected;

  const _MoreActivitiesButton({
    required this.enabled,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: enabled ? () {
          // Show dialog with additional activity options
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('More Activities'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.directions_walk_rounded),
                    title: const Text('Walking'),
                    onTap: () {
                      Navigator.of(context).pop();
                      onSelected(ActivityType.walk);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.directions_run_rounded),
                    title: const Text('Running'),
                    onTap: () {
                      Navigator.of(context).pop();
                      onSelected(ActivityType.run);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.directions_bike_rounded),
                    title: const Text('Cycling'),
                    onTap: () {
                      Navigator.of(context).pop();
                      onSelected(ActivityType.cycle);
                    },
                  ),
                ],
              ),
            ),
          );
        } : null,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: const Color(0xFFE3E3E3),
              width: 1,
            ),
          ),
          child: const Center(
            child: Icon(Icons.more_horiz_rounded, size: 22, color: Colors.black),
          ),
        ),
      ),
    );
  }
}

class _StartPauseControl extends StatelessWidget {
  final ActivityTrackingState state;
  final bool isLocked;
  final ValueChanged<bool> onLockToggle;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;
  final VoidCallback onSettingsTap;

  const _StartPauseControl({
    required this.state,
    required this.isLocked,
    required this.onLockToggle,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onStop,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    final isIdle = state is TrackingIdle || state is TrackingCompleted;
    final isInProgress = state is TrackingInProgress;

    if (isIdle) {
      return Row(
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: OutlinedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Music integration coming soon')),
                );
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.black, width: 1),
                shape: const RoundedRectangleBorder(),
                backgroundColor: Colors.white,
                padding: EdgeInsets.zero,
              ),
              child: const Icon(Icons.music_note_rounded, color: Colors.black, size: 20),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: onStart,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'START',
                          style: TextStyle(
                            fontSize: 12,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w900,
                            height: 1.2,
                          ),
                        ),
                        Text(
                          state.activityType.label.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 12,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w900,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const Icon(Icons.arrow_forward_rounded, size: 22),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 52,
            height: 52,
            child: OutlinedButton(
              onPressed: onSettingsTap,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.black, width: 1),
                shape: const RoundedRectangleBorder(),
                backgroundColor: Colors.white,
                padding: EdgeInsets.zero,
              ),
              child: const Icon(Icons.settings_rounded, color: Colors.black, size: 20),
            ),
          ),
        ],
      );
    }

    if (isLocked) {
      return SlidingButton(
        label: 'SLIDE TO UNLOCK',
        onTriggered: () => onLockToggle(false),
      );
    }

    return Row(
      children: [
        SizedBox(
          width: 60,
          height: 52,
          child: OutlinedButton(
            onPressed: onStop,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.black, width: 2),
              shape: const RoundedRectangleBorder(),
              backgroundColor: Colors.white,
            ),
            child: const Icon(Icons.stop_rounded, color: Colors.black, size: 24),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 52,
            child: isInProgress
                ? FilledButton(
              onPressed: onPause,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pause_rounded, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'PAUSE',
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            )
                : FilledButton(
              onPressed: onResume,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'RESUME',
                    style: const TextStyle(
                      fontSize: 12,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded, size: 24),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 52,
          height: 52,
          child: OutlinedButton(
            onPressed: () => onLockToggle(true),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.black, width: 1),
              shape: const RoundedRectangleBorder(),
              backgroundColor: Colors.white,
              padding: EdgeInsets.zero,
            ),
            child: const Icon(Icons.lock_rounded, color: Colors.black, size: 20),
          ),
        ),
      ],
    );
  }
}

/// Full screen shown after an activity is stopped and saved. Displays the
/// finished session's stats with a back button in the top-left corner.
class ActivityCompletionPage extends StatelessWidget {
  final ActivitySession session;
  final VoidCallback onBack;
  final VoidCallback onNewActivity;
  final VoidCallback onViewHistory;

  const ActivityCompletionPage({
    super.key,
    required this.session,
    required this.onBack,
    required this.onNewActivity,
    required this.onViewHistory,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) onBack();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
                child: _RoundIconButton(
                  icon: Icons.arrow_back_rounded,
                  onPressed: onBack,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: _CompletionStats(
                    elapsed: Duration(seconds: session.totalDurationSeconds),
                    distanceMeters: session.totalDistanceMeters,
                    calories: session.calories,
                    avgPace: session.avgPaceSecondsPerKm,
                    steps: session.steps,
                    stepCountReliable: session.stepCountReliable,
                    activityType: session.activityType,
                    onNewActivity: onNewActivity,
                    onViewHistory: onViewHistory,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompletionStats extends StatelessWidget {
  final Duration elapsed;
  final double distanceMeters;
  final int calories;
  final int avgPace;
  final int steps;
  final bool stepCountReliable;
  final ActivityType activityType;
  final VoidCallback onNewActivity;
  final VoidCallback onViewHistory;

  const _CompletionStats({
    required this.elapsed,
    required this.distanceMeters,
    required this.calories,
    required this.avgPace,
    required this.steps,
    required this.stepCountReliable,
    required this.activityType,
    required this.onNewActivity,
    required this.onViewHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(
                activityType.label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF777777),
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                (distanceMeters / 1000).toStringAsFixed(2),
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                  height: 1.0,
                ),
              ),
              const Text(
                'KILOMETERS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF777777),
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _CompletionStatCard(
                icon: Icons.access_time_rounded,
                label: 'Duration',
                value: _formatDuration(elapsed),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _CompletionStatCard(
                icon: Icons.local_fire_department_rounded,
                label: 'Calories',
                value: '$calories',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _CompletionStatCard(
                icon: Icons.speed_rounded,
                label: 'Avg Pace',
                value: _formatPace(avgPace),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _CompletionStatCard(
                icon: Icons.directions_walk_rounded,
                label: 'Steps',
                value: '$steps',
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onViewHistory,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.black, width: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'View History',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: onNewActivity,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'New Activity',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CompletionStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _CompletionStatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE3E3E3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: const Color(0xFF2BC7D8)),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF777777),
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class SlidingButton extends StatefulWidget {
  final String label;
  final VoidCallback onTriggered;

  const SlidingButton({
    super.key,
    required this.label,
    required this.onTriggered,
  });

  @override
  State<SlidingButton> createState() => _SlidingButtonState();
}

class _SlidingButtonState extends State<SlidingButton> {
  double _position = 0.0;
  bool _triggered = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxDistance = constraints.maxWidth - 46 - 8;

        return Container(
          height: 52,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(0),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Center(
                child: Text(
                  widget.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Positioned(
                left: _position,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    if (_triggered) return;
                    setState(() {
                      _position = (_position + details.delta.dx).clamp(0.0, maxDistance);
                    });
                  },
                  onHorizontalDragEnd: (details) {
                    if (_triggered) return;
                    if (_position >= maxDistance * 0.85) {
                      setState(() {
                        _position = maxDistance;
                        _triggered = true;
                      });
                      widget.onTriggered();
                      Future.delayed(const Duration(milliseconds: 500), () {
                        if (mounted) {
                          setState(() {
                            _position = 0.0;
                            _triggered = false;
                          });
                        }
                      });
                    } else {
                      setState(() {
                        _position = 0.0;
                      });
                    }
                  },
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.rectangle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.black,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours.toString().padLeft(2, '0');
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}

String _formatPace(int secondsPerKm) {
  if (secondsPerKm <= 0) return '00:00';
  final minutes = (secondsPerKm ~/ 60).toString().padLeft(2, '0');
  final seconds = (secondsPerKm % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

class _ZoomResetButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _ZoomResetButton({
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 4,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.my_location_rounded,
            color: Colors.black,
            size: 18,
          ),
        ),
      ),
    );
  }
}

class _OfflineMapIcon extends StatelessWidget {
  final bool isReady;
  final bool isDownloading;
  final double progress;
  final VoidCallback onTap;

  const _OfflineMapIcon({
    required this.isReady,
    required this.isDownloading,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;

    if (isReady) {
      icon = Icons.offline_pin_rounded;
      color = const Color(0xFF47B85A);
    } else if (isDownloading) {
      icon = Icons.downloading_rounded;
      color = const Color(0xFF2BC7D8);
    } else {
      icon = Icons.download_for_offline_rounded;
      color = const Color(0xFF777777);
    }

    return GestureDetector(
      onTap: onTap,
      child: Icon(
        icon,
        color: color,
        size: 24,
      ),
    );
  }
}