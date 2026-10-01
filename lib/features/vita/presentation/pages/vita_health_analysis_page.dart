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

/// Figma `health coach/ analysis` (1908:13240).
class VitaHealthAnalysisPage extends StatefulWidget {
  const VitaHealthAnalysisPage({super.key});

  @override
  State<VitaHealthAnalysisPage> createState() => _VitaHealthAnalysisPageState();
}

class _VitaHealthAnalysisPageState extends State<VitaHealthAnalysisPage> {
  final _repository = sl<VitaRepository>();
  late final Future<HealthAnalysis> _analysis = _repository.getHealthAnalysis();
  late final Future<VitaDailyInsights?> _insights =
      _repository.getDailyInsights();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      header: const AppTitleBar(title: 'Health Analysis'),
      bodyPadding: vitaBodyPadding(context),
      body: VitaFutureBody<HealthAnalysis>(
        future: _analysis,
        builder: (context, analysis) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            VitaInsightCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Vita knows you',
                      style: context.text.headlineLarge?.copyWith(
                        color: context.colors.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimens.space4),
                  Text(
                    'Analyzing ${analysis.signalCount} health '
                    'signal${analysis.signalCount == 1 ? '' : 's'} across '
                    '${analysis.featureCount} '
                    'feature${analysis.featureCount == 1 ? '' : 's'}',
                    style: context.text.bodyMedium?.copyWith(
                      color: context.colors.onSurface,
                    ),
                  ),
                  FutureBuilder<VitaDailyInsights?>(
                    future: _insights,
                    initialData: null,
                    builder: (context, snapshot) {
                      final headline =
                          snapshot.data?.headline ?? analysis.headline;
                      if (headline == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: AppDimens.space12),
                        child: Text(
                          headline,
                          style: context.text.bodyLarge?.copyWith(
                            color: context.colors.onSurface,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            if (analysis.signals.length <= 1) ...[
              const SizedBox(height: AppDimens.space16),
              const AppInfoNote(
                message: 'Log meals, sleep, water and workouts — or connect '
                    'your watch from the Stress Guide — and Vita will '
                    'analyse more of your health here.',
              ),
            ],
            for (final signal in analysis.signals) ...[
              const SizedBox(height: AppDimens.space16),
              _SignalRow(signal: signal),
            ],
          ],
        ),
      ),
    );
  }
}

class _SignalRow extends StatelessWidget {
  final HealthSignal signal;

  const _SignalRow({required this.signal});

  @override
  Widget build(BuildContext context) {
    final onSurface = context.colors.onSurface;
    return AppCard(
      blur: true,
      sheen: false,
      shadow: AppShadows.soft,
      padding: VitaDimens.cardPadding,
      child: Row(
        children: [
          Container(
            width: VitaDimens.signalBadge,
            height: VitaDimens.signalBadge,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: VitaColors.signalBadge,
              borderRadius: BorderRadius.circular(VitaDimens.signalBadgeRadius),
            ),
            child: SvgPicture.asset(
              VitaIcons.forSignal(signal.kind),
              width: AppDimens.iconMd,
              height: AppDimens.iconMd,
            ),
          ),
          const SizedBox(width: AppDimens.space20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  signal.title,
                  style: context.text.titleSmall?.copyWith(color: onSurface),
                ),
                const SizedBox(height: AppDimens.space6),
                Text(
                  signal.summary,
                  style: context.text.bodyMedium?.copyWith(color: onSurface),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
