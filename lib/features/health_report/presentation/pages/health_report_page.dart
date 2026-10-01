import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
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
  HealthReportSummary? _summary;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    final service = sl<HealthReportService>();
    final summary = await service.generateSummary(days: _selectedDays);
    if (mounted) {
      setState(() {
        _summary = summary;
        _isLoading = false;
      });
    }
  }

  Future<void> _exportReport() async {
    setState(() => _isExporting = true);
    HapticFeedback.mediumImpact();
    await sl<HealthReportService>().exportAndShareReport(days: _selectedDays);
    if (mounted) setState(() => _isExporting = false);
  }

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;

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
            Row(
              children: [7, 30, 90].map((days) {
                final isSelected = _selectedDays == days;
                return Padding(
                  padding: const EdgeInsets.only(right: AppDimens.space8),
                  child: ChoiceChip(
                    label: Text('Last $days Days'),
                    selected: isSelected,
                    selectedColor: AppColors.primary.withAlpha(45),
                    backgroundColor: v.glassFill,
                    side: BorderSide(
                      color: isSelected
                          ? AppColors.primary
                          : (v.glassBorder ?? Colors.transparent),
                    ),
                    labelStyle: context.text.bodySmall?.copyWith(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? AppColors.primary
                          : context.colors.onSurface,
                    ),
                    onSelected: (selected) {
                      if (selected && _selectedDays != days) {
                        setState(() => _selectedDays = days);
                        _loadReport();
                        HapticFeedback.selectionClick();
                      }
                    },
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppDimens.space16),

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40.0),
                  child: VitalUpLoader(),
                ),
              )
            else if (_summary != null) ...[
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
                label: _isExporting ? 'Generating Report...' : 'Share Report with Doctor 📄',
                leadingIcon: const Icon(Icons.share_rounded, size: AppDimens.iconSm),
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
      padding: const EdgeInsets.all(AppDimens.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppDimens.space8),
                decoration: BoxDecoration(
                  color: AppColors.error.withAlpha(25),
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: AppColors.error,
                  size: AppDimens.iconMd,
                ),
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
                      style: context.text.bodySmall?.copyWith(color: v.grayText),
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
                  value: '${s.bloodPressure} mmHg',
                  icon: Icons.speed_rounded,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(width: AppDimens.space8),
              Expanded(
                child: _buildMetricTile(
                  context,
                  label: 'Resting BPM',
                  value: '${s.restingBpm} bpm',
                  icon: Icons.monitor_heart_rounded,
                  color: AppColors.teal,
                ),
              ),
            ],
          ),
          if (s.latestWeightKg != null) ...[
            const SizedBox(height: AppDimens.space8),
            _buildMetricTile(
              context,
              label: 'Recorded Body Weight',
              value: '${s.latestWeightKg!.toStringAsFixed(1)} kg',
              icon: Icons.monitor_weight_rounded,
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
      padding: const EdgeInsets.all(AppDimens.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppDimens.space8),
                decoration: BoxDecoration(
                  color: AppColors.sleep.withAlpha(25),
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                ),
                child: const Icon(
                  Icons.bedtime_rounded,
                  color: AppColors.sleep,
                  size: AppDimens.iconMd,
                ),
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
                  value: '${s.avgSleepHours.toStringAsFixed(1)} hrs',
                  icon: Icons.nightlight_round,
                  color: AppColors.sleep,
                ),
              ),
              const SizedBox(width: AppDimens.space8),
              Expanded(
                child: _buildMetricTile(
                  context,
                  label: 'Sleep Quality Score',
                  value: '${s.avgSleepScore} / 100',
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
      padding: const EdgeInsets.all(AppDimens.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppDimens.space8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                ),
                child: const Icon(
                  Icons.directions_run_rounded,
                  color: AppColors.primary,
                  size: AppDimens.iconMd,
                ),
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

  Widget _buildHydrationReportCard(BuildContext context, HealthReportSummary s) {
    return AppCard(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimens.space16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppDimens.space10),
            decoration: BoxDecoration(
              color: AppColors.water.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.water_drop_rounded,
              color: AppColors.water,
              size: AppDimens.iconLg,
            ),
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
                  'Average: ${s.avgWaterMl} ml / day',
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
    required IconData icon,
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
              Icon(icon, size: 16, color: color),
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
