import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/app_segmented_control.dart';
import 'package:vital_up/core/widgets/load_error_view.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:vital_up/core/utils/load_timeout.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/features/weight/data/weight_service.dart';
import '../../data/services/health_report_service.dart';

class HealthReportPage extends StatefulWidget {
  const HealthReportPage({super.key});

  @override
  State<HealthReportPage> createState() => _HealthReportPageState();
}

class _HealthReportPageState extends State<HealthReportPage> {
  int _selectedDays = 30;
  bool _isLoading = true;
  bool _isExporting = false;
  bool _failed = false;
  HealthReportSummary? _summary;
  WeightUnit _unit = WeightUnit.kg;

  /// Bumped per load so a slow earlier period can't replace a newer one.
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    final request = ++_request;
    final days = _selectedDays;
    setState(() {
      _isLoading = true;
      _failed = false;
    });
    try {
      final summary = await sl<HealthReportService>()
          .generateSummary(days: days)
          .withLoadTimeout();
      final unit = await sl<WeightService>().unit();
      if (!mounted || request != _request) return;
      setState(() {
        _summary = summary;
        _unit = unit;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Health report failed: $e');
      if (!mounted || request != _request) return;
      setState(() {
        _summary = null;
        _isLoading = false;
        _failed = true;
      });
    }
  }

  Future<void> _exportReport() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    HapticFeedback.mediumImpact();
    try {
      await sl<HealthReportService>().exportAndShareReport(
        days: _selectedDays,
        summary: _summary,
      );
    } catch (e) {
      debugPrint('Health report share failed: $e');
      if (mounted) {
        showErrorSnackBar(context, "Couldn't share the report. Try again.");
      }
    }
    if (mounted) setState(() => _isExporting = false);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      header: const AppPageHeader(
        title: 'Doctor Health Report',
        subtitle: 'Comprehensive clinical vital summary',
      ),
      padBody: false,
      scrollable: true,
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          context.gutter,
          AppDimens.sectionGap,
          context.gutter,
          AppDimens.sectionGap + context.safePadding.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Time Horizon Filter
            AppCaption('TIME HORIZON'),
            const SizedBox(height: AppDimens.space8),
            AppSegmentedControl<int>(
              values: const [7, 30, 90],
              selected: _selectedDays,
              label: (days) => 'Last $days Days',
              onChanged: (days) {
                if (_selectedDays != days) {
                  setState(() => _selectedDays = days);
                  _loadReport();
                  HapticFeedback.selectionClick();
                }
              },
            ),
            const SizedBox(height: AppDimens.space16),

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: AppDimens.space40),
                  child: VitalUpLoader(),
                ),
              )
            else if (_failed || _summary == null)
              LoadErrorView(onRetry: _loadReport)
            else ...[
              // 2. Patient & Vitals Card
              _buildVitalsCard(context, _summary!),
              const SizedBox(height: AppDimens.space12),

              // 3. Sleep & Recovery Card
              _buildSleepReportCard(context, _summary!),
              const SizedBox(height: AppDimens.space12),

              // 4. Physical Activity Card
              _buildActivityReportCard(context, _summary!),
              const SizedBox(height: AppDimens.space12),

              // 5. Hydration Card
              _buildHydrationReportCard(context, _summary!),
              const SizedBox(height: AppDimens.sectionGap),

              // 6. Export CTA Button
              AppPrimaryButton(
                label: _isExporting
                    ? 'Generating Report...'
                    : 'Share Report with Doctor',
                leadingIcon: const Icon(
                  Icons.share_rounded,
                  size: AppDimens.iconSm,
                ),
                enabled: !_isExporting,
                onTap: _exportReport,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVitalsCard(BuildContext context, HealthReportSummary s) {
    final v = context.vColors;
    final p = s.profile;

    return AppCard(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppIconBadge(
                color: AppColors.error,
                icon: Icon(Icons.favorite_rounded),
              ),
              const SizedBox(width: AppDimens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p?.fullName.isNotEmpty == true
                          ? p!.fullName
                          : 'Patient Profile',
                      style: context.text.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Resting Cardiovascular Vitals',
                      style: context.text.bodySmall?.copyWith(
                        color: v.grayText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.space16),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  context,
                  label: 'Blood Pressure',
                  value: reportValue(s.bloodPressure, (v) => '$v mmHg'),
                  icon: Icons.speed_rounded,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(width: AppDimens.space8),
              Expanded(
                child: _buildMetricTile(
                  context,
                  label: 'Resting BPM',
                  value: reportValue(s.restingBpm, (v) => '$v bpm'),
                  icon: Icons.monitor_heart_rounded,
                  color: AppColors.teal,
                ),
              ),
            ],
          ),
          if (s.latestWeightKg case final kg?) ...[
            const SizedBox(height: AppDimens.space8),
            _buildMetricTile(
              context,
              label: 'Recorded Body Weight',
              value: _unit.format(kg),
              icon: Icons.monitor_weight_rounded,
              svgAsset: 'assets/icons/trackers/weight_icon.svg',
              color: AppColors.primary,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSleepReportCard(BuildContext context, HealthReportSummary s) {
    return AppCard(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppIconBadge(
                color: AppColors.sleep,
                icon: Icon(Icons.bedtime_rounded),
              ),
              const SizedBox(width: AppDimens.space12),
              Text(
                'Sleep & Recovery Trends',
                style: context.text.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.space12),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  context,
                  label: 'Daily Sleep Avg',
                  value: reportValue(
                    s.avgSleepHours,
                    (v) => '${(v as double).toStringAsFixed(1)} hrs',
                  ),
                  icon: Icons.bedtime_rounded,
                  color: AppColors.sleep,
                ),
              ),
              const SizedBox(width: AppDimens.space8),
              Expanded(
                child: _buildMetricTile(
                  context,
                  label: 'Sleep Quality Score',
                  value: reportValue(s.avgSleepScore, (v) => '$v / 100'),
                  icon: Icons.star_half_rounded,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityReportCard(BuildContext context, HealthReportSummary s) {
    return AppCard(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppIconBadge(
                color: AppColors.primary,
                icon: Icon(Icons.directions_run_rounded),
              ),
              const SizedBox(width: AppDimens.space12),
              Text(
                'Physical Activity & Cardio',
                style: context.text.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.space12),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  context,
                  label: 'Total Sessions',
                  value: '${s.totalWorkouts}',
                  icon: Icons.fitness_center_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppDimens.space8),
              Expanded(
                child: _buildMetricTile(
                  context,
                  label: 'Active Time',
                  value: '${s.totalActiveMinutes} mins',
                  icon: Icons.timer_rounded,
                  color: AppColors.teal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHydrationReportCard(
    BuildContext context,
    HealthReportSummary s,
  ) {
    return AppCard(
      width: double.infinity,
      child: Row(
        children: [
          const AppIconBadge(
            color: AppColors.water,
            icon: Icon(Icons.water_drop_rounded),
          ),
          const SizedBox(width: AppDimens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hydration Consistency',
                  style: context.text.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  s.avgWaterMl == null
                      ? notRecorded
                      : 'Average: ${s.avgWaterMl} ml / day',
                  style: context.text.bodySmall?.copyWith(
                    color: AppColors.water,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required String label,
    required String value,
    IconData? icon,
    String? svgAsset,
    required Color color,
  }) {
    final v = context.vColors;

    return Container(
      padding: const EdgeInsets.all(AppDimens.space10),
      decoration: BoxDecoration(
        color: v.glassFill,
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        border: Border.all(color: v.glassBorder ?? AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (svgAsset != null)
                SvgPicture.asset(
                  svgAsset,
                  width: AppDimens.iconXs,
                  height: AppDimens.iconXs,
                  colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                )
              else if (icon != null)
                Icon(icon, size: AppDimens.iconXs, color: color),
              const SizedBox(width: AppDimens.space4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelSmall?.copyWith(color: v.grayText),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.space4),
          Text(
            value,
            style: context.text.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
