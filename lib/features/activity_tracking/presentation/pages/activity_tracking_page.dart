import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/track_point.dart';
import 'package:vital_up/features/activity_tracking/presentation/cubit/activity_tracking_cubit.dart';
import 'package:vital_up/features/activity_tracking/presentation/cubit/activity_tracking_state.dart';

class ActivityTrackingPage extends StatelessWidget {
  const ActivityTrackingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ActivityTrackingCubit>(),
      child: const _ActivityTrackingView(),
    );
  }
}

class _ActivityTrackingView extends StatelessWidget {
  const _ActivityTrackingView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ActivityTrackingCubit, ActivityTrackingState>(
      listener: (context, state) {
        if (state.message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message!)),
          );
        }
      },
      builder: (context, state) {
        final cubit = context.read<ActivityTrackingCubit>();

        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _TopStats(
                  state: state,
                  onBack: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _OfflineRouteMapPainter(state.routePoints),
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
                              enabled: state.status == TrackingStatus.idle ||
                                  state.status == TrackingStatus.completed,
                              onSelected: cubit.selectActivityType,
                            ),
                            const SizedBox(height: 16),
                            _StartPauseControl(
                              state: state,
                              onStart: cubit.start,
                              onPause: cubit.pause,
                              onResume: cubit.resume,
                              onReset: cubit.reset,
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

class _TopStats extends StatelessWidget {
  final ActivityTrackingState state;
  final VoidCallback onBack;

  const _TopStats({
    required this.state,
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
            _formatDuration(state.elapsed),
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
          Row(
            children: [
              Expanded(
                child: _StatBlock(
                  value: (state.distanceMeters / 1000).toStringAsFixed(2),
                  label: 'DISTANCE (KM)',
                ),
              ),
              Expanded(
                child: _StatBlock(
                  value: state.calories.toString(),
                  label: 'CALORIES (CAL)',
                ),
              ),
              Expanded(
                child: _StatBlock(
                  value: _formatPace(state.avgPaceSecondsPerKm),
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

class _StatBlock extends StatelessWidget {
  final String value;
  final String label;

  const _StatBlock({
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          maxLines: 1,
          style: const TextStyle(
            fontSize: 35,
            fontWeight: FontWeight.w900,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF777777),
            fontSize: 13,
            letterSpacing: 2.4,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
  final VoidCallback onReset;

  const _StartPauseControl({
    required this.state,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final isStarted = state.status == TrackingStatus.inProgress;
    final isPaused = state.status == TrackingStatus.paused;
    final isLoading = state.status == TrackingStatus.starting;

    return Row(
      children: [
        SizedBox(
          width: 82,
          height: 70,
          child: OutlinedButton(
            onPressed: onReset,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.black, width: 2),
              shape: const RoundedRectangleBorder(),
              backgroundColor: Colors.white,
            ),
            child: const Icon(Icons.library_music_outlined, color: Colors.black),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: SizedBox(
            height: 70,
            child: FilledButton(
              onPressed: isLoading
                  ? null
                  : isStarted
                      ? onPause
                      : isPaused
                          ? onResume
                          : onStart,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.black,
                shape: const RoundedRectangleBorder(),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isLoading
                          ? 'STARTING'
                          : isStarted
                              ? 'SLIDE TO PAUSE'
                              : isPaused
                                  ? 'RESUME ${state.activityType.label.toUpperCase()}'
                                  : 'START ${state.activityType.label.toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 16,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded, size: 34),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        SizedBox(
          width: 82,
          height: 70,
          child: OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.black, width: 2),
              shape: const RoundedRectangleBorder(),
              backgroundColor: Colors.white,
            ),
            child: const Icon(Icons.settings_outlined, color: Colors.black),
          ),
        ),
      ],
    );
  }
}

class _OfflineRouteMapPainter extends CustomPainter {
  final List<TrackPoint> points;

  _OfflineRouteMapPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFFF4F1EA);
    canvas.drawRect(Offset.zero & size, bgPaint);

    _drawOfflineGrid(canvas, size);

    final routePaint = Paint()
      ..color = const Color(0xFF2BC7D8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final projected = _projectPoints(size);
    if (projected.length > 1) {
      final path = Path()..moveTo(projected.first.dx, projected.first.dy);
      for (final point in projected.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, routePaint);
    }

    final puck = projected.isNotEmpty
        ? projected.last
        : Offset(size.width * 0.52, size.height * 0.48);
    canvas.drawCircle(
      puck,
      18,
      Paint()..color = const Color(0xFF3BB5C8).withValues(alpha: 0.25),
    );
    canvas.drawCircle(puck, 10, Paint()..color = Colors.white);
    canvas.drawCircle(puck, 7, Paint()..color = const Color(0xFF3BB5C8));
  }

  void _drawOfflineGrid(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = const Color(0xFFD7E3EA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final mainRoadPaint = Paint()
      ..color = const Color(0xFF81D4E4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;

    for (var i = -4; i < 10; i++) {
      final x = i * size.width / 7;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.width * 0.55, size.height),
        roadPaint,
      );
    }
    for (var i = 0; i < 8; i++) {
      final y = i * size.height / 7;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y - size.height * 0.25),
        roadPaint,
      );
    }

    final main = Path()
      ..moveTo(size.width * 0.1, size.height)
      ..quadraticBezierTo(
        size.width * 0.48,
        size.height * 0.45,
        size.width * 0.74,
        0,
      );
    canvas.drawPath(main, mainRoadPaint);
    canvas.drawPath(
      main,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.70)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  List<Offset> _projectPoints(Size size) {
    if (points.isEmpty) return [];
    if (points.length == 1) {
      return [Offset(size.width * 0.52, size.height * 0.48)];
    }

    final minLat = points.map((p) => p.latitude).reduce(min);
    final maxLat = points.map((p) => p.latitude).reduce(max);
    final minLng = points.map((p) => p.longitude).reduce(min);
    final maxLng = points.map((p) => p.longitude).reduce(max);
    final latSpan = max(0.0001, maxLat - minLat);
    final lngSpan = max(0.0001, maxLng - minLng);

    return points.map((point) {
      final x = ((point.longitude - minLng) / lngSpan) * size.width;
      final y = size.height - ((point.latitude - minLat) / latSpan) * size.height;
      return Offset(
        x.clamp(32, size.width - 32).toDouble(),
        y.clamp(32, size.height - 32).toDouble(),
      );
    }).toList();
  }

  @override
  bool shouldRepaint(covariant _OfflineRouteMapPainter oldDelegate) {
    return oldDelegate.points != points;
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
