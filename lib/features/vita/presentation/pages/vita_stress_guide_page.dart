import 'package:flutter/material.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/app_score_ring.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/tracker_log_sheets.dart';
import 'package:vital_up/features/vita/domain/entities/vita_insights.dart';
import 'package:vital_up/features/vita/domain/repositories/vita_repository.dart';
import 'package:vital_up/features/vita/presentation/widgets/vita_insight_card.dart';
import 'package:vital_up/features/vita/presentation/widgets/vita_page_body.dart';

/// Today's stress estimate, the check-in, Vita's tip and what may be
/// adding stress. The score is worked out on the device from the check-in
/// and lifestyle triggers; only the tip comes from the AI.
class VitaStressGuidePage extends StatefulWidget {
  const VitaStressGuidePage({super.key});

  @override
  State<VitaStressGuidePage> createState() => _VitaStressGuidePageState();
}

class _VitaStressGuidePageState extends State<VitaStressGuidePage> {
  final _repository = sl<VitaRepository>();
  late Future<StressReport> _report = _load();

  /// Caps the whole fetch so the loader can never spin forever.
  Future<StressReport> _load() =>
      _repository.getStressReport().timeout(const Duration(seconds: 60));
  late final Future<VitaDailyInsights?> _insights = _repository
      .getDailyInsights();
  bool _checkingIn = false;

  // Block body: an arrow body would hand setState the Future and throw.
  void _reload() {
    setState(() {
      _report = _load();
    });
  }

  Future<void> _checkIn(int level) async {
    if (_checkingIn) return;
    _checkingIn = true;
    try {
      await _repository.saveStressCheckIn(level);
    } catch (e) {
      debugPrint('Stress check-in not saved: $e');
      if (mounted) {
        showErrorSnackBar(context, "Couldn't save your check-in. Try again.");
      }
      return;
    } finally {
      _checkingIn = false;
    }
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      header: const AppPageHeader(title: 'Stress guide'),
      body: VitaFutureBody<StressReport>(
        future: _report,
        onRetry: _reload,
        builder: (context, report) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StressLevelCard(report: report),
            const SizedBox(height: AppDimens.cardGap),
            _CheckInCard(
              selected: report.todayCheckIn?.level,
              onSelected: _checkIn,
            ),
            FutureBuilder<VitaDailyInsights?>(
              future: _insights,
              builder: (context, snapshot) {
                final tip = snapshot.data?.stressTip ?? report.tip;
                if (tip == null || tip.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: AppDimens.cardGap),
                  child: VitaInsightCard.message(tip),
                );
              },
            ),
            const SizedBox(height: AppDimens.cardGap),
            _TriggersCard(triggers: report.triggers),
            const SizedBox(height: AppDimens.sectionGap),
            const AppInfoNote(
              message:
                  'Stress scores are estimates for general wellbeing, not a '
                  'medical assessment.',
            ),
          ],
        ),
      ),
    );
  }
}

/// Ring colour for a level (fills only: the label beside it is plain text).
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
    final grey = context.vColors.grayText;

    return AppCard(
      child: Column(
        children: [
          Text(
            'Current stress level',
            textAlign: TextAlign.center,
            style: context.text.bodySmall?.copyWith(color: grey),
          ),
          const SizedBox(height: AppDimens.space12),
          AppScoreRing(
            score: report.score,
            label: report.level.label.split(' ').first,
            color: _levelColor(report.level),
          ),
          const SizedBox(height: AppDimens.space12),
          Text(
            report.level.label,
            textAlign: TextAlign.center,
            style: context.text.titleMedium?.copyWith(
              color: context.colors.onSurface,
            ),
          ),
          const SizedBox(height: AppDimens.space4),
          Text(
            report.trend,
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(color: grey),
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

/// Daily self-report, 1 (very calm) to 5 (very stressed): the same faces
/// as the check-in card on Home.
class _CheckInCard extends StatelessWidget {
  final int? selected;
  final ValueChanged<int> onSelected;

  const _CheckInCard({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            selected == null
                ? 'How stressed do you feel today?'
                : "Today's check-in",
            style: context.text.titleSmall?.copyWith(
              color: context.colors.onSurface,
            ),
          ),
          const SizedBox(height: AppDimens.space12),
          MoodLevelPicker(selected: selected, onSelected: onSelected),
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
    final grey = context.vColors.grayText;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Possible triggers today',
            style: context.text.titleSmall?.copyWith(color: onSurface),
          ),
          if (triggers.isEmpty) ...[
            const SizedBox(height: AppDimens.space8),
            Text(
              'Nothing stands out today.',
              style: context.text.bodyMedium?.copyWith(color: grey),
            ),
          ],
          for (final trigger in triggers) ...[
            const SizedBox(height: AppDimens.space12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    trigger.name,
                    style: context.text.bodyMedium?.copyWith(color: onSurface),
                  ),
                ),
                const SizedBox(width: AppDimens.space12),
                Text(
                  trigger.severity.label,
                  style: context.text.bodySmall?.copyWith(color: grey),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
