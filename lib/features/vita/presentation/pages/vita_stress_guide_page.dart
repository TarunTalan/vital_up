import 'package:flutter/material.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/app_score_ring.dart';
import 'package:vital_up/features/vita/domain/entities/vita_insights.dart';
import 'package:vital_up/features/vita/domain/repositories/vita_repository.dart';
import 'package:vital_up/features/vita/presentation/widgets/vita_insight_card.dart';
import 'package:vital_up/features/vita/presentation/widgets/vita_page_body.dart';

/// Figma `health coach/ stress detect` (1912:17583). The score is computed on
/// device from the daily check-in, watch HRV / resting heart rate and
/// lifestyle triggers; only the tip text comes from the AI.
class VitaStressGuidePage extends StatefulWidget {
  const VitaStressGuidePage({super.key});

  @override
  State<VitaStressGuidePage> createState() => _VitaStressGuidePageState();
}

class _VitaStressGuidePageState extends State<VitaStressGuidePage> {
  final _repository = sl<VitaRepository>();
  late Future<StressReport> _report = _repository.getStressReport();
  late final Future<VitaDailyInsights?> _insights =
      _repository.getDailyInsights();
  bool _connecting = false;

  void _reload() =>
      setState(() => _report = _repository.getStressReport());

  Future<void> _checkIn(int level) async {
    await _repository.saveStressCheckIn(level);
    if (mounted) _reload();
  }

  Future<void> _connectWearable() async {
    setState(() => _connecting = true);
    final granted = await _repository.connectWearable();
    if (!mounted) return;
    setState(() => _connecting = false);
    if (granted) {
      _reload();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No heart data access granted. You can allow it in '
            'Health Connect / Health settings.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      header: const AppTitleBar(title: 'Stress Guide'),
      bodyPadding: vitaBodyPadding(context),
      body: VitaFutureBody<StressReport>(
        future: _report,
        builder: (context, report) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StressLevelCard(report: report),
            const SizedBox(height: AppDimens.space16),
            _CheckInCard(
              selected: report.todayCheckIn?.level,
              onSelected: _checkIn,
            ),
            FutureBuilder<VitaDailyInsights?>(
              future: _insights,
              builder: (context, snapshot) {
                final tip = snapshot.data?.stressTip ?? report.tip;
                if (tip == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: AppDimens.space16),
                  child: VitaInsightCard.message(tip),
                );
              },
            ),
            const SizedBox(height: AppDimens.space16),
            _TriggersCard(triggers: report.triggers),
            if (report.canConnectWearable) ...[
              const SizedBox(height: AppDimens.space16),
              _ConnectWearableCard(
                loading: _connecting,
                onConnect: _connectWearable,
              ),
            ],
            const SizedBox(height: AppDimens.space16),
            const AppInfoNote(
              message: 'Stress scores are estimates for general wellbeing, '
                  'not a medical assessment.',
            ),
          ],
        ),
      ),
    );
  }
}

Color _levelColor(StressLevel level) => switch (level) {
      StressLevel.low => AppColors.gradeGood,
      StressLevel.moderate => AppColors.gradeModerate,
      StressLevel.high => AppColors.gradeBad,
    };

class _StressLevelCard extends StatelessWidget {
  final StressReport report;

  const _StressLevelCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final accent = _levelColor(report.level);
    final grey = context.vColors.grayText;

