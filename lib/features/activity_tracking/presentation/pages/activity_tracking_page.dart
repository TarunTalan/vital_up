import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart' hide ActivityType;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;
import 'package:vital_up/core/config/supabase_config.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/features/activity_tracking/domain/repositories/map_tile_repository.dart';
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
  bool _isCheckingOfflineMap = true;
  bool _isDownloadingMap = false;
  double _mapDownloadProgress = 0.0;

  mbx.MapboxMap? _mapboxMap;
  mbx.PolylineAnnotationManager? _polylineAnnotationManager;
  mbx.PointAnnotationManager? _pointAnnotationManager;

  @override
  void initState() {
    super.initState();
    _checkOfflineMap();
  }

  Future<void> _checkOfflineMap() async {
    final mapRepo = sl<MapTileRepository>();
    final exists = await mapRepo.checkRegionDownloaded(kOfflineRegionId);
    if (mounted) {
      setState(() {
        _isOfflineMapReady = exists;
        _isCheckingOfflineMap = false;
      });
    }
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

  void _onMapCreated(mbx.MapboxMap map) async {
    _mapboxMap = map;
    
    // Set map style
    await map.loadStyleURI(mbx.MapboxStyles.MAPBOX_STREETS);

    // Create annotation managers
    _polylineAnnotationManager = await map.annotations.createPolylineAnnotationManager();
    _pointAnnotationManager = await map.annotations.createPointAnnotationManager();

    // Center camera on user's current location initially
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      _centerCamera(position.latitude, position.longitude);
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

  void _updatePuck(TrackPoint? point) {
    if (_pointAnnotationManager == null || point == null) return;

    _pointAnnotationManager!.deleteAll();

    _pointAnnotationManager!.create(mbx.PointAnnotationOptions(
      geometry: mbx.Point(coordinates: mbx.Position(point.longitude, point.latitude)),
      iconColor: const Color(0xFF3BB5C8).toARGB32(),
      iconSize: 1.5,
    ));
  }

  void _centerCamera(double lat, double lng) {
    _mapboxMap?.setCamera(mbx.CameraOptions(
      center: mbx.Point(coordinates: mbx.Position(lng, lat)),
      zoom: 15.0,
    ));
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
          _updateRoute(state.routePoints);
          if (state.routePoints.isNotEmpty) {
            _updatePuck(state.routePoints.last);
            _centerCamera(state.routePoints.last.latitude, state.routePoints.last.longitude);
          }
        } else if (state is TrackingPaused) {
          _updateRoute(state.routePoints);
          if (state.routePoints.isNotEmpty) {
            _updatePuck(state.routePoints.last);
          }
        } else if (state is TrackingCompleted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Workout saved successfully!')),
          );
          Navigator.of(context).pop();
        }
      },
      builder: (context, state) {
        final bloc = context.read<ActivityTrackingBloc>();

        Duration elapsed = Duration.zero;
        double distanceMeters = 0.0;
        int calories = 0;
        int avgPace = 0;
        int steps = 0;
        bool stepCountReliable = true;

        if (state is TrackingInProgress) {
          elapsed = state.elapsed;
          distanceMeters = state.distanceMeters;
          calories = state.calories;
          avgPace = state.avgPaceSecondsPerKm;
          steps = state.steps;
          stepCountReliable = state.stepCountReliable;
        } else if (state is TrackingPaused) {
          elapsed = state.elapsed;
          distanceMeters = state.distanceMeters;
          calories = state.calories;
          avgPace = state.avgPaceSecondsPerKm;
          steps = state.steps;
          stepCountReliable = state.stepCountReliable;
        }

        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _TopStats(
                  elapsed: elapsed,
                  distanceMeters: distanceMeters,
                  calories: calories,
                  avgPace: avgPace,
                  steps: steps,
                  stepCountReliable: stepCountReliable,
                  onBack: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: mbx.MapWidget(
                          key: const ValueKey("mapWidget"),
                          onMapCreated: _onMapCreated,
                        ),
                      ),
                      Positioned(
                        left: 16,
                        right: 16,
                        top: 16,
                        child: _OfflineMapStatus(
                          isChecking: _isCheckingOfflineMap,
                          isReady: _isOfflineMapReady,
                          isDownloading: _isDownloadingMap,
                          progress: _mapDownloadProgress,
                          onDownload: _downloadOfflineMap,
                        ),
                      ),
                      Positioned(
                        left: 24,
                        right: 24,
                        bottom: 28,
                        child: Column(
                          children: [
                            _ActivitySelector(
                              selected: state.activityType,
                              enabled: state is TrackingIdle,
                              onSelected: (type) => bloc.add(SelectActivityType(type)),
                            ),
                            const SizedBox(height: 16),
                            _StartPauseControl(
                              state: state,
                              onStart: () => bloc.add(StartTracking()),
                              onPause: () => bloc.add(PauseTracking()),
                              onResume: () => bloc.add(ResumeTracking()),
                              onStop: () => bloc.add(StopAndSaveTracking()),
                            ),
                          ],
                        ),
                      ),
                    ],
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

class _OfflineMapStatus extends StatelessWidget {
  final bool isChecking;
  final bool isReady;
  final bool isDownloading;
  final double progress;
  final VoidCallback onDownload;

