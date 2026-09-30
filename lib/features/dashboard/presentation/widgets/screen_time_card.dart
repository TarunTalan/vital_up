import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import '../cubit/screen_time_cubit.dart';
import '../cubit/screen_time_state.dart';
import '../../domain/entities/app_usage_info.dart';
import 'dashboard_card_header.dart';

const _title = 'Screen Time';
const _icon = 'assets/icons/devices.svg';

class ScreenTimeCard extends StatelessWidget {
  const ScreenTimeCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      width: double.infinity,
      child: BlocBuilder<ScreenTimeCubit, ScreenTimeState>(
        builder: (context, state) {
          if (state is ScreenTimeLoading || state is ScreenTimeInitial) {
            return const DashboardCardLoading();
          } else if (state is ScreenTimePermissionDenied) {
            return _buildPermissionState(context);
          } else if (state is ScreenTimeError) {
            return _buildErrorState(context, state.message);
          } else if (state is ScreenTimeLoaded) {
            return _buildLoadedState(context, state);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildPermissionState(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DashboardCardHeader(title: _title, iconAsset: _icon),
        const SizedBox(height: AppDimens.cardInnerGap),
        Text('Permission Required', style: context.text.titleSmall),
        const SizedBox(height: AppDimens.space8),
        Text(
          'To track your screen time, please grant Usage Access permission in settings.',
          style: context.text.bodyMedium
              ?.copyWith(color: context.vColors.grayText),
        ),
        const SizedBox(height: AppDimens.cardInnerGap),
        AppPrimaryButton(
          label: 'Grant Permission',
          expand: false,
          onTap: () => context.read<ScreenTimeCubit>().openSettings(),
        ),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context, String message) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DashboardCardHeader(title: _title, iconAsset: _icon),
        const SizedBox(height: AppDimens.cardInnerGap),
        Text(
          'Error loading data',
          style: context.text.bodyMedium?.copyWith(color: context.colors.error),
        ),
        const SizedBox(height: AppDimens.space8),
        Text(
          message,
          style: context.text.bodySmall
              ?.copyWith(color: context.vColors.grayText),
        ),
      ],
    );
  }

  Widget _buildLoadedState(BuildContext context, ScreenTimeLoaded state) {
    final topApps = state.usageStats.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DashboardCardHeader(title: _title, iconAsset: _icon),
        const SizedBox(height: AppDimens.cardInnerGap),
        DashboardMetric(formatDashboardDuration(state.totalDuration)),
        const SizedBox(height: AppDimens.cardInnerGap),
        _TopAppsList(topApps: topApps),
      ],
    );
  }
}

class _TopAppsList extends StatefulWidget {
  final List<AppUsageInfo> topApps;

  const _TopAppsList({required this.topApps});

  @override
  State<_TopAppsList> createState() => _TopAppsListState();
}

class _TopAppsListState extends State<_TopAppsList> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final grey = context.vColors.grayText;

    if (widget.topApps.isEmpty) {
      return Text(
        'No usage data available.',
        style: context.text.bodyMedium?.copyWith(color: grey),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppDimens.space4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Top Apps Today',
                    style: context.text.bodyMedium?.copyWith(color: grey),
                  ),
                ),
                Icon(
                  _isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: grey,
                ),
              ],
            ),
          ),
        ),
        if (_isExpanded) ...[
          const SizedBox(height: AppDimens.space8),
          ...widget.topApps.map((app) => _buildAppRow(context, app)),
        ],
      ],
    );
  }

  Widget _buildAppRow(BuildContext context, AppUsageInfo app) {
    final primary = context.colors.primary;
    final initial = app.appName.isNotEmpty ? app.appName[0].toUpperCase() : '?';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.space6),
      child: Row(
        children: [
          AppIconBadge(
            size: AppDimens.iconLg,
            color: primary,
            icon: Text(
              initial,
              style: context.text.labelSmall?.copyWith(
                color: primary,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: AppDimens.space8),
          Expanded(
            child: Text(
              app.appName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodyMedium
                  ?.copyWith(color: context.colors.onSurface),
            ),
          ),
          const SizedBox(width: AppDimens.space8),
          Text(
            formatDashboardDuration(app.usageDuration),
            style: context.text.bodySmall?.copyWith(
              color: context.vColors.grayText,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