    return AppCard(
      blur: true,
      shadow: AppShadows.soft,
      padding: VitaDimens.cardPadding,
      child: Column(
        children: [
          Text(
            'CURRENT STRESS LEVEL',
            textAlign: TextAlign.center,
            style: context.text.titleSmall?.copyWith(color: grey),
          ),
          const SizedBox(height: AppDimens.space16),
          AppScoreRing(
            score: report.score,
            label: report.level.label.split(' ').first,
            color: accent,
          ),
          const SizedBox(height: AppDimens.space16),
          Text(
            report.level.label,
            textAlign: TextAlign.center,
            style: context.text.headlineSmall?.copyWith(color: accent),
          ),
          const SizedBox(height: AppDimens.space2),
          Text(
            report.trend,
            textAlign: TextAlign.center,
            style: context.text.bodyLarge?.copyWith(color: grey),
          ),
          const SizedBox(height: AppDimens.space8),
          Text(
            report.source.description,
            textAlign: TextAlign.center,
            style: context.text.bodySmall?.copyWith(color: grey),
          ),
        ],
      ),
    );
  }
}

/// Daily self-report, 1 (very calm) – 5 (very stressed).
class _CheckInCard extends StatelessWidget {
  final int? selected;
  final ValueChanged<int> onSelected;

  const _CheckInCard({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final onSurface = context.colors.onSurface;

    return AppCard(
      blur: true,
      sheen: false,
      shadow: AppShadows.soft,
      padding: VitaDimens.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            selected == null
                ? 'How stressed do you feel today?'
                : "Today's check-in",
            style: context.text.titleSmall?.copyWith(color: onSurface),
          ),
          const SizedBox(height: AppDimens.space12),
          Wrap(
            spacing: AppDimens.space8,
            runSpacing: AppDimens.space8,
            children: [
              for (var level = 1; level <= 5; level++)
                ChoiceChip(
                  label: Text(StressCheckIn.labels[level - 1]),
                  selected: selected == level,
                  showCheckmark: false,
                  onSelected: (_) => onSelected(level),
                  labelStyle: context.text.bodyMedium?.copyWith(
                    color: selected == level ? v.buttonText : onSurface,
                  ),
                  selectedColor: context.colors.primary,
                  backgroundColor: v.glassFill,
                  side: BorderSide(
                    color: selected == level
                        ? context.colors.primary
                        : v.glassBorder!,
                  ),
                  shape: const StadiumBorder(),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TriggersCard extends StatelessWidget {
  final List<StressTrigger> triggers;

  const _TriggersCard({required this.triggers});

  @override
  Widget build(BuildContext context) {
    final onSurface = context.colors.onSurface;
    final rowStyle = context.text.bodyMedium?.copyWith(color: onSurface);

    return AppCard(
      blur: true,
      sheen: false,
      shadow: AppShadows.soft,
      padding: VitaDimens.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Detected Triggers',
            style: context.text.titleSmall?.copyWith(color: onSurface),
          ),
          if (triggers.isEmpty) ...[
            const SizedBox(height: AppDimens.space16),
            Text(
              'No triggers detected today 🎉',
              style: rowStyle?.copyWith(color: context.vColors.grayText),
            ),
          ],
          for (final trigger in triggers) ...[
            const SizedBox(height: AppDimens.space16),
            Row(
              children: [
                Expanded(child: Text(trigger.name, style: rowStyle)),
                const SizedBox(width: AppDimens.space12),
                Text(trigger.severity.label, style: rowStyle),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ConnectWearableCard extends StatelessWidget {
  final bool loading;
  final VoidCallback onConnect;

  const _ConnectWearableCard({required this.loading, required this.onConnect});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      blur: true,
      sheen: false,
      shadow: AppShadows.soft,
      padding: VitaDimens.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'More accurate with your watch',
            style: context.text.titleSmall?.copyWith(
              color: context.colors.onSurface,
            ),
          ),
          const SizedBox(height: AppDimens.space6),
          Text(
            'Vita can read heart-rate variability and resting heart rate '
            'from Health Connect / Apple Health to measure stress.',
            style: context.text.bodyMedium?.copyWith(
              color: context.vColors.grayText,
            ),
          ),
          const SizedBox(height: AppDimens.space16),
          AppSecondaryButton(
            label: 'Connect watch data',
            isLoading: loading,
            onTap: onConnect,
          ),
        ],
      ),
    );
  }
}