  const _OfflineMapStatus({
    required this.isChecking,
    required this.isReady,
    required this.isDownloading,
    required this.progress,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    if (isReady) {
      return const _MapStatusPill(
        icon: Icons.offline_pin_rounded,
        label: 'Offline map ready',
        color: Color(0xFF47B85A),
      );
    }

    if (isChecking) {
      return const _MapStatusPill(
        icon: Icons.map_rounded,
        label: 'Checking offline map',
        color: Color(0xFF777777),
      );
    }

    if (isDownloading) {
      return _MapStatusPill(
        icon: Icons.downloading_rounded,
        label: 'Caching map ${((progress.clamp(0.0, 1.0)) * 100).toStringAsFixed(0)}%',
        color: const Color(0xFF2BC7D8),
      );
    }

    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      elevation: 2,
      child: InkWell(
        onTap: onDownload,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.download_for_offline_rounded, size: 20, color: Colors.black),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Track now. Tap to cache map for offline use.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
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

class _MapStatusPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MapStatusPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          border: Border.all(color: const Color(0xFFE3E3E3)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopStats extends StatelessWidget {
  final Duration elapsed;
  final double distanceMeters;
  final int calories;
  final int avgPace;
  final int steps;
  final bool stepCountReliable;
  final VoidCallback onBack;

  const _TopStats({
    required this.elapsed,
    required this.distanceMeters,
    required this.calories,
    required this.avgPace,
    required this.steps,
    required this.stepCountReliable,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 20),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded, size: 30),
              ),
              const Spacer(),
              const Text(
                'VITALUP',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  fontSize: 18,
                ),
              ),
              const Spacer(),
              const Icon(Icons.gps_fixed_rounded, color: Color(0xFF47B85A)),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            _formatDuration(elapsed),
            style: const TextStyle(
              fontSize: 58,
              fontWeight: FontWeight.w900,
              height: 0.95,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'DURATION',
            style: TextStyle(
              color: Color(0xFF777777),
              fontSize: 15,
              letterSpacing: 5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 28),
          Wrap(
            runSpacing: 18,
            children: [
              _StatBlock(
                value: (distanceMeters / 1000).toStringAsFixed(2),
                label: 'DISTANCE (KM)',
              ),
              _StatBlock(
                value: calories.toString(),
                label: 'CALORIES (CAL)',
              ),
              _StatBlock(
                value: _formatPace(avgPace),
                label: 'AVG. PACE (MIN/KM)',
              ),
              _StatBlock(
                value: steps.toString(),
                label: stepCountReliable ? 'STEPS' : 'STEPS (EST.)',
                reliable: stepCountReliable,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final String value;
  final String label;
  final bool reliable;

  const _StatBlock({
    required this.value,
    required this.label,
    this.reliable = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.sizeOf(context).width / 2 - 22,
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            style: TextStyle(
              fontSize: 35,
              fontWeight: FontWeight.w900,
              color: reliable ? Colors.black : const Color(0xFF777777),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: reliable ? const Color(0xFF777777) : const Color(0xFF9A9A9A),
              fontSize: 13,
              letterSpacing: 2.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
        const SizedBox(width: 14),
        _ActivityButton(
          icon: Icons.directions_run_rounded,
          selected: selected == ActivityType.run,
          enabled: enabled,
          onTap: () => onSelected(ActivityType.run),
        ),
        const SizedBox(width: 14),
        _ActivityButton(
          icon: Icons.directions_bike_rounded,
          selected: selected == ActivityType.cycle,
          enabled: enabled,
          onTap: () => onSelected(ActivityType.cycle),
        ),
        const SizedBox(width: 14),
        _ActivityButton(
          icon: Icons.more_horiz_rounded,
          selected: false,
          enabled: false,
          onTap: () {},
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
          height: 58,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: selected ? Colors.black : const Color(0xFFE3E3E3),
              width: selected ? 2 : 1,
            ),
          ),
          child: Icon(icon, size: 30, color: Colors.black),
        ),
      ),
    );
  }
}

class _StartPauseControl extends StatelessWidget {
  final ActivityTrackingState state;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;

  const _StartPauseControl({
    required this.state,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final isIdle = state is TrackingIdle;
    final isInProgress = state is TrackingInProgress;

    return Row(
      children: [
        if (!isIdle) ...[
          SizedBox(
            width: 82,
            height: 70,
            child: OutlinedButton(
              onPressed: onStop,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.black, width: 2),
                shape: const RoundedRectangleBorder(),
                backgroundColor: Colors.white,
              ),
              child: const Icon(Icons.stop_rounded, color: Colors.black, size: 32),
            ),
          ),
          const SizedBox(width: 14),
        ],
        Expanded(
          child: SizedBox(
            height: 70,
            child: isIdle
                ? FilledButton(
                    onPressed: onStart,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'START ${state.activityType.label.toUpperCase()}',
                          style: const TextStyle(
                            fontSize: 16,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Icon(Icons.arrow_forward_rounded, size: 34),
                      ],
                    ),
                  )
                : isInProgress
                    ? SlidingButton(
                        label: 'SLIDE TO PAUSE',
                        onTriggered: onPause,
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
                              'RESUME ${state.activityType.label.toUpperCase()}',
                              style: const TextStyle(
                                fontSize: 16,
                                letterSpacing: 2,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const Icon(Icons.arrow_forward_rounded, size: 34),
                          ],
                        ),
                      ),
          ),
        ),
      ],
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
        final double maxDistance = constraints.maxWidth - 58 - 8;

        return Container(
          height: 70,
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
                    fontSize: 16,
                    letterSpacing: 2,
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
                    width: 58,
                    height: 58,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.rectangle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.black,
                      size: 28,
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
