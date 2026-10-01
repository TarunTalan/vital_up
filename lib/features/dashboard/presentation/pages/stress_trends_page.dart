import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/features/dashboard/data/services/trends_service.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/trend_cubit.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/mood_widgets.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/trend_widgets.dart';
import 'package:vital_up/features/vita/domain/entities/vita_insights.dart';

/// Mood trend: daily check-in level, what's been behind it, and the log.
class StressTrendsPage extends StatelessWidget {
  const StressTrendsPage({super.key});

  static String formatLevel(double level) =>
      StressCheckIn.labels[(level.round() - 1).clamp(0, 4)];

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TrendCubit<StressCheckIn>(sl<TrendsService>().stress)..load(),
      child: TrendDetailScaffold<StressCheckIn>(
        title: 'Mood & Stress',
        color: AppColors.stressLevels[2],
        colorOf: stressColor,
        format: formatLevel,
        axisFormat: (v) =>
            v == v.roundToDouble() && v >= 1 && v <= 5
                ? StressCheckIn.emojis[v.toInt() - 1]
                : '',
        logsTitle: 'Check-ins',
        emptyLogs: 'No check-ins yet. Log your mood from the dashboard.',
        bottomBar: AppSecondaryButton(
          label: 'Open stress guide',
          onTap: () => context.pushNamed('vita-stress'),
        ),
        header: (context, data) => _TagSummary(checkIns: data.logs),
        logBuilder: (context, c) => AppCard(
          width: double.infinity,
          sheen: false,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.space16,
            vertical: AppDimens.space12,
          ),
          child: Row(
            children: [
              Text(
                c.emoji,
                style: const TextStyle(fontSize: AppDimens.moodFaceSize),
              ),
              const SizedBox(width: AppDimens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.label,
                      style: context.text.titleSmall
                          ?.copyWith(color: stressColor(c.level)),
                    ),
                    if (c.tags.isNotEmpty)
                      Text(
                        c.tags.map((t) => '${t.emoji} ${t.label}').join('  '),
                        style: context.text.bodySmall
                            ?.copyWith(color: context.vColors.grayText),
                      ),
                  ],
                ),
              ),
              Text(
                DateFormat('EEE d MMM').format(c.date),
                style: context.text.bodySmall
                    ?.copyWith(color: context.vColors.grayText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Most frequent check-in tags in the selected range.
class _TagSummary extends StatelessWidget {
  final List<StressCheckIn> checkIns;

  const _TagSummary({required this.checkIns});

  @override
  Widget build(BuildContext context) {
    final counts = <StressTag, int>{};
    for (final c in checkIns) {
      for (final t in c.tags) {
        counts[t] = (counts[t] ?? 0) + 1;
      }
    }
    final top = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return AppCard(
      width: double.infinity,
      padding: AppDimens.cardPaddingCompact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppCaption("What's been on your mind"),
          const SizedBox(height: AppDimens.space12),
          if (top.isEmpty)
            Text(
              'Add tags when you check in to spot patterns.',
              style: context.text.bodyMedium
                  ?.copyWith(color: context.vColors.grayText),
            )
          else
            Wrap(
              spacing: AppDimens.space8,
              runSpacing: AppDimens.space8,
              children: [
                for (final e in top)
                  Chip(label: Text('${e.key.emoji} ${e.key.label} · ${e.value}')),
              ],
            ),
        ],
      ),
    );
  }
}
