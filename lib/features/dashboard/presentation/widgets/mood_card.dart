import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
import 'package:vital_up/core/widgets/tracker/tracker_status.dart';
import 'package:vital_up/core/widgets/tracker/tracker_widgets.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/stress_checkin_cubit.dart';
import 'mood_widgets.dart';
import 'tracker_log_sheets.dart';

const _metric = TrackerMetric.mood;

/// Home tile: today's mood check-in, or a prompt to check in. Checking in
/// and editing open the mood sheet.
class MoodCard extends StatelessWidget {
  const MoodCard({super.key});

  Future<void> _open(BuildContext context) async {
    final cubit = context.read<StressCheckInCubit>();
    await context.pushNamed(_metric.route);
    cubit.load();
  }

  Future<void> _log(BuildContext context) async {
    final cubit = context.read<StressCheckInCubit>();
    if (await showMoodLogSheet(context, initial: cubit.state.today)) {
      cubit.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StressCheckInCubit, StressCheckInState>(
      builder: (context, state) {
        final today = state.today;
        return TrackerCard(
          metric: _metric,
          title: 'Mood',
          status: today == null ? TrackerStatus.notLogged : TrackerStatus.done,
          statusLabel: today == null ? null : 'Checked in',
          onOpen: () => _open(context),
          actions: [
            TrackerQuickAction(
              label: today == null ? _metric.logLabel : 'Edit',
              icon: today == null ? _metric.logIcon : Icons.edit_rounded,
              color: _metric.color,
              filled: today == null,
              onTap: () => _log(context),
            ),
          ],
          child: Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (today == null)
                  TrackerPrompt(
                    title: 'How are you feeling?',
                    message: 'Check in to track your mood.',
                    color: _metric.color,
                  )
                else ...[
                  Row(
                    children: [
                      Icon(
                        moodIcon(today.level),
                        size: AppDimens.iconXl,
                        color: stressColor(today.level),
                      ),
                      const SizedBox(width: AppDimens.space8),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            today.label,
                            maxLines: 1,
                            style: AppTextStyles.metric.copyWith(
                              color: context.colors.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimens.space6),
                  Text(
                    'Checked in at ${DateFormat.jm().format(today.date)}',
                    style: context.text.bodySmall?.copyWith(
                      color: context.vColors.grayText,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
