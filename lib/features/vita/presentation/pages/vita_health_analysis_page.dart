import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/features/vita/domain/entities/vita_insights.dart';
import 'package:vital_up/features/vita/domain/repositories/vita_repository.dart';
import 'package:vital_up/features/vita/presentation/utils/vita_icons.dart';
import 'package:vital_up/features/vita/presentation/widgets/vita_insight_card.dart';
import 'package:vital_up/features/vita/presentation/widgets/vita_page_body.dart';

/// What the user's logs say, one card per area, under Vita's one-line
/// summary. Figures are worked out on the device; only the summary line
/// comes from the AI.
class VitaHealthAnalysisPage extends StatefulWidget {
  const VitaHealthAnalysisPage({super.key});

  @override
  State<VitaHealthAnalysisPage> createState() => _VitaHealthAnalysisPageState();
}

class _VitaHealthAnalysisPageState extends State<VitaHealthAnalysisPage> {
  final _repository = sl<VitaRepository>();
  late Future<HealthAnalysis> _analysis = _load();

  /// The AI call has its own timeout; this caps the whole fetch so the
  /// loader can never spin forever.
  Future<HealthAnalysis> _load() =>
      _repository.getHealthAnalysis().timeout(const Duration(seconds: 60));

  // Block body: an arrow body would hand setState the Future and throw.
  void _reload() {
    setState(() {
      _analysis = _load();
    });
  }

  late final Future<VitaDailyInsights?> _insights = _repository
      .getDailyInsights();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      header: const AppPageHeader(title: 'Health analysis'),
      body: VitaFutureBody<HealthAnalysis>(
        future: _analysis,
        onRetry: _reload,
        builder: (context, analysis) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            VitaInsightCard(
              child: _Summary(analysis: analysis, insights: _insights),
            ),
            if (analysis.signals.length <= 1) ...[
              const SizedBox(height: AppDimens.cardGap),
              const AppInfoNote(
                message:
                    'Log meals, sleep, water and workouts, or turn on Health '
                    'sync in Settings, and Vita will cover more here.',
              ),
            ],
            for (final signal in analysis.signals) ...[
              const SizedBox(height: AppDimens.cardGap),
              _SignalCard(signal: signal),
            ],
          ],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final HealthAnalysis analysis;
  final Future<VitaDailyInsights?> insights;

  const _Summary({required this.analysis, required this.insights});

  @override
  Widget build(BuildContext context) {
    final onSurface = context.colors.onSurface;
    final areas = analysis.featureCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your health at a glance',
          style: context.text.titleMedium?.copyWith(color: onSurface),
        ),
        const SizedBox(height: AppDimens.space4),
        Text(
          'Based on $areas area${areas == 1 ? '' : 's'} you track',
          style: context.text.bodySmall?.copyWith(
            color: context.vColors.grayText,
          ),
        ),
        FutureBuilder<VitaDailyInsights?>(
          future: insights,
          builder: (context, snapshot) {
            final headline = snapshot.data?.headline ?? analysis.headline;
            if (headline == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: AppDimens.space12),
              child: Text(
                headline,
                style: context.text.bodyLarge?.copyWith(color: onSurface),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// One area: icon badge, its name and what the data says. Static (nothing
/// to open), so no chevron.
class _SignalCard extends StatelessWidget {
  final HealthSignal signal;

  const _SignalCard({required this.signal});

  @override
  Widget build(BuildContext context) {
    final onSurface = context.colors.onSurface;
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIconBadge(
            color: VitaColors.accent,
            icon: SvgPicture.asset(
              VitaIcons.forSignal(signal.kind),
              width: AppDimens.iconMd,
              height: AppDimens.iconMd,
              colorFilter: ColorFilter.mode(
                AppIconBadge.glyphColor(context, VitaColors.accent),
                BlendMode.srcIn,
              ),
            ),
          ),
          const SizedBox(width: AppDimens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  signal.title,
                  style: context.text.titleSmall?.copyWith(color: onSurface),
                ),
                const SizedBox(height: AppDimens.space4),
                Text(
                  signal.summary,
                  style: context.text.bodyMedium?.copyWith(
                    color: context.vColors.grayText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
