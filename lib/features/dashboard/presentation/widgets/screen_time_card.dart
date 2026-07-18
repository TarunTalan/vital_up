import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../cubit/screen_time_cubit.dart';
import '../cubit/screen_time_state.dart';
import '../../domain/entities/app_usage_info.dart';

class ScreenTimeCard extends StatelessWidget {
  const ScreenTimeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: const Color(0xFFD8D8D8).withValues(alpha: 0.78),
        ),
      ),
      child: BlocBuilder<ScreenTimeCubit, ScreenTimeState>(
        builder: (context, state) {
          if (state is ScreenTimeLoading || state is ScreenTimeInitial) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: CircularProgressIndicator(),
              ),
            );
          } else if (state is ScreenTimePermissionDenied) {
            return _buildPermissionState(context, theme, colors);
          } else if (state is ScreenTimeError) {
            return _buildErrorState(context, theme, state.message);
          } else if (state is ScreenTimeLoaded) {
            return _buildLoadedState(context, theme, colors, state);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildPermissionState(BuildContext context, ThemeData theme, ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(theme, 'Screen Time', 'assets/icons/Watch.svg'),
        const SizedBox(height: 24),
        Text(
          'Permission Required',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'To track your screen time, please grant Usage Access permission in settings.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: const Color(0xFF777777),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () {
            context.read<ScreenTimeCubit>().openSettings();
          },
          style: FilledButton.styleFrom(
            backgroundColor: colors.primary,
          ),
          child: const Text('Grant Permission'),
        ),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context, ThemeData theme, String message) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(theme, 'Screen Time', 'assets/icons/Watch.svg'),
        const SizedBox(height: 16),
        Text(
          'Error loading data',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF777777)),
        ),
      ],
    );
  }

  Widget _buildLoadedState(BuildContext context, ThemeData theme, ColorScheme colors, ScreenTimeLoaded state) {
    final String formattedTotal = _formatDuration(state.totalDuration);
    final topApps = state.usageStats.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(theme, 'Screen Time', 'assets/icons/Watch.svg'),
        const SizedBox(height: 24),
        Text(
          formattedTotal,
          style: theme.textTheme.displayLarge?.copyWith(
            fontSize: 36,
            height: 1,
            fontWeight: FontWeight.w300,
            color: const Color(0xFF111111),
          ),
        ),
        const SizedBox(height: 16),
        _TopAppsList(
          topApps: topApps,
          theme: theme,
          colors: colors,
        ),
      ],
    );
  }

  Widget _buildHeader(ThemeData theme, String title, String iconAsset) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: Color(0xFFD8F2DC),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: SvgPicture.asset(
              iconAsset,
              width: 23,
              height: 23,
              colorFilter: const ColorFilter.mode(
                Color(0xFF111111),
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF161616),
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
}

class _TopAppsList extends StatefulWidget {
  final List<AppUsageInfo> topApps;
  final ThemeData theme;
  final ColorScheme colors;

  const _TopAppsList({
    required this.topApps,
    required this.theme,
    required this.colors,
  });

  @override
  State<_TopAppsList> createState() => _TopAppsListState();
}

class _TopAppsListState extends State<_TopAppsList> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.topApps.isEmpty) {
      return Text(
        'No usage data available.',
        style: widget.theme.textTheme.bodySmall?.copyWith(
          fontSize: 14,
          color: const Color(0xFF777777),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Top Apps Today',
                  style: widget.theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF161616),
                  ),
                ),
                Icon(
                  _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: const Color(0xFF777777),
                ),
              ],
            ),
          ),
        ),
        if (_isExpanded) ...[
          const SizedBox(height: 8),
          ...widget.topApps.map((app) => _buildAppRow(widget.theme, widget.colors, app)),
        ],
      ],
    );
  }

  Widget _buildAppRow(ThemeData theme, ColorScheme colors, AppUsageInfo app) {
    final initial = app.appName.isNotEmpty ? app.appName[0].toUpperCase() : '?';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: colors.primary.withValues(alpha: 0.2),
            child: Text(
              initial,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              app.appName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF111111),
              ),
            ),
          ),
          Text(
            _formatDuration(app.usageDuration),
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFF777777),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
}
