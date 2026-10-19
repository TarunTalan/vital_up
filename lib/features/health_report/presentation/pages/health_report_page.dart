import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/load_timeout.dart';
import 'package:vital_up/core/utils/number_formats.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/adaptive_row.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/app_segmented_control.dart';
import 'package:vital_up/core/widgets/fit_text.dart';
import 'package:vital_up/core/widgets/load_error_view.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:vital_up/features/weight/data/weight_service.dart';
import '../../data/services/health_report_service.dart';

/// Shown for a figure with nothing recorded in the period.
const _none = '—';

/// A summary of the chosen period to share with a doctor: one card per
/// area (body and heart, sleep, activity, hydration), each with the same
/// header and a row of equal-width figures, and the share action pinned
/// at the bottom.
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

  void _selectDays(int days) {
    if (_selectedDays == days) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedDays = days);
    _loadReport();
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    final ready = !_isLoading && !_failed && summary != null;
    return AppScaffold(
      header: const AppPageHeader(title: 'Health report'),
      scrollable: true,
      bottomBar: ready
          ? AppPrimaryButton(
              label: 'Share with doctor',
              leadingIcon: const Icon(Icons.share_rounded),
              isLoading: _isExporting,
              onTap: _exportReport,
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSegmentedControl<int>(
            values: const [7, 30, 90],
            selected: _selectedDays,
            label: (days) => '$days days',
            onChanged: _selectDays,
          ),
          const SizedBox(height: AppDimens.space12),
          _PeriodLine(days: _selectedDays, name: summary?.profile?.fullName),
          const SizedBox(height: AppDimens.sectionGap),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppDimens.space40),
              child: Center(child: VitalUpLoader()),
            )
          else if (!ready)
            LoadErrorView(onRetry: _loadReport)
          else
            ..._sections(summary),
        ],
      ),
    );
  }

  List<Widget> _sections(HealthReportSummary s) {
    final days = s.daysCount;
    final sections = [
      _ReportSection(
        title: 'Body and heart',
        icon: Icons.favorite_rounded,
        color: AppColors.error,
        figures: [
          _Figure(
            'Weight',
            s.latestWeightKg == null
                ? _none
                : _unit.fromKg(s.latestWeightKg!).toStringAsFixed(1),
            unit: s.latestWeightKg == null ? null : _unit.label,
          ),
          _Figure(
            'Blood pressure',
            s.bloodPressure ?? _none,
            unit: s.bloodPressure == null ? null : 'mmHg',
          ),
          _Figure(
            'Resting pulse',
            s.restingBpm?.toString() ?? _none,
            unit: s.restingBpm == null ? null : 'bpm',
          ),
        ],
      ),
      _ReportSection(
        title: 'Sleep',
        icon: Icons.bedtime_rounded,
        color: AppColors.sleep,
        figures: [
          _Figure(
            'Per night',
            s.avgSleepHours?.toStringAsFixed(1) ?? _none,
            unit: s.avgSleepHours == null ? null : 'h',
          ),
          _Figure(
            'Sleep score',
            s.avgSleepScore?.toString() ?? _none,
            unit: s.avgSleepScore == null ? null : '/ 100',
          ),
          _Figure('Nights logged', '${s.nightsLogged}', unit: 'of $days'),
        ],
      ),
      _ReportSection(
        title: 'Activity',
        icon: Icons.directions_run_rounded,
        color: AppColors.primary,
        figures: [
          _Figure('Workouts', '${s.totalWorkouts}'),
          _Figure(
            'Active time',
            formatCount(s.totalActiveMinutes),
            unit: 'min',
          ),
          _Figure('Distance', s.totalDistanceKm.toStringAsFixed(1), unit: 'km'),
        ],
      ),
      _ReportSection(
        title: 'Hydration',
        icon: Icons.water_drop_rounded,
        color: AppColors.water,
        figures: [
          _Figure(
            'Average a day',
            s.avgWaterMl == null ? _none : formatCount(s.avgWaterMl!),
            unit: s.avgWaterMl == null ? null : 'ml',
          ),
          _Figure('Days logged', '${s.waterDaysLogged}', unit: 'of $days'),
        ],
      ),
    ];
    return [
      for (var i = 0; i < sections.length; i++) ...[
        if (i > 0) const SizedBox(height: AppDimens.cardGap),
        sections[i],
      ],
      const SizedBox(height: AppDimens.cardGap),
      const AppInfoNote(
        message:
            'Figures come from what you logged and synced. '
            'This is not a medical diagnosis.',
      ),
    ];
  }
}

/// "For Tarun · 19 Sep – 18 Oct": who and which days the report covers.
class _PeriodLine extends StatelessWidget {
  final int days;
  final String? name;

  const _PeriodLine({required this.days, required this.name});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day - (days - 1));
    final f = DateFormat('d MMM');
    final who = name?.trim().isNotEmpty == true ? 'For ${name!.trim()} · ' : '';
    return Text(
      '$who${f.format(from)} – ${f.format(now)}',
      style: context.text.bodySmall?.copyWith(color: context.vColors.grayText),
    );
  }
}

/// One area of the report: icon badge and title, then its figures in equal
/// columns (two a row with large text).
class _ReportSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<_Figure> figures;

  const _ReportSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.figures,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppIconBadge(
                color: color,
                size: AppDimens.iconBadgeSmall,
                icon: Icon(icon),
              ),
              const SizedBox(width: AppDimens.space12),
              Expanded(
                child: Text(
                  title,
                  style: context.text.titleSmall?.copyWith(
                    color: context.colors.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.space16),
          AdaptiveRow(spacing: AppDimens.space12, children: figures),
        ],
      ),
    );
  }
}

/// A labelled figure: the label (up to two lines), then the value with its
/// unit in smaller grey text (under it when there isn't room beside it).
class _Figure extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;

  const _Figure(this.label, this.value, {this.unit});

  @override
  Widget build(BuildContext context) {
    final grey = context.vColors.grayText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.text.bodySmall?.copyWith(color: grey),
        ),
        const SizedBox(height: AppDimens.space4),
        FitText.rich(
          TextSpan(
            children: [
              TextSpan(
                text: value,
                style: context.text.titleMedium?.copyWith(
                  color: context.colors.onSurface,
                ),
              ),
              if (unit != null)
                TextSpan(
                  text: ' $unit',
                  style: context.text.bodySmall?.copyWith(color: grey),
                ),
            ],
          ),
          // The unit drops under the value when both don't fit one line.
          maxLines: 2,
        ),
      ],
    );
  }
}
